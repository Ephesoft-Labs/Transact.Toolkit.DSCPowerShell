enum Ensure {
  Absent
  Present
}

enum DBType {
  MariaDB
  SQL
  Oracle
}

enum StartupType {
  Automatic
  DelayedStart
  Manual
  Disabled
}

enum SQLAuthTypes {
  Windows
  SQL
}

# This resource manages the Transact Setup Process.
[DscResource()]
class TransactSetup {

  #  This property is the full version of the Transact instance that is expected to be installed.
  [DscProperty(Key)]
  [ValidatePattern('[0-9]{4}\.[0-9]')]
  [string]$Version

  <#
    This property indicates if the settings should be present or absent
    on the system. For present, the resource ensures the instance
    exists. For absent, it ensures the instance does not exist.
  #>
  [DscProperty(Mandatory)]
  [Ensure] $Ensure

  # Defines which database type will be used for the instance
  [DscProperty(Mandatory)]
  [DBType] $DatabaseType

  # Path to the Transact Installer
  [DscProperty(Mandatory)]
  [string] $InstallerPath

  # Database instance credential used by the Transact installer
  [DscProperty()]
  [System.Management.Automation.PSCredential]$DBCredential

  # Full file path to the Ephesoft license file with file type .lic
  [DscProperty(Mandatory)]
  [string]$LicenseFilePath

  # Hostname where requests will be serviced (uses the server's computer name if not specified)
  [DscProperty()]
  [string]$hostname

  # SQL Authentication mode to use.  'Windows' uses integrated authentication and 'SQL' uses SQL authentication.
  [DscProperty()]
  [SQLAuthTypes]$SQLAuthType = 'SQL'

  # Set Variables
  hidden [string]$ServiceName = 'EphesoftTransact'
  hidden [string]$EphesoftFolder = 'C:\Ephesoft'
  hidden [string]$LicenseUtilFolder = "C:\Ephesoft\Dependencies\license-util"
  hidden [string]$Metafolder = 'WEB-INF\classes\META-INF'
  hidden [string]$DCMAWorkFlow = "C:\Ephesoft\Application\WEB-INF\classes\META-INF\dcma-workflows\dcma-workflows.properties"
  hidden [string]$DCMAFolderMonitor = "C:\Ephesoft\Application\WEB-INF\classes\META-INF\dcma-folder-monitor\folder-monitor.properties"
  hidden [string]$DCMABatch = "'C:\Ephesoft\Application\WEB-INF\classes\META-INF\dcma-batch\dcma-batch.properties"
  hidden [String]$CronEndYear = '2099' # The fix fails to work if you provide a higher year

  [void] Set() {

    # Only install if service does not exist
    if ($this.ensure -eq [Ensure]::Present -and (-NOT $this.TestServiceExists())) {

      # Prepare Config File
      Write-Verbose "Preparing Transact properties file"
      $this.PrepareConfigProperties()

      # Install Software
      Write-Verbose "Installing Ephesoft Transact from $($this.InstallerPath)"
      $InstallerFilePath = (Get-ChildItem $this.InstallerPath -Filter "*.msi").FullName
      $ArgumentListInstall = "/qb /norestart USERINPUTSPATH=`"$($this.InstallerPath)\config.properties`""
      Start-Process -FilePath $InstallerFilePath -ArgumentList $ArgumentListInstall -Wait -Passthru -ErrorAction Stop

      # Verify Installation
      $this.DemandServiceExists()

      # Run post-install configurations
      Write-Verbose 'Running post-install configurations'

      # Apply 2020 cron job fix to all versions prior to 2020
      if ($this.Version -notmatch '20[2-9][0-9]\.[0-9]') {
        $this.Fix2020CronJobIssue()
      }

      # License the application
      $this.SetTransactLicense()

      # If a user specified a hostname, set the hostname in property files so that images show correctly
      if ($this.hostname) {
        $this.SetHostWebProperties()
      }

      # Start the service
      $this.StartService()

    }
    elseif ($this.ensure -eq [Ensure]::Absent -and $this.TestServiceExists()) {

      # If ensure absent and the service exists, uninstall Transact via MSIExec
      Write-Verbose -Message 'Uninstalling Ephesoft Transact'
      $InstallerFilePath = (Get-ChildItem $this.InstallerPath -Filter "*.msi").FullName
      $ArgumentListUninstall = "/x $InstallerFilePath /q"
      Start-Process -FilePath 'msiexec' -ArgumentList $ArgumentListUninstall -Wait -PassThru -ErrorAction Stop
    }
    else {
      Write-Verbose "Requested service $($this.ensure), found service exists to be $($this.TestServiceExists())"
    }
  }

  [bool] Test() {
    $present = $this.TestServiceExists()

    if ($this.Ensure -eq [Ensure]::Present) {
      return $present
    }
    else {
      return -not $present
    }
  }

  [TransactSetup] Get() {
    $present = $this.TestServiceExists()

    if ($present) {
      $this.Ensure = [Ensure]::Present
    }
    else {
      $this.Ensure = [Ensure]::Absent
    }
    return $this
  }

  # Helper method to check if a service exists
  [bool] TestServiceExists() {
    $present = $true

    $item = Get-Service $this.ServiceName -ErrorAction 'Ignore'
    if ($null -eq $item) {
      $present = $false
    }
    return $present
  }

  # Helper method which will throw an error if the specified service does not exist
  [bool] DemandServiceExists() {
    $present = $this.TestServiceExists()
    if (-NOT $present) {
      THROW "Expected service $($this.ServiceName) to be present but it was not found!"
    }
    return $present
  }

  #  This method starts the Transact service
  [void] StartService () {

    $service = Get-Service $this.ServiceName
    if ($service.status -ne 'Running'){
      Write-Verbose "Starting service $this.ServiceName"
      Start-Service $this.ServiceName
    }
  }

  # This method will update the Transact configuration properties in preparation for installation
  [void] PrepareConfigProperties() {
    if (-NOT (Test-Path "$($this.InstallerPath)\config.properties")) {
      Throw "Unable to find configuration file config.properties at installer path $($this.InstallerPath)"
    }

    # Set Database Properties
    Switch ($this.DatabaseType) {
      'MariaDB' { $this.UpdateMariaDBProperties() }
      'SQL' { $this.UpdateSQLProperties() }
      'Oracle' { $this.UpdateOracleProperties() }
    }
  }

  # This method gets the installer properties
  [array] GetConfigProperties () {

    # Get existing properties
    $Properties = Get-Content "$($this.InstallerPath)\config.properties"

    # Throw an error if no properties are returned
    If (-NOT $Properties) {
      Throw "Properties not found in file $($this.InstallerPath)\config.properties!"
    }
    Return $Properties
  }

  # This method updates the installer properties for MariaDB prior to installation
  [void] UpdateMariaDBProperties () {
    if (-NOT ($this.DBCredential)) {
      Throw "DatabaseType set to $($this.DatabaseType) but DBCredential was not provided.  DBCredential must be passed when using MariaDB."
    }

    $Properties = $this.GetConfigProperties()
    $CurrentDBType = $Properties | Where-Object {$_ -like "database_type=*"}
    $Properties = $Properties.Replace($CurrentDBType, "database_type=1")

    $CurrentDBUsername = $Properties | Where-Object {$_ -like "existing_maria_db_username=*"}
    $Properties = $Properties.Replace($CurrentDBUsername, "existing_maria_db_username=$($this.DBCredential.Username)")

    $CurrentDBPassword = $Properties | Where-Object {$_ -like "existing_maria_db_password=*"}
    $Properties = $Properties.Replace($CurrentDBPassword, "existing_maria_db_password=$($this.DBCredential.GetNetworkCredential().Password)")

    $CurrentDBServerName = $Properties | Where-Object {$_ -like "existing_maria_db_servername=*"}
    $Properties = $Properties.Replace($CurrentDBServerName, "existing_maria_db_servername=localhost")

    # Update properties
    Set-Content "$($this.InstallerPath)\config.properties" -Value $Properties -ErrorAction 'Stop'
  }

  # This method updates the installer properties for SQL prior to installation
  [void] UpdateSQLProperties () {

    $Properties = $this.GetConfigProperties()
    $CurrentDBType = $Properties | Where-Object {$_ -like "database_type=*"}
    $Properties = $Properties.Replace($CurrentDBType, "database_type=2")

    if ($this.SQLAuthType -eq 'SQL') {
      if (-NOT ($this.DBCredential)) {
        Throw "SQLAuthType set to $($this.SQLAuthType) but DBCredential was not provided.  DBCredential must be passed when using SQL auth type"
      }

      $CurrentDBUsername = $Properties | Where-Object {$_ -like "existing_ms_db_username=*"}
      $Properties = $Properties.Replace($CurrentDBUsername, "existing_ms_db_username=$($this.DBCredential.Username)")

      $CurrentDBPassword = $Properties | Where-Object {$_ -like "existing_ms_db_password=*"}
      $Properties = $Properties.Replace($CurrentDBPassword, "existing_ms_db_password=$($this.DBCredential.GetNetworkCredential().Password)")

      $CurrentWindowsAuthSetting = $Properties | Where-Object {$_ -like "windows_authentication_for_mssql=*"}
      $Properties = $Properties.Replace($CurrentWindowsAuthSetting, "windows_authentication_for_mssql=")
    }
    elseif ($this.SQLAuthType -eq 'Windows') {
      $CurrentWindowsAuthSetting = $Properties | Where-Object {$_ -like "windows_authentication_for_mssql=*"}
      $Properties = $Properties.Replace($CurrentWindowsAuthSetting, "windows_authentication_for_mssql=1")
    }

    $CurrentDBServerName = $Properties | Where-Object {$_ -like "existing_ms_db_servername=*"}
    $Properties = $Properties.Replace($CurrentDBServerName, "existing_ms_db_servername=$env:COMPUTERNAME")

    # Update properties
    Set-Content "$($this.InstallerPath)\config.properties" -Value $Properties -ErrorAction 'Stop'
  }

  # This method updates the installer properties for Oracle prior to installation
  [void] UpdateOracleProperties () {
    if (-NOT ($this.DBCredential)) {
      Throw "DatabaseType set to $($this.DatabaseType) but DBCredential was not provided.  DBCredential must be passed when using Oracle."
    }

    $Properties = $this.GetConfigProperties()
    $CurrentDBType = $Properties | Where-Object {$_ -like "database_type=*"}
    $Properties = $Properties.Replace($CurrentDBType, "database_type=3")

    $CurrentSysUsername = $Properties | Where-Object {$_ -like "existing_oracle_sys_username=*"}
    $Properties = $Properties.Replace($CurrentSysUsername, "existing_oracle_sys_username=$($this.DBCredential.Username)")

    $CurrentSysPassword = $Properties | Where-Object {$_ -like "existing_oracle_sys_password=*"}
    $Properties = $Properties.Replace($CurrentSysPassword, "existing_oracle_sys_password=$($this.DBCredential.GetNetworkCredential().Password)")

    $CurrentDBServerName = $Properties | Where-Object {$_ -like "existing_oracle_servername=*"}
    $Properties = $Properties.Replace($CurrentDBServerName, "existing_ms_db_servername=$env:COMPUTERNAME")

    $CurrentDBPassword = $Properties | Where-Object {$_ -like "existing_oracle_applicationdbpassword=*"}
    $Properties = $Properties.Replace($CurrentDBPassword, "existing_oracle_applicationdbpassword=$($this.DBCredential.GetNetworkCredential().Password)")

    $CurrentReportDBPassword = $Properties | Where-Object {$_ -like "existing_oracle_reportdbpassword=*"}
    $Properties = $Properties.Replace($CurrentReportDBPassword, "existing_oracle_reportdbpassword=$($this.DBCredential.GetNetworkCredential().Password)")

    $CurrentReportArchiveDBPassword = $Properties | Where-Object {$_ -like "existing_oracle_reportarchivedbpassword=*"}
    $Properties = $Properties.Replace($CurrentReportArchiveDBPassword, "existing_oracle_reportarchivedbpassword=$($this.DBCredential.GetNetworkCredential().Password)")

    # Update properties
    Set-Content "$($this.InstallerPath)\config.properties" -Value $Properties -ErrorAction 'Stop'
  }

  #This method applies a fix for a 2020 end time on a cron job
  [void]Fix2020CronJobIssue () {

    Write-Verbose 'Fixing cron job 2020 timeout'
    $FilesToUpdate = @($this.DCMAWorkFlow, $this.DCMAFolderMonitor)
    foreach ($File in $FilesToUpdate) {
        $Content = Get-Content $File

        # Regex that matches all characters up to a "=" character that also has 2020 at the end of the line. If found, replace 2020 with 2099
        Write-Verbose "Updating $File"
        $UpdatedContent = $Content -replace '(^.*=)(.*)(2020$)', "`$1`${2}$($this.CronEndYear)"
        Set-Content -Path $File -Value $UpdatedContent
    }
  }

  # This method sets the HTTP host property to the local computer name so that images are display properly
  [void] SetHostWebProperties () {
    Write-Verbose "Setting system hostname to $($this.Hostname)"

    # Build up the workflow properties path
    Write-Output "Updating $($this.DCMAWorkFlow)"
    $Content = Get-Content $this.DCMAWorkFlow

    # Regex that matches all characters up to a "//" characters. If found, replace all characters after up to ":" character with the local computer name
    $UpdatedContent = $Content -replace '^(wb.hostURL.+?:\/\/)(.*)(:)', "`$1$($this.Hostname)`$3"
    Set-Content -Path $this.DCMAWorkFlow -Value $UpdatedContent

    # Build up the folder monitor properties path
    Write-Output "Updating $($this.DCMABatch)"
    $Content = Get-Content $this.DCMABatch

    # Regex that matches all characters up to a "//" characters. If found, replace all characters after up to "\" character with the local computer name
    $UpdatedContent = $Content -replace '^(batch.base.+?:\/\/)(.*)(\\)', "`$1$($this.Hostname)`$3"
    Set-Content -Path $this.DCMABatch -Value $UpdatedContent
  }

  # This method will provide a license to the Transact service
  [void] SetTransactLicense() {

    # Install the license
    if (Test-Path $this.LicenseFilePath) {
      Write-Verbose "Installing license file from $($this.LicenseUtilFolder)"
      Copy-Item $this.LicenseFilePath $this.LicenseUtilFolder -Force

      # Set Java home since server hasn't rebooted since Transact installation
      $env:JAVA_HOME = "$($this.EphesoftFolder)\Dependencies\jdk"
      Start-Process -FilePath "$($this.LicenseUtilFolder)\install-license.bat" -WorkingDirectory $this.LicenseUtilFolder -Wait -ErrorAction Stop
    }
    else {
      Throw "Failed to find license file at user specified location of $($this.LicenseFilePath)"
    }
  }
}
Param (
  [Parameter (Mandatory = $true)]
  [string] $IPAddress
)

<#
  Use this example to create a .MOF which will deploy an MS SQL instance using Windows authentication,
  Ephesoft Transact instance, and all prerequisites on a machine via DSC.  All installers will need to
  be pre-staged on the system.  Make sure to update variables as needed.
#>

Configuration SetVMConfig
{
  # Import DSC modules
  Import-DscResource -ModuleName 'ComputerManagementDsc'
  Import-DscResource -ModuleName 'Ephesoft.Transact.Dsc'
  Import-DSCResource -ModuleName 'NetworkingDsc'
  Import-DscResource -ModuleName 'PowerShellModule'
  Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
  Import-DscResource -ModuleName 'SQLServerDSC'
  Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
  Import-DSCResource -ModuleName 'xSystemSecurity' -Name 'xIEEsc'

  Node $IPAddress {
    LocalConfigurationManager
    {
      RebootNodeIfNeeded = $true
    }

    UserAccountControl 'TransactUAC'
    {
        IsSingleInstance  = 'Yes'
        SuppressRestart   = $true
        NotificationLevel = 'NeverNotifyAndDisableAll'
    }

    Firewall 'TransactTCP'
    {
        Name        = 'TransactTCP'
        DisplayName = 'Transact-8080'
        Action      = 'Allow'
        Direction   = 'Inbound'
        LocalPort   = '8080'
        Protocol    = 'TCP'
        Profile     = 'Any'
        Enabled     = 'True'
    }

    NetAdapterBinding 'DisableIPv6'
    {
        InterfaceAlias = '*'
        ComponentId    = 'ms_tcpip6'
        State          = 'Disabled'
    }

    WindowsFeature 'NetFramework'
    {
         Name   = 'NET-Framework-45-Core'
         Ensure = 'Present'
    }

    # Disable UAC for Administrators only
    xIEEsc 'DisableIEEscAdmin'
    {
        IsEnabled = $False
        UserRole  = "Administrators"
    }

    xIEEsc 'EnableIEEscUser'
    {
        IsEnabled = $True
        UserRole  = "Users"
    }

    xArchive 'UnzipSQLInstaller'
    {
        Path        = 'C:\Path\To\SQL2017.zip'
        Destination = 'C:\Installers\SQLServer\2017'
        Validate    = $true
        Checksum    = 'SHA-256'
        Force       = $true
        Ensure      = 'Present'
    }

    SqlSetup 'InstallDefaultInstance'
    {
      InstanceName        = 'MSSQLSERVER'
      Features            = 'SQLENGINE'
      SourcePath          = 'C:\Installers\SQLServer\2017'
      SQLSysAdminAccounts = @('Administrators')
      DependsOn           = '[WindowsFeature]NetFramework'
      BrowserSvcStartupType = 'Automatic'
      SuppressReboot      = $true
    }

    # These configurations are required as documented here: https://ephesoft.com/docs/microsoft-sql-server-mssql-installation-and-configuration-instructions/
    SqlServerNetwork 'SetTCPConfig'
    {
      InstanceName        = 'MSSQLSERVER'
      ProtocolName        = 'tcp'
      IsEnabled           = $true
      TCPDynamicPort      = $false
      TCPPort             = '1433'
      RestartService      = $true
    }

    Package 'SQLCMDUtils'
    {
        Ensure = 'Present'
        Name = 'Microsoft Command Line Utilities 13 for SQL Server'
        Path = "C:\Installers\SQLServer\MsSqlCmdLnUtils.msi"
        Arguments = 'IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES'
        ProductId = '33C3E60D-6E22-445C-9B44-E9EEA5C47A01'
        DependsOn = '[SqlSetup]InstallDefaultInstance'
    }

    # Transact
    if ($Transact) {


      TransactSetup 'InstallTransact'
      {
        DatabaseType = 'SQL'
        SQLAuthType = 'Windows'
        Ensure = 'Present'
        InstallerPath = 'C:\Installers\Transact'
        Version = '2020.1'
        LicenseFilePath = 'C:\Installers\License\Ephesoft.lic'
      }

      ServiceSet 'SetTransactServiceToAutomatic'
      {
        Name        = 'EphesoftTransact'
        StartupType = 'Automatic'
        DependsOn   = 'InstallTransact'
      }
    }
  }
}

SetVMConfig -OutputPath 'C:\DSC' -IPAddress $IPAddress -ConfigurationData $ConfigurationData
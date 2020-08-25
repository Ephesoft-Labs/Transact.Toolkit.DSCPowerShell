using module '..\DSCResources\TransactSetup.psm1'
Function New-TransactSetupObject {
  [CMDLetBinding(SupportsShouldProcess = $true)]
  Param (
    [array]$MethodsToMock = @(),
    [string]$InstallerPath = '.\tests\resources',
    [string]$Version = '2020.1',
    [string]$Ensure = 'Present',
    [string]$SQLAuthType = 'SQL',
    [string]$DatabaseType = 'MariaDB',
    [Pscredential]$DBCredential,
    [string]$Hostname,
    [string]$LicenseFilePath
  )
  # Create context specific object
  If ($PSCMDLet.ShouldProcess('TransactSetup', 'Create Object')) {
    $Instance = New-Object 'TransactSetup'
    $Instance.DatabaseType = $DatabaseType
    $Instance.Ensure = $Ensure
    $Instance.InstallerPath = $InstallerPath
    $Instance.Version = $Version
    $Instance.SQLAuthType = $SQLAuthType
    $Instance.DBCredential = $DBCredential
    $Instance.Hostname = $Hostname
    $Instance.LicenseFilePath = $LicenseFilePath

    # Mock class methods
    Foreach ($Method in $MethodsToMock) {
      $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name $Method -Value { $true } -Force -PassThru
    }
    Return $Instance
  }
}

# Get-Service/Set-Service doesn't currently exist on Linux so this is needed for Bitbucket pipelines
# Follow this open issue to see when this can be updated: https://github.com/PowerShell/PowerShell/issues/3582
Function Get-Service {}
Function Start-Service {
  [CMDLetBinding(SupportsShouldProcess = $true)]
  Param(
    [string]$ServiceName
  )
  Write-Verbose $ServiceName
  If ($PSCMDLet.ShouldProcess('FakeService', 'Set Service')) {}
}

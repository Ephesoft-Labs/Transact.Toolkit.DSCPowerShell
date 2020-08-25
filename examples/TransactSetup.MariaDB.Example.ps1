Param (
  [Parameter (Mandatory = $true)]
  [pscredential] $DBCred,
  [Parameter (Mandatory = $true)]
  [string] $IPAddress
)

<#
  This example configuration allows the SQL credential to be stored in the .MOF in plain text.
  Only use this for demo/dev configurations.
  For instructions on securely storing the credential in the .MOF please see https://docs.microsoft.com/en-us/powershell/scripting/dsc/pull-server/securemof?view=powershell-7

  Use this example to create a .MOF which will deploy an MS SQL instance, Ephesoft Transact instance, and all prerequisites on a machine via DSC.

  All installers will need to be pre-staged on the system.  Make sure to update variables as needed.
#>
$ConfigurationData = @{
  AllNodes = @(
    @{
        NodeName=$IPAddress
        PSDscAllowPlainTextPassword=$true
    }
  )
}

Configuration SetConfig
{
  # Import DSC modules
  Import-DscResource -ModuleName 'ComputerManagementDsc'
  Import-DscResource -ModuleName 'Ephesoft.Transact.DSC'
  Import-DSCResource -ModuleName 'NetworkingDsc'
  Import-DscResource -ModuleName 'PowerShellModule'
  Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
  Import-DscResource -ModuleName 'MariaDB.DSC'
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

    # MariaDB
    MariaDB 'DBInstance'
    {
      InstallerPath = 'C:\Installers\MariadB\MariaDB.msi'
      RootPwd = $DBCred
      ServiceName = $MariaDBServiceName
      Ensure = $MariaDBEnsure
    }

    # Transact
    if ($Transact) {
      TransactSetup 'InstallTransact'
      {
        DatabaseType = 'MariaDB'
        DBCredential = $DBCred
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
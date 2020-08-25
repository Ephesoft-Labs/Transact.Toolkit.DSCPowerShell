using module '.\TransactSetup.TestHelper.psm1'

# PSScriptAnalyzer - ignore irrelevant errors
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", '', Justification = "Fake credentials used for unit testing." )]
Param ()

# Set Global Mocks
Mock Set-Content -ModuleName 'TransactSetup' {}
Mock Test-Path -ModuleName 'TransactSetup' {$true}

# Set Global Variables
$MariaDBUsername = 'FakeUser'
$MariaPWD = 'FakePW'

[securestring]$secStringPassword = ConvertTo-SecureString $MariaPWD -AsPlainText -Force
[pscredential]$DBCred = New-Object System.Management.Automation.PSCredential ($MariaDBUsername, $secStringPassword)

$Params = @{
  InstallerPath = '.\tests\resources'
  DatabaseType = 'SQL'
  SQLAuthType = 'SQL'
  DBCredential = $DBCred
}

# Create object for global use
$Instance = New-TransactSetupObject @Params

Describe "TransactSetup.PrepareConfigProperties()" {

  Context "When Using SQL with SQL Auth" {

    # Run the method
    $Instance.PrepareConfigProperties()

    It "Sets properties file using correct values" {
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "database_type=2"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_ms_db_username=$($DBCred.Username)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_ms_db_password=$($DBCred.GetNetworkCredential().Password)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "windows_authentication_for_mssql="
      }
    }

    It "Throws an error if database credential is not provided" {
      $Instance.DBCredential = $null
      { $Instance.PrepareConfigProperties() } | Should -Throw
    }
  }

  Context "When using SQL with Windows Auth" {

    # Set Context specific variables
    $Instance.SQLAuthType = 'Windows'

    # Run the method
    $Instance.PrepareConfigProperties()

    It "Sets properties file using correct values" {
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "database_type=2"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_ms_db_username=sa"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_ms_db_password=Default"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "windows_authentication_for_mssql=1"
      }
    }
  }

  Context "When using MariaDB" {

    # Set Context specific variables
    $Instance.DataBaseType = 'MariaDB'
    $Instance.DBCredential = $DBCred

    # Run the method
    $Instance.PrepareConfigProperties()

    It "Sets properties file using correct values" {
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "database_type=1"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_maria_db_username=$($DBCred.Username)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_maria_db_password=$($DBCred.GetNetworkCredential().Password)"
      }
    }

    It "Throws an error if database credential is not provided" {
      $Instance.DBCredential = $null
      { $Instance.PrepareConfigProperties() } | Should -Throw
    }
  }

  Context "When using Oracle" {

    # Set Context specific variables
    $Instance.DataBaseType = 'Oracle'
    $Instance.DBCredential = $DBCred

    # Run the method
    $Instance.PrepareConfigProperties()

    It "Sets properties file using correct values" {
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "database_type=3"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_oracle_sys_username=$($DBCred.Username)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_oracle_sys_password=$($DBCred.GetNetworkCredential().Password)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_oracle_applicationdbpassword=$($DBCred.GetNetworkCredential().Password)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_oracle_reportdbpassword=$($DBCred.GetNetworkCredential().Password)"
      }
      Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter{
        $Value -like "existing_oracle_reportarchivedbpassword=$($DBCred.GetNetworkCredential().Password)"
      }
    }

    It "Throws an error if database credential is not provided" {
      $Instance.DBCredential = $null
      { $Instance.PrepareConfigProperties() } | Should -Throw
    }
  }
}

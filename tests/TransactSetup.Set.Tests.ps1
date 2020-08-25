using module '.\TransactSetup.TestHelper.psm1'

# Set Global Mocks
Mock Get-ChildItem -ModuleName 'TransactSetup' {[pscustomobject]@{FullName = 'C:\Installer\Transact\Installer.msi'}}
Mock Start-Process -ModuleName 'TransactSetup' {}
Mock Set-Content -ModuleName 'TransactSetup' {}

# Set Global Variables
$InstallerPath = '.\tests\resources'
$InstallerMSI = 'C:\Installer\Transact\Installer.msi'
$Params = @{
  MethodsToMock = @('PrepareConfigProperties','Fix2020CronJobIssue','SetHostWebProperties','SetTransactLicense','StartService','DemandServiceExists')
  InstallerPath = $InstallerPath
}

# Create object for global use
$Instance = New-TransactSetupObject @Params

Describe "TransactSetup.Set()" {

  Context "Ensure is present when service does not exist" {
    $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name TestServiceExists -Value { $false } -Force -PassThru

    # Run Test
    $Instance.Set()

    It "Passes Correct Installer Path To Start-Process" {
      Assert-MockCalled Start-Process -ModuleName 'TransactSetup' -ParameterFilter {
        $FilePath -eq $InstallerMSI
      }
    }

    It "Passes Correct Config File Path To Start-Process" {
      Assert-MockCalled Start-Process -ModuleName 'TransactSetup' -Exactly 1 -ParameterFilter {
        $ArgumentList -split(' ') -contains "USERINPUTSPATH=`"$InstallerPath\config.properties`""
      }
    }
  }

  Context "Ensure is Present When Service Already Exists" {
    Mock Get-Service -ModuleName 'TransactSetup' {$true}
    Mock Start-Service -ModuleName 'TransactSetup' {}

    # Run Test
    $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name TestServiceExists -Value { $true } -Force -PassThru
    $Instance.Set()
    It "Does not process if the service is already present" {
      Assert-MockCalled Start-Process -ModuleName TransactSetup -Exactly 0
    }
  }

  Context "Ensure is Absent When Service Exists" {
    Mock Get-Service -ModuleName 'TransactSetup' {$true}

    # Configure context specific properties
    $Instance.Ensure = 'Absent'

    # Run Test
    $Instance.Set()

    It "Passes Correct Installer Path to Start-Process" {
      Assert-MockCalled Start-Process -ModuleName TransactSetup -ParameterFilter {
        $FilePath -eq 'msiexec'
      }
    }
  }

  Context "Ensure is Absent When Serice Does Not Exist" {
    Mock Get-Service -ModuleName TransactSetup {$null}

    # Configure context specific properties
    $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name TestServiceExists -Value { $false } -Force -PassThru
    $Instance.Ensure = 'Absent'

    # Run Test
    $Instance.Set()

    It "Does not process if the service does not exist" {
      Assert-MockCalled Start-Process -ModuleName TransactSetup -Exactly 0
    }
  }

  Context "Version Specified is 2019.2 or earlier" {
    $Version = '2019.2'

    # Context specific Mocks
    Mock Get-Content -ModuleName 'TransactSetup' {'Test=2020'}
    Mock Get-Service -ModuleName 'TransactSetup' {$true}

    # Create new object and do not mock Fix2020CronJobIssue method
    $Params.Version = $Version
    $Params.MethodsToMock = @('PrepareConfigProperties','SetHostWebProperties','SetTransactLicense','StartService','DemandServiceExists')
    $Instance = $Instance = New-TransactSetupObject @Params
    $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name TestServiceExists -Value { $false } -Force -PassThru
    $Instance.Set()

    It "Applies fix to cron job text" {
      Assert-MockCalled Set-Content -ModuleName 'TransactSetup' -ParameterFilter {
           $Value -like "Test=*"
      }
    }
  }

  Context "Version Specified is 2020.1 or later" {
    $Version = '2020.1'

    # Context specific Mocks
    Mock Get-Content -ModuleName 'TransactSetup' {'Test=2020'}
    Mock Get-Service -ModuleName 'TransactSetup' {$true}

    # Create new object and do not mock Fix2020CronJobIssue method
    $Params.Version = $Version
    $Params.MethodsToMock = @('PrepareConfigProperties','SetHostWebProperties','SetTransactLicense','StartService','DemandServiceExists')
    $Instance = $Instance = New-TransactSetupObject @Params
    $Instance = $Instance | Add-Member -MemberType ScriptMethod -Name TestServiceExists -Value { $false } -Force -PassThru
    $Instance.Set()

    It "Does not apply fix to cron job text" {
      Assert-MockCalled Set-Content -ModuleName 'TransactSetup' -Exactly 0
    }
  }
}
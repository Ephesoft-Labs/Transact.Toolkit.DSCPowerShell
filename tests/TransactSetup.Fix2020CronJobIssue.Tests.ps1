using module '.\TransactSetup.TestHelper.psm1'

# Set Global Mocks
Mock Set-Content -ModuleName 'TransactSetup' {}

# Create object for global use
$Instance = New-TransactSetupObject

Describe "TransactSetup.Fix2020CronJob()" {
  $CronJobEndYear = $Instance.CronEndYear

  Context "Cron job end year $CronJobEndYear specified" {
    # Create context specific mock
    Mock Get-Content -ModuleName 'TransactSetup' {'Test=2020'}

    # Create context specific object
    $Instance.Fix2020CronJobIssue()

    It "Updates references to end year 2020 to $CronJobEndYear" {
      Assert-MockCalled Set-Content -ModuleName TransactSetup -Exactly 2 -ParameterFilter{
        $Value -like "Test=$CronJobEndYear"
      }
    }
  }
}

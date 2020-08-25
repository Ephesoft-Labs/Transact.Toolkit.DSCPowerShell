using module '.\TransactSetup.TestHelper.psm1'

# Create global mocks
Mock Start-Service -ModuleName 'TransactSetup' {}

# Create object for global use
$Instance = New-TransactSetupObject

Describe "TransactSetup.StartService()" {

  Context "Service is already running" {

    # Context specific mocks
    Mock Get-Service -ModuleName 'TransactSetup' {@{status = 'running'}}

    # Call the method
    $Instance.StartService()

    It "Does nothing" {
      Assert-MockCalled Start-Service -ModuleName 'TransactSetup' -Exactly 0
    }
  }

  Context "Service is not running" {

    # Context specific mocks
    Mock Get-Service -ModuleName 'TransactSetup' {@{status = 'stopped'}}

    # Call the method
    $Instance.StartService()

    It "Attempts to Start the service" {
      Assert-MockCalled Start-Service -ModuleName 'TransactSetup' -Exactly 1 -ParameterFilter {
        $ServiceName -eq $Instance.ServiceName
      }
    }
  }
}
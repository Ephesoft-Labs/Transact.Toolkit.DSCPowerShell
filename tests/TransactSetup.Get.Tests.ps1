using module '.\TransactSetup.TestHelper.psm1'

# Create object for global use
$Instance = New-TransactSetupObject

Describe "TransactSetup.Get()" {

  Context "Transact service exists" {
    Mock Get-Service -ModuleName TransactSetup {$True}

    $Data = $Instance.Get()
    It "Returns Ensure as Present" {
      $Data.Ensure | Should -Be 'Present'
    }
  }

  Context "Transact service does not exist" {
    Mock Get-Service -ModuleName TransactSetup {}
    $Data = $Instance.Get()

    It "Returns Ensure as Absent" {
      $Data.Ensure | Should -Be 'Absent'
    }
  }
}
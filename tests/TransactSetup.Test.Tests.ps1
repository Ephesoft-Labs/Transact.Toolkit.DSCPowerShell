using module '.\TransactSetup.TestHelper.psm1'

# Create object for global use
$Instance = New-TransactSetupObject

Describe "TransactSetup.Test()" {

  Context "Transact service exists" {
    Mock Get-Service -ModuleName TransactSetup {$true}

    It "Returns true" {
      $Instance.Test() | Should -Be $true
    }
  }

  Context "Transact service does not exist" {
    Mock Get-Service -ModuleName TransactSetup {}

    It "Returns true" {
      $Instance.Test() | Should -Be $false
    }
  }
}
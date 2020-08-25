using module '.\TransactSetup.TestHelper.psm1'

# Set Global Mocks
Mock Start-Process -ModuleName 'TransactSetup' {}
Mock Copy-Item -ModuleName 'TransactSetup' {}
Mock Test-Path -ModuleName 'TransactSetup' {$true}

# Set global variables
$LicenseFilePath = 'C:\Installers\License\Ephesoft.lic'

# Create object for global use
$Instance = New-TransactSetupObject -LicenseFilePath $LicenseFilePath

Describe "TransactSetup.SetTransactLicense()" {
  Context "License file exists in provided path" {

    # Create context specific object
    $Instance.SetTransactLicense()

    It "Copies the specified file to the correct destination" {
      Assert-MockCalled Copy-Item -ModuleName TransactSetup -ParameterFilter {
        $Path -eq $LicenseFilePath -and $Destination -eq $Instance.LicenseUtilFolder
      }
    }
    It "Runs the license installer batch file from the correct location" {
      Assert-MockCalled Start-Process -ModuleName TransactSetup -ParameterFilter {
        $FilePath -eq "$($Instance.LicenseUtilFolder)\install-license.bat"
      }
    }
  }

  Context "License file does not exist in provided path" {

    # Context specific mocks
    Mock Test-Path -ModuleName 'TransactSetup' {$false}

    It "Throws an error" {
      { $Instance.SetTransactLicense() } | Should -Throw
    }

    It "Does not run the license installer batch file" {
      Assert-MockCalled Start-Process -ModuleName TransactSetup -Exactly 0
    }
  }
}
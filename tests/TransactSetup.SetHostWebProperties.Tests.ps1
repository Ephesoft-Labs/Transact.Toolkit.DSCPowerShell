using module '.\TransactSetup.TestHelper.psm1'

# Set global mocks
Mock Set-Content -ModuleName 'TransactSetup' {}

# Set global variables
$CustomHostname = 'MyCustomHostname'

# Create object for global use
$Instance = New-TransactSetupObject -Hostname $CustomHostname

Describe "TranasctSetup.SetHostWebProperties()" {
  Context "Given custom hostname" {
    # Create test specific mocks
    Mock Get-Content -ModuleName 'TransactSetup' {'wb.hostURL=http://localhost:8080/dcma/rest'} -ParameterFilter{$Path -eq $Instance.DCMAWorkFlow}
    Mock Get-Content -ModuleName 'TransactSetup' {'batch.base_http_url=http\://localhost\:8080/dcma-batches'} -ParameterFilter{$Path -eq $Instance.DCMABatch}

    # Create context specific object
    $Instance.SetHostWebProperties()

    # Iterate through each property file and verify it is being updated with the specified hostname
    Foreach ($File in @($Instance.DCMAWorkflow,$Instance.DCMABatch)) {
      It "Updates the $(Split-Path $File -Leaf) file with provided hostname"{
        Assert-MockCalled Set-Content -ModuleName TransactSetup -ParameterFilter {
          $Path -eq $File -and $Value -like "*$CustomHostname*"
        }
      }
    }
  }
}

Describe 'ScriptAnalyzer' {
	Context 'Validating ScriptAnalyzer installation' {
		It 'Checking Invoke-ScriptAnalyzer exists.' {
			{ Get-Command Invoke-ScriptAnalyzer -ErrorAction Stop } | Should Not Throw
		}
	}
}

Describe 'ScriptAnalyzer issues found' {

  # Excluding file 'MOFGnerator' because script analyzer in Bitbucket pipelines cannot parse the DSC configuration
  $ExcludedFiles = @('tests', 'examples')
  $ScriptAnalyzerSettings = @{

    <#
      PSDSCDscExamplesPresent and PSDSCDscTestsPresent excluded for running in Bitbucket pipelines
      The Ephesoft.Transact.DSC class based module cannot be imported in Linux so these tests will
      not succeed even though the examples and tests are present.
      Powershell DSC for Linux page: https://github.com/microsoft/PowerShell-DSC-for-Linux

      PSAvoidUsingCmdletAliases excluded due to 'Package' being overloaded by the DSC resource name
      'Package' and the alias for 'Get-Package'.  The Package DSC resource is referenced
      Transact.SQL.Example.ps1.
    #>
    ExcludeRules = @('PSDSCDscExamplesPresent','PSDSCDscTestsPresent','PSAvoidUsingCmdletAliases')
  }
	$results = Get-ChildItem .\* -Exclude $ExcludedFiles | Invoke-ScriptAnalyzer -Settings $ScriptAnalyzerSettings
	$scripts = $results.ScriptName | Get-Unique

	Context 'Checking results' {
		It 'Should have no issues' {
			$results.count | Should Be 0
		}
	}

	foreach ($script in $scripts) {
		Context $script {
			$issues = $results | Where-Object {$_.ScriptName -eq $script}

			foreach ($issue in $issues) {
				It "On line: $($issue.Line) - $($issue.Message)" {
					$true | Should Be $False
				}
			}
		}
	}
}
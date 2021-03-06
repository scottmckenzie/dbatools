$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 11
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\$CommandName).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'InputObject', 'ObjectName', 'IncludeStats','IncludeDataTypes','Raw','IncludeFragmentation','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}
Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $random = Get-Random
        $dbname = "dbatoolsci_$random"
        $server.Query("CREATE DATABASE $dbname")
        $server.Query("Create Table Test (col1 varchar(50) PRIMARY KEY, col2 int)",$dbname)
        $server.Query("Insert into test values ('value1',1),('value2',2)",$dbname)
        $server.Query("create statistics dbatools_stats on test (col2)", $dbname)
        $server.Query("select * from test", $dbname)
    }
    AfterAll {
        $null = Get-DbaDatabase -SqlInstance $script:instance2 -Database $dbname | Remove-DbaDatabase -Confirm:$false
    }
    Context "Command works for indexes" {
        $results = Get-DbaHelpIndex -SqlInstance $script:instance2 -Database $dbname
        It 'Results should be returned' {
            $results | Should Not BeNullOrEmpty
        }
        It 'Gets results for the test table' {
            $results.object | Should Be '[dbo].[test]'
        }
        It 'Correctly returns IndexRows of 2' {
            $results.IndexRows | Should Be 2
        }
        It 'Should not return datatype for col1' {
            $results.KeyColumns | Should Not Match 'varchar'
        }
    }
    Context "Command works when including statistics" {
        $results = Get-DbaHelpIndex -SqlInstance $script:instance2 -Database $dbname -IncludeStats | Where-Object {$_.IndexType -eq 'Statistics'}
        It 'Results should be returned' {
            $results | Should Not BeNullOrEmpty
        }
        It 'Returns dbatools_stats from test object' {
            $results.Index | Should Be 'dbatools_stats'
        }
    }
    Context "Command output includes data types" {
        $results = Get-DbaHelpIndex -SqlInstance $script:instance2 -Database $dbname -IncludeDataTypes
        It 'Results should be returned' {
            $results | Should Not BeNullOrEmpty
        }
        It 'Returns varchar for col1' {
            $results.KeyColumns | Should Match 'varchar'
        }
    }
    Context "Formatting is correct" {
        $results = Get-DbaHelpIndex -SqlInstance $script:instance2 -Database $dbname -IncludeFragmentation
        It 'Formatted as strings' {
            $results.IndexReads | Should BeOfType 'String'
            $results.IndexUpdates | Should BeOfType 'String'
            $results.SizeKB | Should BeOfType 'String'
            $results.IndexRows | Should BeOfType 'String'
            $results.IndexLookups | Should BeOfType 'String'
            $results.StatsSampleRows | Should BeOfType 'String'
            $results.IndexFragInPercent | Should BeOfType 'String'
        }
    }
    Context "Formatting is correct for raw" {
        $results = Get-DbaHelpIndex -SqlInstance $script:instance2 -Database $dbname -raw -IncludeFragmentation
        It 'Formatted as Long' {
            $results.IndexReads | Should BeOfType 'Long'
            $results.IndexUpdates | Should BeOfType 'Long'
            $results.SizeKB | Should BeOfType 'Long'
            $results.IndexRows | Should BeOfType 'Long'
            $results.IndexLookups | Should BeOfType 'Long'
        }
        It 'Formatted as Double' {
            $results.IndexFragInPercent | Should BeOfType 'Double'
        }
    }
}

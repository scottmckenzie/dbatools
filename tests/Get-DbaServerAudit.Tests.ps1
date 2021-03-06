$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 5
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaServerAudit).Parameters.Keys
        $knownParameters = 'SqlInstance','SqlCredential','Audit','ExcludeAudit','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $sql = "CREATE SERVER AUDIT LoginAudit
                TO FILE (FILEPATH = N'C:\temp',MAXSIZE = 10 MB,MAX_ROLLOVER_FILES = 1,RESERVE_DISK_SPACE = OFF)
                WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)

                CREATE SERVER AUDIT SPECIFICATION TrackAllLogins
                FOR SERVER AUDIT LoginAudit ADD (SUCCESSFUL_LOGIN_GROUP) WITH (STATE = ON)

                ALTER SERVER AUDIT LoginAudit WITH (STATE = ON)"
        $server.Query($sql)
    }
    AfterAll {
        $sql = "ALTER SERVER AUDIT SPECIFICATION TrackAllLogins WITH (STATE = OFF)
                ALTER SERVER AUDIT LoginAudit WITH (STATE = OFF)
                DROP SERVER AUDIT SPECIFICATION TrackAllLogins
                DROP SERVER AUDIT LoginAudit"
        $server.Query($sql)
    }
    Context "Verifying command output" {
        It "returns some results" {
            $results = Get-DbaServerAudit -SqlInstance $script:instance2
            $results | Should -Not -Be $null
        }
        It "returns some results" {
            $results = Get-DbaServerAudit -SqlInstance $script:instance2 -Audit LoginAudit
            $results.Name | Should -Be 'LoginAudit'
            $results.Enabled | Should -Be $true
        }
    }
}

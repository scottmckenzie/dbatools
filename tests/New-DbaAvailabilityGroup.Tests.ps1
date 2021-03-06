$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 31
        <#
            Get commands, Default count = 11
            Commands with SupportShouldProcess = 13
        #>
        $defaultParamCount = 13
        [object[]]$params = (Get-ChildItem function:\New-DbaAvailabilityGroup).Parameters.Keys
        $knownParameters = 'Primary', 'PrimarySqlCredential', 'Secondary', 'SecondarySqlCredential', 'Name', 'DtcSupport', 'ClusterType', 'AutomatedBackupPreference', 'FailureConditionLevel', 'HealthCheckTimeout', 'Basic', 'DatabaseHealthTrigger', 'Passthru', 'Database', 'NetworkShare', 'UseLastBackups', 'Force', 'AvailabilityMode', 'FailoverMode', 'BackupPriority', 'ConnectionModeInPrimaryRole', 'ConnectionModeInSecondaryRole', 'SeedingMode', 'Endpoint', 'ReadonlyRoutingConnectionUrl', 'Certificate', 'IPAddress', 'SubnetMask', 'Port', 'Dhcp', 'EnableException'
        it "Should contain our specific parameters" {
            ((Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count) | Should Be $paramCount
        }
        it "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $computername = ($script:instance3).Split("\")[0]
        $null = Get-DbaProcess -SqlInstance $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $server = Connect-DbaInstance -SqlInstance $script:instance3
        $dbname = "dbatoolsci_addag_agroupdb"
        $server.Query("create database $dbname")
        $agname = "dbatoolsci_addag_agroup"
        $null = New-DbaDbCertificate -SqlInstance $server -Database master -Name dbatoolsci_AGCert -Subject 'AG Certificate' -ErrorAction Ignore
        $null = New-DbaEndpoint -SqlInstance $script:instance3 -Type DatabaseMirroring -Name dbatoolsci_AGEndpoint -Certificate dbatoolsci_AGCert | Start-DbaEndpoint
        $backup = Get-DbaDatabase -SqlInstance $script:instance3 -Database $dbname | Backup-DbaDatabase
    }
    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $server -AvailabilityGroup $agname -Confirm:$false
        $null = Remove-DbaEndpoint -SqlInstance $server -Endpoint dbatoolsci_AGEndpoint -Confirm:$false
        $null = Get-DbaDbCertificate -SqlInstance $server -Certificate dbatoolsci_AGCert | Remove-DbaDbCertificate -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $server -Database $dbname -Confirm:$false
    }
    Context "adds an ag" {
        It "returns an ag with a db" {
            $results  = New-DbaAvailabilityGroup -Primary $script:instance3 -Name $agname -ClusterType None -FailoverMode Manual -Database $dbname -Confirm:$false -Certificate dbatoolsci_AGCert
            $results.AvailabilityDatabases.Name | Should -Be $dbname
        }
    }
} #$script:instance2 for appveyor

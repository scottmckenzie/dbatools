#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Set-DbaTcpPort {
    <#
    .SYNOPSIS
        Changes the TCP port used by the specified SQL Server.

    .DESCRIPTION
        This function changes the TCP port used by the specified SQL Server.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Credential object used to connect to the SQL Server instance as a different user

    .PARAMETER Credential
        Credential object used to connect to the Windows server itself as a different user (like SQL Configuration Manager)

    .PARAMETER Port
        TCPPort that SQLService should listen on.

    .PARAMETER IpAddress
        Which IpAddress should the portchange , if omitted allip (0.0.0.0) will be changed with the new port number.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .NOTES
        Tags: Service, Port, TCP, Configure
        Author: @H0s0n77
        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Set-DbaTcpPort

    .EXAMPLE
        PS C:\> Set-DbaTcpPort -SqlInstance sql2017 -Port 1433

        Sets the port number 1433 for all IP Addresses on the default instance on sql2017. Prompts for confirmation.

    .EXAMPLE
        PS C:\> Set-DbaTcpPort -SqlInstance winserver\sqlexpress -IpAddress 192.168.1.22 -Port 1433 -Confirm:$false

        Sets the port number 1433 for IP 192.168.1.22 on the sqlexpress instance on winserver. Does not prompt for confirmation.

    .EXAMPLE
        PS C:\> Set-DbaTcpPort -SqlInstance sql2017, sql2019 -port 1337 -Credential ad\dba

        Sets the port number 1337 for all IP Addresses on SqlInstance sql2017 and sql2019 using the credentials for ad\dba. Prompts for confirmation.

#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$Credential,
        [parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        [IpAddress[]]$IpAddress,
        [switch]$EnableException
    )
    
    begin {
        if (-not $IpAddress) {
            $IpAddress = '0.0.0.0'
        } else {
            if ($SqlInstance.Count -gt 1) {
                Stop-Function -Message "-IpAddress switch cannot be used with a collection of serveraddresses" -Target $SqlInstance
                return
            }
        }
        $scriptblock = {
            $computername = $args[0]
            $wmiinstancename = $args[1]
            $port = $args[2]
            $IpAddress = $args[3]
            $sqlinstanceName = $args[4]
            
            $wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $computername
            $wmiinstance = $wmi.ServerInstances | Where-Object {
                $_.Name -eq $wmiinstancename
            }
            $tcp = $wmiinstance.ServerProtocols | Where-Object {
                $_.DisplayName -eq 'TCP/IP'
            }
            $IpAddress = $tcp.IpAddresses | where-object {
                $_.IpAddress -eq $IpAddress
            }
            $tcpport = $IpAddress.IpAddressProperties | Where-Object {
                $_.Name -eq 'TcpPort'
            }
            
            $oldport = $tcpport.Value
            try {
                $tcpport.value = $port
                $tcp.Alter()
                [pscustomobject]@{
                    ComputerName  = $computername
                    InstanceName  = $wmiinstancename
                    SqlInstance   = $sqlinstanceName
                    OldPortNumber = $oldport
                    PortNumber    = $Port
                    Status        = "Success"
                }
            } catch {
                [pscustomobject]@{
                    ComputerName  = $computername
                    InstanceName  = $wmiinstancename
                    SqlInstance   = $sqlinstanceName
                    OldPortNumber = $oldport
                    PortNumber    = $Port
                    Status        = "Failed: $_"
                }
            }
        }
    }
    process {
        if (Test-FunctionInterrupt) {
            return
        }
        
        foreach ($instance in $SqlInstance) {
            $wmiinstancename = $instance.InstanceName
            $computerName = $instance.ComputerName
            
            if ($Pscmdlet.ShouldProcess($computerName, "Setting port to $Port for $wmiinstancename")) {
                try {
                    $computerName = $instance.ComputerName
                    $resolved = Resolve-DbaNetworkName -ComputerName $computerName
                    Invoke-ManagedComputerCommand -ComputerName $resolved.FullComputerName -ScriptBlock $scriptblock -ArgumentList $instance.ComputerName, $wmiinstancename, $port, $IpAddress, $instance.InputObject -Credential $Credential
                } catch {
                    try {
                        Invoke-ManagedComputerCommand -ComputerName $instance.ComputerName -ScriptBlock $scriptblock -ArgumentList $instance.ComputerName, $wmiinstancename, $port, $IpAddress, $instance.InputObject -Credential $Credential
                    } catch {
                        Stop-Function -Message "Failure setting port to $Port for $wmiinstancename on $computerName" -Continue
                    }
                }
            }
        }
    }
}
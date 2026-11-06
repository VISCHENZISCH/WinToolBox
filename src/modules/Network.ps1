# Network diagnostics: cmdlets return objects, independent of the Windows language.

function Get-SensitivePortLabel {
    param([Parameter(Mandatory)][int]$Port)
    $labels = @{
        21 = 'FTP'; 23 = 'Telnet'; 135 = 'RPC'; 139 = 'NetBIOS'; 445 = 'SMB'
        3389 = 'Remote Desktop'; 5900 = 'VNC'; 5985 = 'WinRM'; 5986 = 'WinRM'
    }
    return $labels[$Port]
}

function Test-TcpPort {
    param([Parameter(Mandatory)][string]$HostName, [Parameter(Mandatory)][int]$Port, [int]$TimeoutMs = 3000)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        return ($task.Wait($TimeoutMs) -and $client.Connected)
    }
    catch { return $false }
    finally { $client.Dispose() }
}

function Get-ProcessNameMap {
    $map = @{}
    Get-Process | ForEach-Object { $map[$_.Id] = $_.Name }
    return $map
}

function Show-NetworkInterfaces {
    Get-NetIPConfiguration | ForEach-Object {
        [pscustomobject]@{
            Interface  = $_.InterfaceAlias
            IPv4       = @($_.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
            Gateway    = @($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ', '
            DNS        = @($_.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ', '
        }
    } | Format-Table -AutoSize | Out-Host
    Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress | Format-Table -AutoSize | Out-Host
}

# A TCP test, because many networks block ping without blocking the Internet.
function Show-Connectivity {
    $gateway = (Get-NetIPConfiguration | ForEach-Object { $_.IPv4DefaultGateway } | Where-Object { $_ } | Select-Object -First 1).NextHop
    if ($gateway) {
        $reachable = Test-Connection -ComputerName $gateway -Count 1 -Quiet
        if ($reachable) { Write-Status OK "Gateway $gateway reachable." }
        else { Write-Status WARN "Gateway $gateway did not answer ping (some routers do not respond)." }
    }
    else { Write-Status FAIL 'No default gateway.' }

    try {
        [void][Net.Dns]::GetHostAddresses('www.microsoft.com')
        Write-Status OK 'DNS resolution works.'
    }
    catch { Write-Status FAIL 'DNS resolution failed.' }

    if (Test-TcpPort -HostName 'www.microsoft.com' -Port 443) { Write-Status OK 'Internet reachable (HTTPS).' }
    elseif (Test-TcpPort -HostName '1.1.1.1' -Port 443) { Write-Status WARN 'Internet reachable by IP only: check DNS.' }
    else { Write-Status FAIL 'Internet unreachable.' }
}

function Show-ListeningPorts {
    $processes = Get-ProcessNameMap
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | ForEach-Object {
        $exposed = $_.LocalAddress -notin '127.0.0.1', '::1'
        $label = Get-SensitivePortLabel -Port $_.LocalPort
        [pscustomobject]@{
            Port      = $_.LocalPort
            Address   = $_.LocalAddress
            Process   = $processes[[int]$_.OwningProcess]
            Alert     = if ($label -and $exposed) { "SENSITIVE: $label" } else { '' }
        }
    } | Format-Table -AutoSize | Out-Host
}

function Show-LiveConnections {
    Write-Status INFO 'Refreshing every 2 seconds.'
    while ($true) {
        $processes = Get-ProcessNameMap
        Clear-Host
        Write-Title 'Active connections (Q to go back)'
        Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notin '127.0.0.1', '::1' } |
            Select-Object @{ n = 'Process'; e = { $processes[[int]$_.OwningProcess] } }, LocalPort, RemoteAddress, RemotePort |
            Sort-Object Process | Format-Table -AutoSize | Out-Host
        $deadline = (Get-Date).AddSeconds(2)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q') { return }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Invoke-DnsFlush {
    Clear-DnsClientCache
    Write-Log -Message 'DNS cache flushed.'
    Write-Status OK 'DNS cache flushed.'
}

function Show-NetworkMenu {
    Show-Menu -Title 'Network' -Items @(
        @{ Section = 'DIAGNOSTICS'; Key = '1'; Label = 'Interfaces and addresses'; Action = { Show-NetworkInterfaces } }
        @{ Section = 'DIAGNOSTICS'; Key = '2'; Label = 'Test the connection'; Action = { Show-Connectivity } }
        @{ Section = 'MONITORING'; Key = '3'; Label = 'Listening ports'; Action = { Show-ListeningPorts } }
        @{ Section = 'MONITORING'; Key = '4'; Label = 'Live connections'; Submenu = $true; Action = { Show-LiveConnections } }
        @{ Section = 'ACTIONS'; Key = '5'; Label = 'Flush the DNS cache'; Admin = $true; Action = { Invoke-DnsFlush } }
    )
}

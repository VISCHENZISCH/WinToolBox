# Diagnostic reseau : les cmdlets renvoient des objets, independants de la langue de Windows.

function Get-SensitivePortLabel {
    param([Parameter(Mandatory)][int]$Port)
    $labels = @{
        21 = 'FTP'; 23 = 'Telnet'; 135 = 'RPC'; 139 = 'NetBIOS'; 445 = 'SMB'
        3389 = 'Bureau a distance'; 5900 = 'VNC'; 5985 = 'WinRM'; 5986 = 'WinRM'
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
            Passerelle = @($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ', '
            DNS        = @($_.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ', '
        }
    } | Format-Table -AutoSize | Out-Host
    Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress | Format-Table -AutoSize | Out-Host
}

# Un test TCP, car beaucoup de reseaux bloquent le ping sans bloquer Internet.
function Show-Connectivity {
    $gateway = (Get-NetIPConfiguration | ForEach-Object { $_.IPv4DefaultGateway } | Where-Object { $_ } | Select-Object -First 1).NextHop
    if ($gateway) {
        $reachable = Test-Connection -ComputerName $gateway -Count 1 -Quiet
        if ($reachable) { Write-Status OK "Passerelle $gateway joignable." }
        else { Write-Status WARN "Passerelle $gateway muette au ping (certains routeurs ne repondent pas)." }
    }
    else { Write-Status FAIL 'Aucune passerelle par defaut.' }

    try {
        [void][Net.Dns]::GetHostAddresses('www.microsoft.com')
        Write-Status OK 'Resolution DNS fonctionnelle.'
    }
    catch { Write-Status FAIL 'Resolution DNS en echec.' }

    if (Test-TcpPort -HostName 'www.microsoft.com' -Port 443) { Write-Status OK 'Internet joignable (HTTPS).' }
    elseif (Test-TcpPort -HostName '1.1.1.1' -Port 443) { Write-Status WARN 'Internet joignable par IP uniquement : verifiez le DNS.' }
    else { Write-Status FAIL 'Internet injoignable.' }
}

function Show-ListeningPorts {
    $processes = Get-ProcessNameMap
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | ForEach-Object {
        $exposed = $_.LocalAddress -notin '127.0.0.1', '::1'
        $label = Get-SensitivePortLabel -Port $_.LocalPort
        [pscustomobject]@{
            Port      = $_.LocalPort
            Adresse   = $_.LocalAddress
            Processus = $processes[[int]$_.OwningProcess]
            Alerte    = if ($label -and $exposed) { "SENSIBLE : $label" } else { '' }
        }
    } | Format-Table -AutoSize | Out-Host
}

function Show-LiveConnections {
    Write-Status INFO 'Actualisation toutes les 2 secondes.'
    while ($true) {
        $processes = Get-ProcessNameMap
        Clear-Host
        Write-Title 'Connexions actives (Q pour revenir)'
        Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notin '127.0.0.1', '::1' } |
            Select-Object @{ n = 'Processus'; e = { $processes[[int]$_.OwningProcess] } }, LocalPort, RemoteAddress, RemotePort |
            Sort-Object Processus | Format-Table -AutoSize | Out-Host
        $deadline = (Get-Date).AddSeconds(2)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q') { return }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Invoke-DnsFlush {
    Clear-DnsClientCache
    Write-Log -Message 'Cache DNS vide.'
    Write-Status OK 'Cache DNS vide.'
}

function Show-NetworkMenu {
    Show-Menu -Title 'Reseau' -Items @(
        @{ Section = 'DIAGNOSTIC'; Key = '1'; Label = 'Interfaces et adresses'; Action = { Show-NetworkInterfaces } }
        @{ Section = 'DIAGNOSTIC'; Key = '2'; Label = 'Tester la connexion'; Action = { Show-Connectivity } }
        @{ Section = 'SURVEILLANCE'; Key = '3'; Label = 'Ports en ecoute'; Action = { Show-ListeningPorts } }
        @{ Section = 'SURVEILLANCE'; Key = '4'; Label = 'Connexions en direct'; Submenu = $true; Action = { Show-LiveConnections } }
        @{ Section = 'ACTIONS'; Key = '5'; Label = 'Vider le cache DNS'; Admin = $true; Action = { Invoke-DnsFlush } }
    )
}

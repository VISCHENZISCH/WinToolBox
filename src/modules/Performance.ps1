# Performance of the CPU, memory, GPU, disks and network.
# CIM classes, because Get-Counter takes counter names translated into the Windows language.

$script:BarWidth = 24

# One class that cannot be read, such as the GPU counters of a virtual machine, must not hide the others.
function Get-PerfRows {
    param([Parameter(Mandatory)][string]$ClassName)
    try { return @(Get-CimInstance -ClassName $ClassName -ErrorAction Stop) }
    catch {
        Write-Verbose "$ClassName unavailable: $($_.Exception.Message)"
        return @()
    }
}

function Format-UsageBar {
    param([Parameter(Mandatory)][double]$Percent, [int]$Width = $script:BarWidth)
    $bounded = [math]::Min(100.0, [math]::Max(0.0, $Percent))
    $filled = [int][math]::Round($bounded / 100 * $Width)
    # Any activity shows at least one star, so that low use does not look like none.
    if ($bounded -gt 0 -and $filled -eq 0) { $filled = 1 }
    return [pscustomobject]@{ Stars = '*' * $filled; Rest = '.' * ($Width - $filled) }
}

function Get-UsageColor {
    param([Parameter(Mandatory)][double]$Percent)
    if ($Percent -ge 90) { return 'Red' }
    if ($Percent -ge 70) { return 'Yellow' }
    return 'Green'
}

function Write-UsageLine {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][double]$Percent, [string]$Detail = '')
    # A long name, such as that of a GPU, gets its own line rather than being cut.
    if ($Label.Length -gt 16) { Write-Host "   $Label" -ForegroundColor DarkGray }
    $name = if ($Label.Length -gt 16) { ' ' * 16 } else { $Label.PadRight(16) }
    $bar = Format-UsageBar -Percent $Percent
    Write-Host "   $name " -NoNewline
    Write-Host $bar.Stars -ForegroundColor (Get-UsageColor -Percent $Percent) -NoNewline
    Write-Host $bar.Rest -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,5:0.0} % ' -f $Percent) -ForegroundColor White -NoNewline
    $room = (Get-ConsoleWidth) - 52
    if ($room -gt 3 -and $Detail.Length -gt $room) { $Detail = $Detail.Substring(0, $room - 3) + '...' }
    Write-Host $Detail -ForegroundColor Gray
}

function ConvertTo-CpuUsage {
    param([object[]]$Rows)
    $total = @($Rows) | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
    if (-not $total) { return $null }
    $cores = @(@($Rows) | Where-Object { $_.Name -ne '_Total' })
    $busiest = ($cores | Measure-Object -Property PercentProcessorTime -Maximum).Maximum
    return [pscustomobject]@{ Percent = [double]$total.PercentProcessorTime; Threads = $cores.Count; Busiest = [double]$busiest }
}

function ConvertTo-MemoryUsage {
    param($System, $Counters)
    if (-not $System -or -not $System.TotalVisibleMemorySize) { return $null }
    $total = [double]$System.TotalVisibleMemorySize * 1KB
    $used = $total - [double]$System.FreePhysicalMemory * 1KB
    $commit = $null
    if ($Counters -and $Counters.CommitLimit) {
        $commit = [pscustomobject]@{ Used = [double]$Counters.CommittedBytes; Limit = [double]$Counters.CommitLimit; Percent = 100 * [double]$Counters.CommittedBytes / [double]$Counters.CommitLimit }
    }
    return [pscustomobject]@{ Percent = 100 * $used / $total; Used = $used; Total = $total; Commit = $commit }
}

# Use of a GPU is that of its busiest engine, as in the Task Manager: engines work in parallel, so
# adding them could pass 100%. Instances of the same engine are one per process, so those are added.
function Get-GpuEnginePeaks {
    param([object[]]$Rows, [Parameter(Mandatory)][string]$KeyPattern)
    $sums = @{}
    foreach ($row in @($Rows)) {
        if ("$($row.Name)" -notmatch $KeyPattern) { continue }
        $key = $Matches[1]
        if ("$($row.Name)" -notmatch 'engtype_(.*)$') { continue }
        $engine = "$key|$($Matches[1])"
        $sums[$engine] = [double]$sums[$engine] + [double]$row.UtilizationPercentage
    }
    $peaks = @{}
    foreach ($engine in $sums.Keys) {
        $key = $engine.Split('|')[0]
        $peaks[$key] = [math]::Min(100.0, [math]::Max([double]$peaks[$key], $sums[$engine]))
    }
    return $peaks
}

function ConvertTo-GpuUsage {
    param([object[]]$Engines, [object[]]$Memory, [object[]]$Hardware)
    $luidPattern = 'luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)'
    $peaks = Get-GpuEnginePeaks -Rows $Engines -KeyPattern $luidPattern
    $used = @{}
    foreach ($row in @($Memory)) {
        if ("$($row.Name)" -match $luidPattern) { $used[$Matches[1]] = [double]$used[$Matches[1]] + [double]$row.DedicatedUsage }
    }
    # Windows also lists virtual render adapters, which never have any use or memory.
    $adapters = @(@($peaks.Keys) + @($used.Keys) | Sort-Object -Unique | Where-Object { [double]$peaks[$_] -gt 0 -or [double]$used[$_] -gt 0 })
    # Counters only give an opaque adapter ID: a name is certain only when there is one of each.
    $single = $adapters.Count -eq 1 -and @($Hardware).Count -eq 1
    $number = 0
    foreach ($adapter in $adapters) {
        $number++
        [pscustomobject]@{
            Label   = if ($single) { @($Hardware)[0].Name } else { "GPU $number" }
            Percent = [double]$peaks[$adapter]
            Used    = [double]$used[$adapter]
            Total   = if ($single) { [double]@($Hardware)[0].Memory } else { 0 }
        }
    }
}

# Win32_VideoController stores memory in 32 bits and tops out at 4 GB, so the driver's value comes first.
function Get-GpuHardware {
    $classKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $drivers = @(Get-ChildItem -Path $classKey -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue })
    foreach ($controller in (Get-PerfRows -ClassName 'Win32_VideoController')) {
        if ($controller.Name -match 'Basic Display|Remote Display|Mirror') { continue }
        $driver = $drivers | Where-Object { $_.DriverDesc -eq $controller.Name } | Select-Object -First 1
        $size = if ($driver) { $driver.'HardwareInformation.qwMemorySize' }
        [pscustomobject]@{ Name = $controller.Name; Memory = if ($size) { [double]$size } else { [double]$controller.AdapterRAM } }
    }
}

function Get-GpuProcessRows {
    param([object[]]$Engines, [object[]]$Memory, [hashtable]$Names = @{})
    $pidPattern = 'pid_(\d+)_'
    $peaks = Get-GpuEnginePeaks -Rows $Engines -KeyPattern $pidPattern
    $used = @{}
    foreach ($row in @($Memory)) {
        if ("$($row.Name)" -match $pidPattern) { $used[$Matches[1]] = [double]$used[$Matches[1]] + [double]$row.DedicatedUsage }
    }
    @(@($peaks.Keys) + @($used.Keys) | Sort-Object -Unique | Where-Object { [double]$peaks[$_] -gt 0 -or [double]$used[$_] -gt 0 } | ForEach-Object {
            [pscustomobject]@{ Name = $Names[[int]$_]; Id = [int]$_; Percent = [double]$peaks[$_]; Memory = [double]$used[$_] }
        }) | Sort-Object Percent, Memory -Descending | Select-Object -First 15
}

# Busy time is 100 minus idle time: the "disk time" counter can pass 100 with queued requests.
function ConvertTo-DiskUsage {
    param([object[]]$Rows)
    @($Rows) | Where-Object { $_ -and $_.Name -ne '_Total' } | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Label   = "Disk $($_.Name)"
            Percent = [math]::Min(100.0, [math]::Max(0.0, 100 - [double]$_.PercentIdleTime))
            Read    = [double]$_.DiskReadBytesPersec
            Write   = [double]$_.DiskWriteBytesPersec
        }
    }
}

# Virtual adapters report no link speed. Windows machines can list many: the busiest ones are enough.
function ConvertTo-NetworkUsage {
    param([object[]]$Rows, [int]$Limit = 4)
    @($Rows) | Where-Object { $_ -and [double]$_.CurrentBandwidth -gt 0 -and $_.Name -notmatch 'isatap|teredo|loopback' } | ForEach-Object {
        $traffic = [double]$_.BytesReceivedPersec + [double]$_.BytesSentPersec
        [pscustomobject]@{
            Label    = $_.Name
            Percent  = [math]::Min(100.0, $traffic * 8 / [double]$_.CurrentBandwidth * 100)
            Received = [double]$_.BytesReceivedPersec
            Sent     = [double]$_.BytesSentPersec
            Traffic  = $traffic
        }
    } | Sort-Object Traffic -Descending | Select-Object -First $Limit
}

function Get-PerformanceSnapshot {
    return [pscustomobject]@{
        Cpu     = ConvertTo-CpuUsage -Rows (Get-PerfRows -ClassName 'Win32_PerfFormattedData_PerfOS_Processor')
        Memory  = ConvertTo-MemoryUsage -System (@(Get-PerfRows -ClassName 'Win32_OperatingSystem') | Select-Object -First 1) -Counters (@(Get-PerfRows -ClassName 'Win32_PerfFormattedData_PerfOS_Memory') | Select-Object -First 1)
        Gpus    = @(ConvertTo-GpuUsage -Engines (Get-PerfRows -ClassName 'Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine') -Memory (Get-PerfRows -ClassName 'Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory') -Hardware @(Get-GpuHardware))
        Disks   = @(ConvertTo-DiskUsage -Rows (Get-PerfRows -ClassName 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk'))
        Network = @(ConvertTo-NetworkUsage -Rows (Get-PerfRows -ClassName 'Win32_PerfFormattedData_Tcpip_NetworkInterface'))
    }
}

function Write-PerformanceSnapshot {
    param([Parameter(Mandatory)]$Snapshot)
    Write-Section 'CPU'
    if ($Snapshot.Cpu) { Write-UsageLine -Label 'Total' -Percent $Snapshot.Cpu.Percent -Detail ('{0} threads, busiest {1:0} %' -f $Snapshot.Cpu.Threads, $Snapshot.Cpu.Busiest) }
    else { Write-Status INFO 'CPU counters are not available.' }

    Write-Section 'MEMORY'
    if ($Snapshot.Memory) {
        Write-UsageLine -Label 'RAM' -Percent $Snapshot.Memory.Percent -Detail ('{0} of {1}' -f (Format-Bytes $Snapshot.Memory.Used), (Format-Bytes $Snapshot.Memory.Total))
        if ($Snapshot.Memory.Commit) { Write-UsageLine -Label 'Committed' -Percent $Snapshot.Memory.Commit.Percent -Detail ('{0} of {1}' -f (Format-Bytes $Snapshot.Memory.Commit.Used), (Format-Bytes $Snapshot.Memory.Commit.Limit)) }
    }
    else { Write-Status INFO 'Memory counters are not available.' }

    Write-Section 'GPU'
    if ($Snapshot.Gpus.Count -eq 0) { Write-Status INFO 'GPU counters are not available. Virtual machines and old drivers often have none.' }
    foreach ($gpu in $Snapshot.Gpus) {
        $detail = if ($gpu.Total -gt 0) { 'memory {0} of {1}' -f (Format-Bytes $gpu.Used), (Format-Bytes $gpu.Total) } else { 'memory {0}' -f (Format-Bytes $gpu.Used) }
        Write-UsageLine -Label $gpu.Label -Percent $gpu.Percent -Detail $detail
    }

    Write-Section 'DISKS'
    if ($Snapshot.Disks.Count -eq 0) { Write-Status INFO 'Disk counters are not available.' }
    foreach ($disk in $Snapshot.Disks) { Write-UsageLine -Label $disk.Label -Percent $disk.Percent -Detail ('read {0}/s, write {1}/s' -f (Format-Bytes $disk.Read), (Format-Bytes $disk.Write)) }

    Write-Section 'NETWORK'
    if ($Snapshot.Network.Count -eq 0) { Write-Status INFO 'No active network adapter found.' }
    foreach ($adapter in $Snapshot.Network) { Write-UsageLine -Label $adapter.Label -Percent $adapter.Percent -Detail ('in {0}/s, out {1}/s' -f (Format-Bytes $adapter.Received), (Format-Bytes $adapter.Sent)) }
}

# These counters compare two readings, so the very first one can show zero.
function Show-PerformanceSnapshot {
    $snapshot = Invoke-WithLoader 'Measuring' {
        [void](Get-PerformanceSnapshot)
        Start-Sleep -Seconds 1
        Get-PerformanceSnapshot
    }
    Write-PerformanceSnapshot -Snapshot $snapshot
}

function Show-PerformanceLive {
    Clear-Screen
    Write-Title 'Live performance (Q to go back)'
    Write-Status INFO 'Measuring...'
    [void](Get-PerformanceSnapshot)
    while ($true) {
        # Measured before clearing: reading the counters takes a moment and the screen would stay empty.
        $snapshot = Get-PerformanceSnapshot
        Clear-Screen
        Write-Title 'Live performance (Q to go back)'
        Write-PerformanceSnapshot -Snapshot $snapshot
        $deadline = (Get-Date).AddSeconds(2)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q') { return }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Show-PerformanceMenu {
    Show-Menu -Title 'Performance' -Items @(
        @{ Section = 'CPU, MEMORY, GPU, DISKS, NETWORK'; Key = '1'; Label = 'Live monitor'; Hint = 'refreshes every 2 seconds'; Submenu = $true; Action = { Show-PerformanceLive } }
        @{ Section = 'CPU, MEMORY, GPU, DISKS, NETWORK'; Key = '2'; Label = 'Snapshot'; Hint = 'one measurement'; Action = { Show-PerformanceSnapshot } }
    )
}

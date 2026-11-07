# Process management: rankings, search, details, ending a process and changing its priority.

# Ending any of these crashes or destabilizes Windows, and svchost hosts services that have their own controls.
$script:ProtectedProcesses = @(
    'Idle', 'System', 'Registry', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'LsaIso',
    'svchost', 'dwm', 'fontdrvhost', 'Memory Compression', 'MemCompression', 'MsMpEng', 'SecurityHealthService'
)

# Realtime is left out on purpose: it can starve the keyboard and disk drivers and freeze the machine.
$script:ProcessPriorities = 'Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High'

function Test-ProtectedProcess {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][int]$Id)
    return ($Id -le 4 -or $Id -eq $PID -or $script:ProtectedProcesses -contains $Name)
}

function Get-ProcessSample {
    return @(Get-Process | ForEach-Object {
            [pscustomobject]@{ Id = $_.Id; Name = $_.Name; Cpu = [double]$_.CPU; Memory = [long]$_.WorkingSet64 }
        })
}

# CPU share of each process between two samples, where 100 means every logical processor is busy.
# Idle is not work: it would top the list on any quiet machine.
function Get-ProcessCpuRows {
    param([object[]]$Before, [object[]]$After, [Parameter(Mandatory)][double]$Seconds, [int]$Processors = [Environment]::ProcessorCount)
    $start = @{}
    foreach ($item in @($Before)) { $start[[int]$item.Id] = [double]$item.Cpu }
    foreach ($item in @($After)) {
        if ($item.Name -eq 'Idle') { continue }
        $used = [double]$item.Cpu - [double]$start[[int]$item.Id]
        [pscustomobject]@{
            Id      = $item.Id
            Name    = $item.Name
            Percent = [math]::Round([math]::Max(0.0, $used) / ($Seconds * $Processors) * 100, 1)
            Memory  = $item.Memory
        }
    }
}

function Show-TopCpuProcesses {
    $rows = Invoke-WithLoader 'Measuring CPU use' {
        $before = Get-ProcessSample
        $clock = [Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Seconds 1
        Get-ProcessCpuRows -Before $before -After (Get-ProcessSample) -Seconds $clock.Elapsed.TotalSeconds
    }
    Write-Host ''
    Write-Table -Rows @($rows | Sort-Object Percent, Memory -Descending | Select-Object -First 15 Name, Id,
        @{ n = 'CPU %'; e = { '{0:0.0}' -f $_.Percent } },
        @{ n = 'Memory'; e = { Format-Bytes $_.Memory } })
}

function Show-TopProcesses {
    Write-Table -Rows @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id,
        @{ n = 'Memory'; e = { Format-Bytes $_.WorkingSet64 } },
        @{ n = 'CPU time (s)'; e = { [math]::Round($_.CPU, 1) } })
}

function Show-TopGpuProcesses {
    $rows = Invoke-WithLoader 'Measuring GPU use' {
        [void](Get-PerfRows -ClassName 'Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine')
        Start-Sleep -Seconds 1
        Get-GpuProcessRows -Engines (Get-PerfRows -ClassName 'Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine') -Memory (Get-PerfRows -ClassName 'Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory') -Names (Get-ProcessNameMap)
    }
    Write-Host ''
    Write-Table -Empty 'No GPU use reported. Virtual machines and old drivers often have no GPU counters.' -Rows @($rows | Select-Object Name, Id,
        @{ n = 'GPU %'; e = { '{0:0.0}' -f $_.Percent } },
        @{ n = 'GPU memory'; e = { Format-Bytes $_.Memory } })
}

# Asks for a name or a PID and returns one process, or $null.
function Read-ProcessSelection {
    $text = Read-Text 'Process name or PID (leave blank to cancel)'
    if (-not $text) { return $null }
    $id = 0
    if ([int]::TryParse($text, [ref]$id)) { $found = @(Get-Process -Id $id -ErrorAction SilentlyContinue) }
    else {
        $pattern = '*{0}*' -f [WildcardPattern]::Escape($text)
        $found = @(Get-Process | Where-Object { $_.Name -like $pattern } | Sort-Object WorkingSet64 -Descending)
    }
    if ($found.Count -eq 0) {
        Write-Status WARN "No process matches '$text'."
        return $null
    }
    if ($found.Count -eq 1) { return $found[0] }
    if ($found.Count -gt 30) { Write-Status INFO "$($found.Count) processes match: showing the 30 using the most memory." }
    return (Select-FromList -Items @($found | Select-Object -First 30) -Format {
            param($p)
            '{0} (PID {1}), {2}' -f $p.Name, $p.Id, (Format-Bytes $p.WorkingSet64)
        })
}

# Windows refuses to describe some processes: reading those properties throws.
function Get-ProcessField {
    param([Parameter(Mandatory)]$Process, [Parameter(Mandatory)][string]$Name)
    try {
        $value = $Process.$Name
        if ($null -eq $value) { return 'not available' }
        return $value
    }
    catch { return 'access denied' }
}

function Show-ProcessDetails {
    $process = Read-ProcessSelection
    if (-not $process) { return }
    $extra = $null
    try { $extra = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction Stop }
    catch { Write-Verbose "Process details unavailable: $($_.Exception.Message)" }
    Write-Host ''
    Write-Details ([ordered]@{
            'Name'     = $process.Name
            'PID'      = $process.Id
            'Parent'   = $(if ($extra) { $extra.ParentProcessId } else { 'not available' })
            'Path'     = Get-ProcessField $process 'Path'
            'Command'  = $(if ($extra -and $extra.CommandLine) { $extra.CommandLine } else { 'not available' })
            'Started'  = Get-ProcessField $process 'StartTime'
            'Priority' = Get-ProcessField $process 'PriorityClass'
            'Memory'   = Format-Bytes $process.WorkingSet64
            'Threads'  = @($process.Threads).Count
            'Handles'  = $process.HandleCount
        })
}

function Write-ProtectedRefusal {
    param([Parameter(Mandatory)]$Process)
    Write-Status FAIL "$($Process.Name) (PID $($Process.Id)) is needed by Windows or by WinToolBox: the operation is refused."
}

function Invoke-ProcessStop {
    $process = Read-ProcessSelection
    if (-not $process) { return }
    if (Test-ProtectedProcess -Name $process.Name -Id $process.Id) {
        Write-ProtectedRefusal -Process $process
        return
    }
    $label = '{0} (PID {1})' -f $process.Name, $process.Id
    Write-Status WARN 'Unsaved work in this process will be lost.'
    if (-not (Confirm-Action "End $label?")) { return }

    # The answer can take a while, and Windows reuses PIDs: the same process must still be running.
    $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if (-not $current) {
        Write-Status INFO "$label has already ended."
        return
    }
    if ($current.Name -ne $process.Name -or (Get-ProcessField $current 'StartTime') -ne (Get-ProcessField $process 'StartTime')) {
        Write-Status FAIL "PID $($process.Id) now belongs to another process: nothing was ended."
        return
    }
    try { Stop-Process -Id $process.Id -Force -ErrorAction Stop }
    catch {
        Write-Log -Level WARN -Message "End process ${label}: $($_.Exception.Message)"
        Write-Status FAIL "$label could not be ended: $($_.Exception.Message)"
        return
    }
    # Stop-Process only asks: success is reported once the process has actually gone.
    $deadline = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $deadline -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 100 }
    if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
        Write-Status WARN "$label was asked to end but is still running."
        return
    }
    Write-Log -Message "Process ended: $label."
    Write-Status OK "$label ended."
}

function Invoke-ProcessPriority {
    $process = Read-ProcessSelection
    if (-not $process) { return }
    if (Test-ProtectedProcess -Name $process.Name -Id $process.Id) {
        Write-ProtectedRefusal -Process $process
        return
    }
    Write-Status INFO ('Current priority: {0}. The change lasts until the process ends.' -f (Get-ProcessField $process 'PriorityClass'))
    $priority = Select-FromList -Items $script:ProcessPriorities -Format { param($name) $name }
    if (-not $priority) { return }
    try { $process.PriorityClass = $priority }
    catch {
        Write-Status FAIL "Priority not changed: $($_.Exception.Message)"
        return
    }
    Write-Log -Message "Priority of $($process.Name) (PID $($process.Id)) set to $priority."
    Write-Status OK "Priority set to $priority."
}

function Show-ProcessMenu {
    Show-Menu -Title 'Processes' -Items @(
        @{ Section = 'RANKINGS'; Key = '1'; Label = 'Top by CPU'; Hint = 'measured over one second'; Action = { Show-TopCpuProcesses } }
        @{ Section = 'RANKINGS'; Key = '2'; Label = 'Top by memory'; Action = { Show-TopProcesses } }
        @{ Section = 'RANKINGS'; Key = '3'; Label = 'Top by GPU'; Action = { Show-TopGpuProcesses } }
        @{ Section = 'ONE PROCESS'; Key = '4'; Label = 'Find and show details'; Hint = 'path, command, parent, priority'; Action = { Show-ProcessDetails } }
        @{ Section = 'ONE PROCESS'; Key = '5'; Label = 'Change the priority'; Action = { Invoke-ProcessPriority } }
        @{ Section = 'ONE PROCESS'; Key = '6'; Label = 'End a process'; Hint = 'Windows processes are refused'; Danger = $true; Action = { Invoke-ProcessStop } }
    )
}

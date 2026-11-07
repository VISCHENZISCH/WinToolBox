# Cleanup with a prior scan, and Windows repair.

function Get-CleanupTargets {
    $targets = @(
        @{ Name = 'User temporary files'; Root = $env:TEMP; MinAgeDays = 1; Admin = $false; Filter = '*' }
        @{ Name = 'Windows temporary files'; Root = (Join-Path $env:SystemRoot 'Temp'); MinAgeDays = 1; Admin = $true; Filter = '*' }
        @{ Name = 'Windows Update cache'; Root = (Join-Path $env:SystemRoot 'SoftwareDistribution\Download'); MinAgeDays = 0; Admin = $true; Filter = '*'; Service = 'wuauserv' }
        @{ Name = 'Explorer thumbnails'; Root = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'); MinAgeDays = 0; Admin = $false; Filter = 'thumbcache_*.db' }
        @{ Name = 'Crash reports'; Root = (Join-Path $env:LOCALAPPDATA 'CrashDumps'); MinAgeDays = 0; Admin = $false; Filter = '*' }
        @{ Name = 'System memory dumps'; Root = (Join-Path $env:SystemRoot 'Minidump'); MinAgeDays = 0; Admin = $true; Filter = '*' }
    )
    return $targets
}

# Selects eligible files without changing anything.
function Get-CleanupCandidates {
    param(
        [Parameter(Mandatory)][string]$Root,
        [int]$MinAgeDays = 0,
        [string]$Filter = '*',
        [datetime]$Now = [DateTime]::UtcNow
    )
    if (-not [IO.Directory]::Exists($Root)) { return @() }
    $limit = $Now.AddDays(-$MinAgeDays).Ticks
    return @((Get-FileEntries -Root $Root).Files | Where-Object {
            $_.Ticks -le $limit -and [IO.Path]::GetFileName($_.Rel) -like $Filter
        })
}

# Deletes the candidates and then empty folders; locked files are counted, not hidden.
function Remove-CleanupCandidates {
    param([Parameter(Mandatory)][string]$Root, [object[]]$Candidates)
    $freed = [long]0
    $locked = 0
    foreach ($file in $Candidates) {
        try {
            [IO.File]::Delete((ConvertTo-LongPath ([IO.Path]::Combine($Root, $file.Rel))))
            $freed += $file.Size
        }
        catch { $locked++ }
    }
    $listing = Get-FileEntries -Root $Root
    foreach ($dir in ($listing.Dirs | Sort-Object Length -Descending)) {
        $path = ConvertTo-LongPath ([IO.Path]::Combine($Root, $dir))
        try {
            if ([IO.Directory]::GetFileSystemEntries($path).Length -eq 0) { [IO.Directory]::Delete($path) }
        }
        catch { Write-Verbose "Folder kept: $dir" }
    }
    return [pscustomobject]@{ Freed = $freed; Locked = $locked }
}

function Get-RecycleBinSize {
    try {
        $shell = New-Object -ComObject Shell.Application
        $total = [long]0
        foreach ($item in $shell.Namespace(10).Items()) { $total += [long]$item.ExtendedProperty('Size') }
        return $total
    }
    catch { return [long]0 }
}

# Measured after the fact: Clear-RecycleBin can fail silently, so success is never assumed.
function Invoke-RecycleBinClear {
    param([Parameter(Mandatory)][long]$SizeBefore)
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    $left = [long](Get-RecycleBinSize)
    return [pscustomobject]@{ Freed = [math]::Max([long]0, $SizeBefore - $left); Left = $left }
}

function Invoke-CleanupWizard {
    $isAdmin = Test-IsAdmin
    $rows = New-Object 'System.Collections.Generic.List[object]'
    Write-Status INFO 'Scanning, nothing is deleted at this stage.'
    Write-Section 'What can be deleted'
    foreach ($target in Get-CleanupTargets) {
        if ($target.Admin -and -not $isAdmin) { continue }
        $candidates = @(Get-CleanupCandidates -Root $target.Root -MinAgeDays $target.MinAgeDays -Filter $target.Filter)
        $size = ($candidates | Measure-Object -Property Size -Sum).Sum
        $rows.Add([pscustomobject]@{ Name = $target.Name; Target = $target; Candidates = $candidates; Size = [long]$size })
    }
    $rows.Add([pscustomobject]@{ Name = 'Recycle Bin (all drives)'; Target = $null; Candidates = @(); Size = (Get-RecycleBinSize) })

    for ($i = 0; $i -lt $rows.Count; $i++) {
        Write-Host ('   [{0}] {1,-38} {2,10}' -f ($i + 1), $rows[$i].Name, (Format-Bytes $rows[$i].Size))
    }
    if (-not $isAdmin) {
        Write-Host ''
        Write-Status INFO 'System caches require administrator rights.'
    }
    Write-Host ''
    $answer = Read-Text 'Numbers separated by commas, A for all, leave blank to cancel'
    if (-not $answer) { return }

    $selected = if ($answer -ieq 'A') { @($rows) } else {
        @($answer -split '[,; ]+' | ForEach-Object {
                $n = 0
                if ([int]::TryParse($_, [ref]$n) -and $n -ge 1 -and $n -le $rows.Count) { $rows[$n - 1] }
            })
    }
    if ($selected.Count -eq 0) {
        Write-Status WARN 'No valid selection.'
        return
    }
    $announced = ($selected | Measure-Object -Property Size -Sum).Sum
    if (-not (Confirm-Action ('Delete about {0}?' -f (Format-Bytes $announced)))) { return }

    $totalFreed = [long]0
    $totalLocked = 0
    $summary = New-Object 'System.Collections.Generic.List[object]'
    foreach ($row in $selected) {
        if ($null -eq $row.Target) {
            $bin = Invoke-WithLoader 'Emptying the Recycle Bin' { Invoke-RecycleBinClear -SizeBefore $row.Size }
            $totalFreed += $bin.Freed
            $summary.Add([pscustomobject]@{ Item = $row.Name; Freed = Format-Bytes $bin.Freed; 'Files kept' = $(if ($bin.Left) { "$(Format-Bytes $bin.Left) left" } else { '0' }) })
            continue
        }
        $service = $null
        if ($row.Target.Service) {
            $service = Get-Service -Name $row.Target.Service -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') { Stop-Service -InputObject $service -Force } else { $service = $null }
        }
        try {
            $result = Invoke-WithLoader "Cleaning: $($row.Name)" { Remove-CleanupCandidates -Root $row.Target.Root -Candidates $row.Candidates }
        }
        finally {
            if ($service) { Start-Service -InputObject $service }
        }
        $totalFreed += $result.Freed
        $totalLocked += $result.Locked
        $summary.Add([pscustomobject]@{ Item = $row.Name; Freed = Format-Bytes $result.Freed; 'Files kept' = $result.Locked })
    }
    Write-Section 'Result'
    Write-Table -Rows $summary.ToArray()
    Write-Log -Message "Cleanup: $totalFreed bytes freed, $totalLocked files kept."
    Write-Host ''
    Write-Status OK ('Total freed: {0}.' -f (Format-Bytes $totalFreed))
}

function Write-RepairResult {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][int]$Code)
    Write-Log -Message "${Label}: code $Code."
    if ($Code -eq 0) { Write-Status OK "$Label completed." }
    else { Write-Status FAIL "$Label returned code $Code." }
}

function Invoke-DismRepair {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Operation)
    Write-Status INFO "${Label}: this operation may take several minutes."
    $code = Invoke-QuietTool -Label $Label -Command 'dism.exe' -Arguments '/English', '/Online', '/Cleanup-Image', $Operation
    Write-RepairResult -Label $Label -Code $code
}

# What the check found, from the [SR] lines it added to the log. $null if the log cannot tell.
function Get-SfcResult {
    param([Parameter(Mandatory)][string]$LogPath, [Parameter(Mandatory)][datetime]$Since)
    $completed = $false
    $repaired = 0
    $unrepaired = 0
    $reader = $null
    try {
        # Shared access: Windows can keep this log open for writing.
        $stream = [IO.FileStream]::new($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        $reader = [IO.StreamReader]::new($stream)
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line -notmatch '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).*\[SR\] (.*)$') { continue }
            $text = $Matches[2]
            if ([datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) -lt $Since) { continue }
            if ($text -like 'Verify complete*') { $completed = $true }
            elseif ($text -like 'Cannot repair member file*') { $unrepaired++ }
            elseif ($text -like 'Repaired file*') { $repaired++ }
        }
    }
    catch {
        Write-Verbose "SFC log unavailable: $($_.Exception.Message)"
        return $null
    }
    finally { if ($reader) { $reader.Dispose() } }
    if (-not $completed) { return $null }
    return [pscustomobject]@{ Repaired = $repaired; Unrepaired = $unrepaired }
}

function Invoke-SfcCheck {
    $label = 'SFC check'
    $logPath = Join-Path $env:SystemRoot 'Logs\CBS\CBS.log'
    $start = Get-Date
    Write-Status INFO "${label}: this operation may take several minutes."
    $code = Invoke-QuietTool -Label $label -Command 'sfc.exe' -Arguments '/scannow'
    Write-Log -Message "${label}: code $code."
    $result = Get-SfcResult -LogPath $logPath -Since $start
    # "No problem" is only stated when the log confirms it: the exit code does not say so.
    if (-not $result) { Write-Status WARN "$label finished with code $code, but its result could not be read. See $logPath" }
    elseif ($result.Unrepaired) { Write-Status FAIL "$($result.Unrepaired) damaged files could not be repaired. See $logPath" }
    elseif ($result.Repaired) { Write-Status OK "$($result.Repaired) damaged files were repaired." }
    else { Write-Status OK 'No damaged system files found.' }
}

function Show-MaintenanceMenu {
    Show-Menu -Title 'Cleanup and repair' -Items @(
        @{ Section = 'CLEANUP'; Key = '1'; Label = 'Scan and clean'; Hint = 'shows what can be deleted first'; Action = { Invoke-CleanupWizard } }
        @{ Section = 'CLEANUP'; Key = '2'; Label = 'Shrink the Windows component store'; Admin = $true; Action = { Invoke-DismRepair -Label 'Component cleanup' -Operation '/StartComponentCleanup' } }
        @{ Section = 'REPAIR'; Key = '3'; Label = 'Repair the Windows image (DISM)'; Admin = $true; Action = { Invoke-DismRepair -Label 'DISM repair' -Operation '/RestoreHealth' } }
        @{ Section = 'REPAIR'; Key = '4'; Label = 'Check system files (SFC)'; Admin = $true; Action = { Invoke-SfcCheck } }
    )
}

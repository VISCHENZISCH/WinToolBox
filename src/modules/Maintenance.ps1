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

function Invoke-CleanupWizard {
    $isAdmin = Test-IsAdmin
    $rows = New-Object 'System.Collections.Generic.List[object]'
    Write-Status INFO 'Scanning, nothing is deleted at this stage.'
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
    if (-not $isAdmin) { Write-Status INFO 'System caches require administrator rights.' }
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
    foreach ($row in $selected) {
        if ($null -eq $row.Target) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            $totalFreed += $row.Size
            Write-Status OK "$($row.Name): emptied."
            continue
        }
        $service = $null
        if ($row.Target.Service) {
            $service = Get-Service -Name $row.Target.Service -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') { Stop-Service -InputObject $service -Force } else { $service = $null }
        }
        try {
            $result = Remove-CleanupCandidates -Root $row.Target.Root -Candidates $row.Candidates
        }
        finally {
            if ($service) { Start-Service -InputObject $service }
        }
        $totalFreed += $result.Freed
        $totalLocked += $result.Locked
        Write-Status OK ('{0}: {1} freed, {2} files in use kept.' -f $row.Name, (Format-Bytes $result.Freed), $result.Locked)
    }
    Write-Log -Message "Cleanup: $totalFreed bytes freed, $totalLocked files kept."
    Write-Host ''
    Write-Status OK ('Total freed: {0}.' -f (Format-Bytes $totalFreed))
}

# The commands show their own progress; only their exit code decides the result.
function Invoke-RepairCommand {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Command, [string[]]$Arguments)
    Write-Status INFO "${Label}: this operation may take several minutes."
    & $Command @Arguments | Out-Host
    $code = $LASTEXITCODE
    Write-Log -Message "${Label}: code $code."
    if ($code -eq 0) { Write-Status OK "$Label completed." }
    else { Write-Status FAIL "$Label returned code $code." }
}

function Show-MaintenanceMenu {
    Show-Menu -Title 'Cleanup and repair' -Items @(
        @{ Section = 'CLEANUP'; Key = '1'; Label = 'Scan and clean'; Action = { Invoke-CleanupWizard } }
        @{ Section = 'CLEANUP'; Key = '2'; Label = 'Shrink the Windows component store'; Admin = $true; Action = { Invoke-RepairCommand -Label 'Component cleanup' -Command 'dism.exe' -Arguments '/Online', '/Cleanup-Image', '/StartComponentCleanup' } }
        @{ Section = 'REPAIR'; Key = '3'; Label = 'Repair the Windows image (DISM)'; Admin = $true; Action = { Invoke-RepairCommand -Label 'DISM repair' -Command 'dism.exe' -Arguments '/Online', '/Cleanup-Image', '/RestoreHealth' } }
        @{ Section = 'REPAIR'; Key = '4'; Label = 'Check system files (SFC)'; Admin = $true; Action = { Invoke-RepairCommand -Label 'SFC check' -Command 'sfc.exe' -Arguments '/scannow' } }
    )
}

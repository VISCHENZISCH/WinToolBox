# Versioned file backup.
#
# Repository: <destination>\<set>\<id>\ with data\ (copied files), files.tsv (full state of the
# source), dirs.txt, errors.txt and meta.json. A backup is built in .tmp-<id> and then
# renamed, so an existing <id> folder is always complete. For each file, files.tsv records
# the backup that stores it, which makes every version directly restorable.

function Get-BackupSetName {
    param([Parameter(Mandatory)][string]$Source)
    $clean = $Source.TrimEnd('\', '/')
    $leaf = [IO.Path]::GetFileName($clean)
    # On-disk identifier, deliberately not translated: renaming it would orphan existing
    # drive-root backup sets and silently start a new chain.
    if (-not $leaf) { $leaf = 'Disque' }
    $leaf = $leaf -replace '[^\w.-]', '_'
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($clean.ToLowerInvariant()))
    }
    finally { $sha.Dispose() }
    return ('{0}-{1}' -f $leaf, ([BitConverter]::ToString($hash, 0, 4).Replace('-', '').ToLowerInvariant()))
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead((ConvertTo-LongPath $Path))
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

# TSV format: tabs are not allowed in NTFS file names.
function Write-Manifest {
    param([Parameter(Mandatory)][string]$Path, [object[]]$Entries)
    $writer = [IO.StreamWriter]::new($Path, $false, [Text.UTF8Encoding]::new($false))
    try {
        foreach ($entry in $Entries) {
            $writer.WriteLine(($entry.Size, $entry.Ticks, $entry.Hash, $entry.Store, $entry.Rel) -join "`t")
        }
    }
    finally { $writer.Dispose() }
}

function Read-Manifest {
    param([Parameter(Mandatory)][string]$Path)
    foreach ($line in [IO.File]::ReadLines($Path)) {
        $fields = $line.Split([char[]]"`t", 5)
        [pscustomobject]@{
            Size  = [long]$fields[0]
            Ticks = [long]$fields[1]
            Hash  = $fields[2]
            Store = $fields[3]
            Rel   = $fields[4]
        }
    }
}

function Get-BackupCatalog {
    param([Parameter(Mandatory)][string]$SetPath)
    if (-not [IO.Directory]::Exists($SetPath)) { return }
    $found = foreach ($dir in [IO.Directory]::GetDirectories($SetPath)) {
        $id = [IO.Path]::GetFileName($dir)
        $metaPath = [IO.Path]::Combine($dir, 'meta.json')
        if ($id -match '^\d{8}-\d{9}-(full|incr)$' -and [IO.File]::Exists($metaPath)) {
            $meta = [IO.File]::ReadAllText($metaPath) | ConvertFrom-Json
            $meta | Add-Member -NotePropertyName Path -NotePropertyValue $dir -PassThru
        }
    }
    @($found) | Where-Object { $_ } | Sort-Object Id
}

function Resolve-BackupMode {
    param(
        [Parameter(Mandatory)][string]$Requested,
        [object[]]$Catalog,
        [int]$FullEvery = 0
    )
    $Catalog = @($Catalog | Where-Object { $_ })
    if ($Requested -eq 'Full' -or $Catalog.Count -eq 0) { return 'Full' }
    if ($FullEvery -gt 0) {
        $sinceFull = 0
        for ($i = $Catalog.Count - 1; $i -ge 0 -and $Catalog[$i].Type -ne 'Full'; $i--) { $sinceFull++ }
        if ($sinceFull -ge $FullEvery - 1) { return 'Full' }
    }
    return 'Incremental'
}

function Assert-BackupPaths {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
    if (-not [IO.Directory]::Exists($Source)) { throw "Source not found: $Source" }
    if ((Test-PathInside -Child $Destination -Parent $Source) -or (Test-PathInside -Child $Source -Parent $Destination)) {
        throw 'The source and destination must not be nested.'
    }
}

function Get-FreeBytes {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetPathRoot($Path)
    if ($root.StartsWith('\\')) { return $null }
    try { return ([IO.DriveInfo]::new($root)).AvailableFreeSpace }
    catch { return $null }
}

function Assert-FreeSpace {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][long]$Needed)
    $free = Get-FreeBytes $Path
    if ($null -ne $free -and $free -lt $Needed) {
        throw ('Not enough space on {0}: {1} required, {2} free.' -f $Path, (Format-Bytes $Needed), (Format-Bytes $free))
    }
}

function Remove-Tree {
    param([Parameter(Mandatory)][string]$Path)
    Remove-Item -LiteralPath (ConvertTo-LongPath $Path) -Recurse -Force
}

function Get-RobocopyCommonArgs {
    $arguments = @('/COPY:DAT', '/DCOPY:T', '/R:2', '/W:5', '/NP', '/NFL', '/NDL', '/NJH', '/NJS')
    if ($script:LogFile) { $arguments += "/UNILOG+:$($script:LogFile).robocopy" }
    # /B reads files protected by their permissions, but requires the backup privilege.
    if (Test-IsAdmin) { $arguments += '/B' }
    return $arguments
}

# Robocopy returns a bitmask: 8 or higher means some files were not copied.
function Invoke-Robocopy {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & robocopy.exe @Arguments | Out-Null
    return $LASTEXITCODE
}

function Copy-Tree {
    param(
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )
    $arguments = @($From, $To, '/E', '/MT:16') + (Get-RobocopyCommonArgs)
    if ($ExcludeDirs.Count) { $arguments += @('/XD') + $ExcludeDirs }
    if ($ExcludeFiles.Count) { $arguments += @('/XF') + $ExcludeFiles }
    return (Invoke-Robocopy -Arguments $arguments)
}

# Copies specific files from one folder, in batches to respect the command length limit.
function Copy-FileGroup {
    param(
        [Parameter(Mandatory)][string]$FromDir,
        [Parameter(Mandatory)][string]$ToDir,
        [Parameter(Mandatory)][string[]]$Names
    )
    $worst = 0
    $batch = New-Object 'System.Collections.Generic.List[string]'
    $length = 0
    $common = @('/IS', '/IT') + (Get-RobocopyCommonArgs)
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $batch.Add($Names[$i])
        $length += $Names[$i].Length + 3
        if ($length -ge 24000 -or $i -eq $Names.Count - 1) {
            $code = Invoke-Robocopy -Arguments (@($FromDir, $ToDir) + $batch.ToArray() + $common)
            if ($code -gt $worst) { $worst = $code }
            $batch.Clear()
            $length = 0
        }
    }
    return $worst
}

function Group-EntriesForCopy {
    param([object[]]$Entries, [Parameter(Mandatory)][scriptblock]$StoreSelector)
    $groups = @{}
    foreach ($entry in $Entries) {
        $dir = [IO.Path]::GetDirectoryName($entry.Rel)
        $store = & $StoreSelector $entry
        $key = "$store|$dir"
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = [pscustomobject]@{
                Store = $store
                Dir   = $dir
                Names = New-Object 'System.Collections.Generic.List[string]'
            }
        }
        $groups[$key].Names.Add([IO.Path]::GetFileName($entry.Rel))
    }
    return $groups.Values
}

# VSS snapshot: allows reading open files (administrator rights required).
function New-VssSnapshot {
    param([Parameter(Mandatory)][string]$Volume)
    $created = Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{ Volume = $Volume; Context = 'ClientAccessible' }
    if ($created.ReturnValue -ne 0) { throw "Could not create the VSS snapshot (code $($created.ReturnValue))." }
    $shadow = Get-CimInstance -ClassName Win32_ShadowCopy -Filter "ID='$($created.ShadowID)'"
    # %SystemRoot%\Temp is not writable by a standard account, unlike %TEMP%.
    $link = Join-Path $env:SystemRoot ("Temp\wtb-vss-{0}" -f [guid]::NewGuid().ToString('N'))
    & cmd.exe /c mklink /d "$link" "$($shadow.DeviceObject)\" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-CimInstance -InputObject $shadow
        throw "Could not mount the VSS snapshot."
    }
    return [pscustomobject]@{ Shadow = $shadow; Link = $link }
}

function Remove-VssSnapshot {
    param([Parameter(Mandatory)][object]$Snapshot)
    & cmd.exe /c rmdir "$($Snapshot.Link)" | Out-Null
    Remove-CimInstance -InputObject $Snapshot.Shadow
}

function New-Backup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [ValidateSet('Full', 'Incremental')][string]$Mode = 'Incremental',
        [switch]$UseVss,
        [int]$FullEvery = 0,
        [int]$KeepChains = 0,
        [string[]]$ExcludeDirs = @('$RECYCLE.BIN', 'System Volume Information'),
        [string[]]$ExcludeFiles = @('pagefile.sys', 'hiberfil.sys', 'swapfile.sys')
    )
    $Source = Resolve-FullPath $Source
    $Destination = Resolve-FullPath $Destination
    Assert-BackupPaths -Source $Source -Destination $Destination

    $setPath = [IO.Path]::Combine($Destination, (Get-BackupSetName $Source))
    [void][IO.Directory]::CreateDirectory($setPath)
    # The exclusive lock stops a manual backup and a scheduled task from overlapping.
    $lock = [IO.File]::Open([IO.Path]::Combine($setPath, '.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $snapshot = $null
    $tempDir = $null
    try {
        foreach ($stale in [IO.Directory]::GetDirectories($setPath, '.tmp-*')) { Remove-Tree $stale }

        $catalog = @(Get-BackupCatalog -SetPath $setPath)
        $effectiveMode = Resolve-BackupMode -Requested $Mode -Catalog $catalog -FullEvery $FullEvery
        $previous = @{}
        $previousCount = 0
        if ($effectiveMode -eq 'Incremental') {
            foreach ($entry in Read-Manifest -Path ([IO.Path]::Combine($catalog[-1].Path, 'files.tsv'))) {
                $previous[$entry.Rel] = $entry
                $previousCount++
            }
        }

        $readRoot = $Source
        if ($UseVss) {
            $volume = [IO.Path]::GetPathRoot($Source)
            if ($volume.StartsWith('\\')) { throw 'VSS does not work on a network share.' }
            $snapshot = New-VssSnapshot -Volume $volume
            $readRoot = [IO.Path]::Combine($snapshot.Link, $Source.Substring($volume.Length))
        }

        Write-Progress -Activity 'Backup' -Status 'Scanning the source'
        $listing = Get-FileEntries -Root $readRoot -ExcludeDirs $ExcludeDirs -ExcludeFiles $ExcludeFiles

        $entries = New-Object 'System.Collections.Generic.List[object]'
        $toCopy = New-Object 'System.Collections.Generic.List[object]'
        $bytesToCopy = [long]0
        foreach ($file in $listing.Files) {
            $known = $previous[$file.Rel]
            if ($known -and $known.Size -eq $file.Size -and $known.Ticks -eq $file.Ticks) {
                $entries.Add($known)
            }
            else {
                $toCopy.Add($file)
                $bytesToCopy += $file.Size
            }
        }

        if ($effectiveMode -eq 'Incremental' -and $toCopy.Count -eq 0 -and $entries.Count -eq $previousCount) {
            Write-Log -Message "Backup ${Source}: no change."
            return [pscustomobject]@{ Status = 'NoChange'; Id = $catalog[-1].Id; SetPath = $setPath; CopiedFiles = 0; CopiedBytes = 0; TotalFiles = $entries.Count; Failed = 0; Unreadable = $listing.Errors.Count; Links = $listing.Links.Count; Chain = $effectiveMode }
        }
        Assert-FreeSpace -Path $Destination -Needed $bytesToCopy

        $suffix = if ($effectiveMode -eq 'Full') { 'full' } else { 'incr' }
        $id = '{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff'), $suffix
        $tempDir = [IO.Path]::Combine($setPath, ".tmp-$id")
        $dataDir = [IO.Path]::Combine($tempDir, 'data')
        [void][IO.Directory]::CreateDirectory($dataDir)

        # A whole-tree copy is much faster for a full backup, as long as the
        # link exclusion list fits within the maximum command length.
        $linkPaths = @($listing.Links | ForEach-Object { [IO.Path]::Combine($readRoot, $_) })
        $linkLength = ($linkPaths | Measure-Object -Property Length -Sum).Sum
        Write-Progress -Activity 'Backup' -Status ('Copying {0} files ({1})' -f $toCopy.Count, (Format-Bytes $bytesToCopy))
        if ($effectiveMode -eq 'Full' -and $linkLength -lt 20000) {
            [void](Copy-Tree -From $readRoot -To $dataDir -ExcludeDirs (@($ExcludeDirs) + $linkPaths) -ExcludeFiles (@($ExcludeFiles) + $linkPaths))
            # Copying a drive root makes the target folder hidden and system.
            if (Test-IsWindows) { [IO.File]::SetAttributes($dataDir, [IO.FileAttributes]::Directory) }
        }
        else {
            foreach ($group in Group-EntriesForCopy -Entries $toCopy -StoreSelector { 'source' }) {
                $fromDir = [IO.Path]::Combine($readRoot, $group.Dir)
                $toDir = [IO.Path]::Combine($dataDir, $group.Dir)
                [void](Copy-FileGroup -FromDir $fromDir -ToDir $toDir -Names $group.Names.ToArray())
            }
        }

        # Each copy is checked individually: the robocopy exit code does not say which
        # files are missing. A failed file keeps its previous version in the manifest.
        $failed = New-Object 'System.Collections.Generic.List[string]'
        $copiedBytes = [long]0
        $done = 0
        foreach ($file in $toCopy) {
            $done++
            if ($done % 200 -eq 0) {
                Write-Progress -Activity 'Backup' -Status 'Checking copies' -PercentComplete ([int](100 * $done / $toCopy.Count))
            }
            $stored = [IO.Path]::Combine($dataDir, $file.Rel)
            try {
                $copy = [IO.FileInfo]::new((ConvertTo-LongPath $stored))
                if (-not $copy.Exists -or $copy.Length -ne $file.Size) { throw 'copy missing or incomplete' }
                $entries.Add([pscustomobject]@{ Size = $file.Size; Ticks = $file.Ticks; Hash = (Get-FileSha256 $stored); Store = $id; Rel = $file.Rel })
                $copiedBytes += $file.Size
            }
            catch {
                $failed.Add($file.Rel)
                $known = $previous[$file.Rel]
                if ($known) { $entries.Add($known) }
            }
        }
        Write-Progress -Activity 'Backup' -Completed

        $status = if ($failed.Count -or $listing.Errors.Count) { 'Partial' } else { 'Complete' }
        Write-Manifest -Path ([IO.Path]::Combine($tempDir, 'files.tsv')) -Entries $entries.ToArray()
        [IO.File]::WriteAllLines([IO.Path]::Combine($tempDir, 'dirs.txt'), [string[]]$listing.Dirs.ToArray())
        [IO.File]::WriteAllLines([IO.Path]::Combine($tempDir, 'errors.txt'), [string[]](@($failed | ForEach-Object { "COPY`t$_" }) + @($listing.Errors | ForEach-Object { "READ`t$_" })))

        $totalBytes = ($entries | Measure-Object -Property Size -Sum).Sum
        if ($null -eq $totalBytes) { $totalBytes = 0 }
        $meta = [ordered]@{
            Schema = 1; Id = $id; Type = $effectiveMode; Status = $status; Source = $Source
            CreatedUtc = [DateTime]::UtcNow.ToString('o'); FileCount = $entries.Count; TotalBytes = [long]$totalBytes
            CopiedFiles = $toCopy.Count - $failed.Count; CopiedBytes = $copiedBytes
            Failed = $failed.Count; Unreadable = $listing.Errors.Count; Links = $listing.Links.Count
        }
        [IO.File]::WriteAllText([IO.Path]::Combine($tempDir, 'meta.json'), ($meta | ConvertTo-Json))
        [IO.Directory]::Move($tempDir, [IO.Path]::Combine($setPath, $id))
        $tempDir = $null

        if ($KeepChains -gt 0) { [void](Remove-OldBackupChains -SetPath $setPath -KeepChains $KeepChains) }

        $level = if ($status -eq 'Complete') { 'INFO' } else { 'WARN' }
        Write-Log -Level $level -Message ('Backup {0} -> {1}: {2}, {3}, {4} files copied, {5} failures, {6} unreadable folders.' -f $Source, $id, $effectiveMode, $status, $meta.CopiedFiles, $failed.Count, $listing.Errors.Count)
        return [pscustomobject]@{ Status = $status; Id = $id; SetPath = $setPath; CopiedFiles = $meta.CopiedFiles; CopiedBytes = $copiedBytes; TotalFiles = $entries.Count; Failed = $failed.Count; Unreadable = $listing.Errors.Count; Links = $listing.Links.Count; Chain = $effectiveMode }
    }
    finally {
        if ($tempDir -and [IO.Directory]::Exists($tempDir)) {
            try { Remove-Tree $tempDir } catch { Write-Log -Level WARN -Message "Temporary folder not removed: $tempDir" }
        }
        if ($snapshot) {
            try { Remove-VssSnapshot -Snapshot $snapshot } catch { Write-Log -Level WARN -Message "VSS snapshot not removed: $($_.Exception.Message)" }
        }
        $lock.Dispose()
    }
}

# Checks every file of a version against its SHA-256 hash.
function Test-Backup {
    param([Parameter(Mandatory)][string]$BackupPath)
    $setPath = [IO.Path]::GetDirectoryName($BackupPath)
    $missing = New-Object 'System.Collections.Generic.List[string]'
    $corrupt = New-Object 'System.Collections.Generic.List[string]'
    $checked = 0
    foreach ($entry in Read-Manifest -Path ([IO.Path]::Combine($BackupPath, 'files.tsv'))) {
        $checked++
        if ($checked % 200 -eq 0) { Write-Progress -Activity 'Verification' -Status "$checked files" }
        $stored = [IO.Path]::Combine($setPath, $entry.Store, 'data', $entry.Rel)
        if (-not [IO.File]::Exists((ConvertTo-LongPath $stored))) { $missing.Add($entry.Rel); continue }
        if ((Get-FileSha256 $stored) -ne $entry.Hash) { $corrupt.Add($entry.Rel) }
    }
    Write-Progress -Activity 'Verification' -Completed
    return [pscustomobject]@{ Checked = $checked; Missing = $missing; Corrupt = $corrupt; Ok = ($missing.Count -eq 0 -and $corrupt.Count -eq 0) }
}

function Restore-Backup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$Target,
        [string]$Filter = '*'
    )
    $Target = Resolve-FullPath $Target
    $setPath = [IO.Path]::GetDirectoryName($BackupPath)
    if (Test-PathInside -Child $Target -Parent $setPath) { throw 'The target must not be inside the backup repository.' }

    $selected = @(Read-Manifest -Path ([IO.Path]::Combine($BackupPath, 'files.tsv')) | Where-Object { $_.Rel -like $Filter })
    $needed = ($selected | Measure-Object -Property Size -Sum).Sum
    if ($needed) { Assert-FreeSpace -Path $Target -Needed ([long]$needed) }
    [void][IO.Directory]::CreateDirectory((ConvertTo-LongPath $Target))

    if ($Filter -eq '*') {
        $dirsFile = [IO.Path]::Combine($BackupPath, 'dirs.txt')
        if ([IO.File]::Exists($dirsFile)) {
            foreach ($dir in [IO.File]::ReadLines($dirsFile)) {
                [void][IO.Directory]::CreateDirectory((ConvertTo-LongPath ([IO.Path]::Combine($Target, $dir))))
            }
        }
    }

    foreach ($group in Group-EntriesForCopy -Entries $selected -StoreSelector { param($e) $e.Store }) {
        $fromDir = [IO.Path]::Combine($setPath, $group.Store, 'data', $group.Dir)
        $toDir = [IO.Path]::Combine($Target, $group.Dir)
        [void](Copy-FileGroup -FromDir $fromDir -ToDir $toDir -Names $group.Names.ToArray())
    }

    $failed = New-Object 'System.Collections.Generic.List[string]'
    $done = 0
    foreach ($entry in $selected) {
        $done++
        if ($done % 200 -eq 0) { Write-Progress -Activity 'Restore' -Status 'Checking' -PercentComplete ([int](100 * $done / $selected.Count)) }
        $restored = [IO.Path]::Combine($Target, $entry.Rel)
        try {
            if ((Get-FileSha256 $restored) -ne $entry.Hash) { $failed.Add($entry.Rel) }
        }
        catch { $failed.Add($entry.Rel) }
    }
    Write-Progress -Activity 'Restore' -Completed
    Write-Log -Level $(if ($failed.Count) { 'WARN' } else { 'INFO' }) -Message ('Restore {0} -> {1}: {2} files, {3} failures.' -f $BackupPath, $Target, $selected.Count, $failed.Count)
    return [pscustomobject]@{ Restored = $selected.Count - $failed.Count; Failed = $failed; Ok = ($failed.Count -eq 0) }
}

# Keeps the N most recent chains. A chain (one full backup and its incrementals)
# is deleted as a block: no kept version depends on an older chain.
function Remove-OldBackupChains {
    param([Parameter(Mandatory)][string]$SetPath, [Parameter(Mandatory)][ValidateRange(1, 1000)][int]$KeepChains)
    $catalog = @(Get-BackupCatalog -SetPath $SetPath)
    $fullIndexes = @(for ($i = 0; $i -lt $catalog.Count; $i++) { if ($catalog[$i].Type -eq 'Full') { $i } })
    if ($fullIndexes.Count -le $KeepChains) { return @() }
    $firstKept = $fullIndexes[$fullIndexes.Count - $KeepChains]
    $removed = @()
    for ($i = 0; $i -lt $firstKept; $i++) {
        Remove-Tree $catalog[$i].Path
        $removed += $catalog[$i].Id
    }
    Write-Log -Message "Retention ${SetPath}: $($removed.Count) versions deleted."
    return $removed
}

function Start-SystemImageBackup {
    param([Parameter(Mandatory)][string]$TargetDrive)
    if ($TargetDrive -notmatch '^[A-Za-z]:$') { throw 'Enter a drive in the format E:' }
    if ($TargetDrive -ieq $env:SystemDrive) { throw "The system image cannot be stored on the system drive." }
    & wbadmin.exe start backup "-backupTarget:$TargetDrive" -allCritical -quiet | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "wbadmin failed (code $LASTEXITCODE)." }
    Write-Log -Message "System image created on $TargetDrive."
}

# A trailing \ would escape the closing quote: "D:\" must be written "D:\\".
function ConvertTo-QuotedArgument {
    param([Parameter(Mandatory)][string]$Value)
    if ($Value.EndsWith('\')) { $Value += '\' }
    return "`"$Value`""
}

function Register-BackupSchedule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Time,
        [ValidateSet('Daily', 'Weekly')][string]$Frequency = 'Daily',
        [int]$FullEvery = 7,
        [int]$KeepChains = 4
    )
    if ($Name -notmatch '^[\w -]{1,50}$') { throw 'Invalid task name.' }
    $Source = Resolve-FullPath $Source
    $Destination = Resolve-FullPath $Destination
    Assert-BackupPaths -Source $Source -Destination $Destination
    $at = [datetime]::ParseExact($Time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -Task Backup -Source {1} -Destination {2} -Mode Incremental -FullEvery {3} -KeepChains {4}' -f (ConvertTo-QuotedArgument $script:EntryScript), (ConvertTo-QuotedArgument $Source), (ConvertTo-QuotedArgument $Destination), $FullEvery, $KeepChains
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = if ($Frequency -eq 'Daily') { New-ScheduledTaskTrigger -Daily -At $at } else { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $at }
    # Limited rights of the current account: the script lives in a folder the user can
    # modify, so running it as SYSTEM would allow privilege escalation.
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    [void](Register-ScheduledTask -TaskPath '\WinToolBox\' -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force)
    Write-Log -Message "Scheduled task created: $Name."
}

# --- User interface ---

function Select-BackupSet {
    $root = Read-Text 'Backup destination folder'
    if (-not $root) { return $null }
    $root = Resolve-FullPath $root
    if (-not [IO.Directory]::Exists($root)) { throw "Folder not found: $root" }
    $sets = @([IO.Directory]::GetDirectories($root) | Where-Object { @(Get-BackupCatalog -SetPath $_).Count -gt 0 })
    if ($sets.Count -eq 0) {
        Write-Status WARN 'No backups in this folder.'
        return $null
    }
    return (Select-FromList -Items $sets -Format { param($s) [IO.Path]::GetFileName($s) })
}

function Format-BackupLabel {
    param([Parameter(Mandatory)][object]$Backup)
    # ConvertFrom-Json returns a string on PowerShell 5.1 and a date on PowerShell 7.
    $when = ([datetime]$Backup.CreatedUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    return ('{0}  {1,-11}  {2,-8}  {3} files  {4}' -f $when, $Backup.Type, $Backup.Status, $Backup.FileCount, (Format-Bytes $Backup.TotalBytes))
}

function Select-Backup {
    $set = Select-BackupSet
    if (-not $set) { return $null }
    return (Select-FromList -Items @(Get-BackupCatalog -SetPath $set) -Format { param($b) Format-BackupLabel $b })
}

function Write-BackupResult {
    param([Parameter(Mandatory)][object]$Result)
    switch ($Result.Status) {
        'NoChange' { Write-Status OK 'No changes since the last backup.' }
        'Complete' { Write-Status OK ('Backup completed ({0}): {1} files copied, {2}.' -f $Result.Chain, $Result.CopiedFiles, (Format-Bytes $Result.CopiedBytes)) }
        default { Write-Status WARN ('Partial backup: {0} copied, {1} failures, {2} unreadable folders. See errors.txt in {3}.' -f $Result.CopiedFiles, $Result.Failed, $Result.Unreadable, $Result.Id) }
    }
    if ($Result.Links) { Write-Status INFO "$($Result.Links) links and junctions skipped." }
}

function Invoke-BackupWizard {
    $source = Read-Text 'Folder to back up'
    $destination = Read-Text 'Destination folder'
    if (-not $source -or -not $destination) { return }
    $mode = if ((Read-Text 'Type: [I]ncremental or [F]ull') -ieq 'F') { 'Full' } else { 'Incremental' }
    $useVss = (Test-IsAdmin) -and (Confirm-Action 'Include open files using VSS?')
    Write-BackupResult -Result (New-Backup -Source $source -Destination $destination -Mode $mode -UseVss:$useVss)
}

function Invoke-RestoreWizard {
    $backup = Select-Backup
    if (-not $backup) { return }
    $target = Read-Text 'Restore folder'
    if (-not $target) { return }
    $filter = Read-Text 'Filter, for example Photos\* (leave blank to restore everything)'
    if (-not $filter) { $filter = '*' }
    if (-not (Confirm-Action "Files with the same name in $target will be overwritten. Continue?")) { return }
    $result = Restore-Backup -BackupPath $backup.Path -Target $target -Filter $filter
    if ($result.Ok) { Write-Status OK "$($result.Restored) files restored and verified." }
    else {
        Write-Status FAIL "$($result.Failed.Count) files not restored:"
        $result.Failed | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    }
}

function Invoke-VerifyWizard {
    $backup = Select-Backup
    if (-not $backup) { return }
    $result = Test-Backup -BackupPath $backup.Path
    if ($result.Ok) { Write-Status OK "$($result.Checked) files verified, no problems found." }
    else {
        Write-Status FAIL ('{0} files missing and {1} corrupt out of {2}.' -f $result.Missing.Count, $result.Corrupt.Count, $result.Checked)
        @($result.Missing) + @($result.Corrupt) | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    }
}

function Show-BackupList {
    $set = Select-BackupSet
    if (-not $set) { return }
    foreach ($backup in Get-BackupCatalog -SetPath $set) { Write-Host ('   ' + (Format-BackupLabel $backup)) }
}

function Invoke-RetentionWizard {
    $set = Select-BackupSet
    if (-not $set) { return }
    $keep = 0
    if (-not [int]::TryParse((Read-Text 'Number of full chains to keep'), [ref]$keep) -or $keep -lt 1) {
        Write-Status WARN 'Invalid number.'
        return
    }
    if (-not (Confirm-Phrase -Message 'Older versions will be permanently deleted.' -Phrase 'DELETE')) { return }
    $removed = @(Remove-OldBackupChains -SetPath $set -KeepChains $keep)
    Write-Status OK "$($removed.Count) versions deleted."
}

function Invoke-ScheduleWizard {
    $tasks = @(Get-ScheduledTask -TaskPath '\WinToolBox\' -ErrorAction SilentlyContinue)
    if ($tasks.Count) { $tasks | Select-Object TaskName, State | Format-Table -AutoSize | Out-Host }
    else { Write-Status INFO 'No scheduled tasks.' }
    switch ((Read-Text '[A]dd, [D]elete (leave blank to go back)').ToUpperInvariant()) {
        'A' {
            $name = Read-Text 'Task name'
            $source = Read-Text 'Folder to back up'
            $destination = Read-Text 'Local or external drive destination'
            $time = Read-Text 'Time (HH:mm)'
            $frequency = if ((Read-Text '[D]aily or [W]eekly') -ieq 'W') { 'Weekly' } else { 'Daily' }
            Write-Status INFO 'Windows will ask you to confirm the account if necessary.'
            Register-BackupSchedule -Name $name -Source $source -Destination $destination -Time $time -Frequency $frequency
            Write-Status OK "Task '$name' created: one full backup every 7 runs, 4 chains kept."
        }
        'D' {
            $task = Select-FromList -Items $tasks -Format { param($t) $t.TaskName }
            if ($task -and (Confirm-Action "Delete task $($task.TaskName)?")) {
                Unregister-ScheduledTask -InputObject $task -Confirm:$false
                Write-Status OK 'Task deleted. Existing backups are kept.'
            }
        }
    }
}

function Invoke-SystemImageWizard {
    Write-Status INFO "The image is restored from the Windows Recovery Environment."
    $target = (Read-Text 'Target drive, for example E:').ToUpperInvariant()
    if ($target -and (Confirm-Action "Create a system image on ${target}?")) { Start-SystemImageBackup -TargetDrive $target }
}

function Invoke-RestorePoint {
    Checkpoint-Computer -Description "WinToolBox $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType MODIFY_SETTINGS
    Write-Status OK 'Restore point requested (Windows limits this to one every 24 hours).'
}

function Show-BackupMenu {
    Show-Menu -Title 'Backup and restore' -Items @(
        @{ Section = 'FILES'; Key = '1'; Label = 'New backup'; Action = { Invoke-BackupWizard } }
        @{ Section = 'FILES'; Key = '2'; Label = 'Restore a version'; Action = { Invoke-RestoreWizard } }
        @{ Section = 'FILES'; Key = '3'; Label = 'Verify a version'; Action = { Invoke-VerifyWizard } }
        @{ Section = 'FILES'; Key = '4'; Label = 'List versions'; Action = { Show-BackupList } }
        @{ Section = 'FILES'; Key = '5'; Label = 'Delete old versions'; Action = { Invoke-RetentionWizard } }
        @{ Section = 'AUTOMATION'; Key = '6'; Label = 'Scheduled tasks'; Admin = $true; Action = { Invoke-ScheduleWizard } }
        @{ Section = 'SYSTEM'; Key = '7'; Label = 'Full system image'; Admin = $true; Action = { Invoke-SystemImageWizard } }
        @{ Section = 'SYSTEM'; Key = '8'; Label = 'Restore point'; Admin = $true; Action = { Invoke-RestorePoint } }
    )
}

# Disks and partitions, through the Windows Storage module.

# Formatting or deleting these partitions would make Windows unusable.
function Test-PartitionProtected {
    param([Parameter(Mandatory)][object]$Partition, [string]$SystemDrive = $env:SystemDrive)
    if ($Partition.IsBoot -or $Partition.IsSystem -or $Partition.IsHidden) { return $true }
    # 39 is the MBR type of a recovery partition. These can have a letter assigned by hand.
    if ("$($Partition.Type)" -in 'System', 'Reserved', 'Recovery' -or $Partition.MbrType -eq 39) { return $true }
    $letter = "$($Partition.DriveLetter)".Trim([char]0, ' ')
    return ($letter -and $SystemDrive -and $SystemDrive.StartsWith($letter, [StringComparison]::OrdinalIgnoreCase))
}

# Another Windows installation (dual boot) is neither IsBoot nor IsSystem for the running one.
function Test-PathHoldsWindows {
    param([Parameter(Mandatory)][string]$Root)
    return [IO.File]::Exists([IO.Path]::Combine($Root, 'Windows', 'System32', 'ntoskrnl.exe'))
}

function Test-DriveHostsTool {
    param([Parameter(Mandatory)][string]$Letter, [string]$AppRoot = $script:AppRoot)
    return ($AppRoot -and $AppRoot -like "${Letter}:*")
}

function Get-ChildDirectories {
    param([Parameter(Mandatory)][string]$Path)
    try { return [IO.Directory]::GetDirectories($Path) }
    catch { return @() }
}

# Looks for backup versions at <root>\<set>\<id> and <root>\<folder>\<set>\<id>. The search depth
# is bounded to stay fast, so a repository nested deeper is not detected: this only adds a warning.
function Test-PathHoldsBackups {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($base in @($Root) + @(Get-ChildDirectories $Root)) {
        foreach ($set in Get-ChildDirectories $base) {
            foreach ($version in Get-ChildDirectories $set) {
                if ([IO.Path]::GetFileName($version) -match '^\d{8}-\d{9}-(full|incr)$' -and [IO.File]::Exists([IO.Path]::Combine($version, 'meta.json'))) { return $true }
            }
        }
    }
    return $false
}

function ConvertTo-DriveLetter {
    param([string]$Text)
    if ("$Text".Trim() -match '^([A-Za-z]):?\\?$') { return $Matches[1].ToUpperInvariant() }
    return $null
}

function Read-DriveLetter {
    param([string]$Prompt = 'Drive letter')
    $letter = ConvertTo-DriveLetter (Read-Text $Prompt)
    if (-not $letter) { Write-Status WARN 'Invalid drive letter.' }
    return $letter
}

function Read-PartitionSafe {
    $letter = Read-DriveLetter
    if (-not $letter) { return $null }
    $partition = Get-Partition -DriveLetter $letter
    if (Test-PartitionProtected -Partition $partition) {
        Write-Status FAIL "${letter}: is a system, boot, recovery or hidden partition, the operation is refused."
        return $null
    }
    if (Test-PathHoldsWindows -Root "${letter}:\") {
        Write-Status FAIL "${letter}: contains a Windows installation, the operation is refused."
        return $null
    }
    if (Test-DriveHostsTool -Letter $letter) {
        Write-Status FAIL "${letter}: contains WinToolBox itself, the operation is refused."
        return $null
    }
    return $partition
}

# Shows what is about to be destroyed: a letter alone is easy to get wrong.
function Write-PartitionSummary {
    param([Parameter(Mandatory)][object]$Partition)
    $letter = $Partition.DriveLetter
    try {
        $volume = Get-Volume -DriveLetter $letter
        $disk = Get-Disk -Number $Partition.DiskNumber
        Write-Status INFO ('{0}: "{1}", {2}, {3} used of {4}, on disk {5} ({6}).' -f $letter, $volume.FileSystemLabel, $volume.FileSystem, (Format-Bytes ($volume.Size - $volume.SizeRemaining)), (Format-Bytes $volume.Size), $disk.Number, $disk.FriendlyName)
    }
    catch { Write-Status WARN 'Could not read the details of this volume.' }
    if (Test-PathHoldsBackups -Root "${letter}:\") { Write-Status WARN 'This volume contains WinToolBox backups, and they would be lost.' }
}

function Show-DiskOverview {
    Write-Section 'Disks'
    Write-Table -Rows @(Get-Disk | Sort-Object Number | Select-Object @{ n = 'Disk'; e = { $_.Number } }, @{ n = 'Name'; e = { $_.FriendlyName } },
        @{ n = 'Style'; e = { $_.PartitionStyle } }, @{ n = 'Status'; e = { $_.OperationalStatus } },
        @{ n = 'Size'; e = { Format-Bytes $_.Size } },
        @{ n = 'Unallocated'; e = { Format-Bytes $_.LargestFreeExtent } })

    Write-Section 'Partitions'
    Write-Table -Rows @(Get-Partition | Sort-Object DiskNumber, PartitionNumber | Select-Object @{ n = 'Disk'; e = { $_.DiskNumber } },
        @{ n = 'Part.'; e = { $_.PartitionNumber } }, @{ n = 'Letter'; e = { $_.DriveLetter } }, Type,
        @{ n = 'Boot'; e = { $_.IsBoot } }, @{ n = 'System'; e = { $_.IsSystem } },
        @{ n = 'Size'; e = { Format-Bytes $_.Size } })

    Write-Section 'Volumes'
    Write-Table -Rows @(Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | Select-Object @{ n = 'Letter'; e = { $_.DriveLetter } },
        @{ n = 'Label'; e = { $_.FileSystemLabel } }, @{ n = 'Format'; e = { $_.FileSystem } }, @{ n = 'Health'; e = { $_.HealthStatus } },
        @{ n = 'Free'; e = { Format-Bytes $_.SizeRemaining } },
        @{ n = 'Size'; e = { Format-Bytes $_.Size } })
}

function Show-DiskHealth {
    Write-Table -Rows @(Get-PhysicalDisk | ForEach-Object {
        $counters = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Disk        = $_.FriendlyName
            Type        = $_.MediaType
            Size        = Format-Bytes $_.Size
            Health      = $_.HealthStatus
            State       = $_.OperationalStatus
            Temperature = $counters.Temperature
            Wear        = $counters.Wear
            ReadErrors  = $counters.ReadErrorsTotal
            PowerOnHrs  = $counters.PowerOnHours
        }
    })
    Write-Host ''
    Write-Status INFO 'An empty column means the disk does not report this measurement.'
}

function Invoke-VolumeScan {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    try { $result = Invoke-WithLoader "Scanning ${letter}:" { Repair-Volume -DriveLetter $letter -Scan -ErrorAction Stop } }
    catch {
        Write-Log -Level ERROR -Message "Volume scan ${letter}: $($_.Exception.Message)"
        Write-Status FAIL "Scan of ${letter}: failed: $($_.Exception.Message)"
        Write-Status INFO 'An online scan needs a snapshot. "Repair offline" and "Repair with chkdsk" do not.'
        return
    }
    Write-Log -Message "Volume scan ${letter}: $result."
    if ("$result" -eq 'NoErrorsFound') { Write-Status OK "No errors on ${letter}:." }
    else { Write-Status WARN "Result on ${letter}: $result. Use `"Repair offline`" or `"Repair with chkdsk`"." }
}

# Going offline invalidates every open file, so the targets refused are the same as for a format.
function Invoke-VolumeOfflineRepair {
    Write-Status INFO 'The Windows drive cannot go offline: use "Repair with chkdsk" for it.'
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    Write-PartitionSummary -Partition $partition
    Write-Status WARN "${letter}: goes offline during the repair: programs using it lose access and unsaved work may be lost."
    if (-not (Confirm-Action "Repair ${letter}: offline?")) { return }
    $result = Invoke-WithLoader "Repairing ${letter}:" { Repair-Volume -DriveLetter $letter -OfflineScanAndFix -ErrorAction Stop }
    Write-Log -Message "Offline repair ${letter}: $result."
    if ("$result" -eq 'NoErrorsFound') { Write-Status OK "No errors on ${letter}:." }
    else { Write-Status INFO "Result on ${letter}: $result." }
}

# Start-Process keeps chkdsk attached to the console: its Y/N questions would stay invisible in a pipeline.
# They are left to the user because "Y" can mean either a check at restart or a forced dismount.
function Invoke-VolumeChkdsk {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    Write-Status INFO 'If the volume is in use, chkdsk asks whether to check it at the next restart.'
    Write-Status WARN 'If it offers to force a dismount, accepting closes the files open on that volume.'
    Write-Status INFO 'chkdsk has no language option: its messages and questions use the Windows language.'
    if (-not (Confirm-Action "Run chkdsk ${letter}: /f?")) { return }
    $process = Start-Process -FilePath 'chkdsk.exe' -ArgumentList "${letter}:", '/f' -NoNewWindow -Wait -PassThru
    $code = $process.ExitCode
    Write-Log -Message "chkdsk ${letter}: /f: code $code."
    if ($code -in 0, 1) { Write-Status OK "chkdsk finished on ${letter}: (code $code)." }
    else { Write-Status WARN "chkdsk returned code ${code}: see its message above. A check accepted for the next restart only runs after restarting." }
}

function Invoke-VolumeOptimize {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    Write-Status INFO 'Windows chooses TRIM for an SSD and defragmentation for a hard drive.'
    Invoke-WithLoader "Optimizing ${letter}:" { Optimize-Volume -DriveLetter $letter }
    Write-Log -Message "Volume optimization $letter."
    Write-Status OK 'Optimization completed.'
}

function Invoke-PartitionResize {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    $partition = Get-Partition -DriveLetter $letter
    $limits = Get-PartitionSupportedSize -DriveLetter $letter
    Write-Status INFO ('Current size {0}, minimum {1}, maximum {2}.' -f (Format-Bytes $partition.Size), (Format-Bytes $limits.SizeMin), (Format-Bytes $limits.SizeMax))
    $size = ConvertTo-BytesFromGb (Read-Text 'New size in GB')
    if ($null -eq $size) {
        Write-Status WARN 'Invalid size.'
        return
    }
    if ($size -lt $limits.SizeMin -or $size -gt $limits.SizeMax) {
        Write-Status FAIL 'This size is outside the limits shown.'
        return
    }
    if (-not (Confirm-Action ('Resize {0}: to {1}? Make a backup first.' -f $letter, (Format-Bytes $size)))) { return }
    Invoke-WithLoader "Resizing ${letter}:" { Resize-Partition -DriveLetter $letter -Size $size }
    Write-Log -Message "Partition $letter resized to $size bytes."
    Write-Status OK 'Partition resized.'
}

function Invoke-PartitionCreate {
    $disks = @(Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and -not $_.IsReadOnly -and ($_.LargestFreeExtent -gt 0 -or $_.PartitionStyle -eq 'RAW') })
    $disk = Select-FromList -Items $disks -Format {
        param($d)
        if ($d.PartitionStyle -eq 'RAW') { '{0}: {1}, {2}, no partition table' -f $d.Number, $d.FriendlyName, (Format-Bytes $d.Size) }
        else { '{0}: {1}, {2} unallocated' -f $d.Number, $d.FriendlyName, (Format-Bytes $d.LargestFreeExtent) }
    }
    if (-not $disk) {
        Write-Status INFO 'No disk selected.'
        return
    }
    $sizeText = Read-Text 'Size in GB (leave blank to use all free space)'
    $parameters = @{ DiskNumber = $disk.Number; AssignDriveLetter = $true }
    if ($sizeText) {
        $size = ConvertTo-BytesFromGb $sizeText
        if ($null -eq $size) {
            Write-Status WARN 'Invalid size.'
            return
        }
        $parameters.Size = $size
    }
    else { $parameters.UseMaximumSize = $true }
    $fileSystem = if ((Read-Text 'File system: [N]TFS or [E]xFAT') -ieq 'E') { 'exFAT' } else { 'NTFS' }
    $label = Read-Text 'Volume name'
    # RAW can also mean a damaged partition table on a disk whose data is still recoverable.
    if ($disk.PartitionStyle -eq 'RAW') {
        $warning = 'Disk {0} ({1}, {2}) has no partition table. It may be new, or its table may be damaged with data still recoverable: initializing and formatting it would make recovery much harder.' -f $disk.Number, $disk.FriendlyName, (Format-Bytes $disk.Size)
        if (-not (Confirm-Phrase -Message $warning -Phrase "INITIALIZE $($disk.Number)")) {
            Write-Status INFO 'Creation cancelled.'
            return
        }
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    }
    elseif (-not (Confirm-Action "Create and format a $fileSystem partition on disk $($disk.Number)?")) { return }
    $partition = New-Partition @parameters
    [void](Invoke-WithLoader "Formatting $($partition.DriveLetter):" { $partition | Format-Volume -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false })
    Write-Log -Message "Partition created on disk $($disk.Number) ($fileSystem)."
    Write-Status OK "Partition created on $($partition.DriveLetter):."
}

function Invoke-VolumeFormat {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    $fileSystem = if ((Read-Text 'File system: [N]TFS or [E]xFAT') -ieq 'E') { 'exFAT' } else { 'NTFS' }
    $label = Read-Text 'Volume name'
    Write-PartitionSummary -Partition $partition
    if (-not (Confirm-Phrase -Message "All data on ${letter}: will be erased." -Phrase "FORMAT $letter")) {
        Write-Status INFO 'Format cancelled.'
        return
    }
    [void](Invoke-WithLoader "Formatting ${letter}:" { Format-Volume -DriveLetter $letter -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false })
    Write-Log -Level WARN -Message "Volume $letter formatted as $fileSystem."
    Write-Status OK "${letter}: formatted as $fileSystem."
}

function Invoke-PartitionDelete {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    Write-PartitionSummary -Partition $partition
    if (-not (Confirm-Phrase -Message "Partition ${letter}: and its data will be deleted." -Phrase "DELETE $letter")) {
        Write-Status INFO 'Deletion cancelled.'
        return
    }
    Remove-Partition -DriveLetter $letter -Confirm:$false
    Write-Log -Level WARN -Message "Partition $letter deleted."
    Write-Status OK "Partition $letter deleted."
}

function Invoke-DriveLetterChange {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $new = Read-DriveLetter -Prompt 'New letter'
    if (-not $new) { return }
    if (Test-Path -LiteralPath "${new}:\") {
        Write-Status FAIL "Letter $new is already in use."
        return
    }
    if (-not (Confirm-Action "Replace $($partition.DriveLetter): with ${new}:?")) { return }
    Set-Partition -DriveLetter $partition.DriveLetter -NewDriveLetter $new
    Write-Log -Message "Letter $($partition.DriveLetter) replaced with $new."
    Write-Status OK "New letter: $new."
}

function Show-DiskMenu {
    Show-Menu -Title 'Disks and partitions' -Items @(
        @{ Section = 'STATUS'; Key = '1'; Label = 'Overview'; Hint = 'disks, partitions, volumes'; Admin = $true; Action = { Show-DiskOverview } }
        @{ Section = 'STATUS'; Key = '2'; Label = 'Disk health'; Hint = 'temperature, wear, errors'; Admin = $true; Action = { Show-DiskHealth } }
        @{ Section = 'MAINTENANCE'; Key = '3'; Label = 'Scan a volume'; Hint = 'read-only'; Admin = $true; Action = { Invoke-VolumeScan } }
        @{ Section = 'MAINTENANCE'; Key = '4'; Label = 'Optimize a volume'; Hint = 'TRIM or defragmentation'; Admin = $true; Action = { Invoke-VolumeOptimize } }
        @{ Section = 'MAINTENANCE'; Key = '5'; Label = 'Repair offline'; Hint = 'data volumes, takes the volume offline'; Admin = $true; Action = { Invoke-VolumeOfflineRepair } }
        @{ Section = 'MAINTENANCE'; Key = '6'; Label = 'Repair with chkdsk'; Hint = 'next restart if the volume is in use'; Admin = $true; Action = { Invoke-VolumeChkdsk } }
        @{ Section = 'PARTITIONS'; Key = '7'; Label = 'Create a partition'; Admin = $true; Action = { Invoke-PartitionCreate } }
        @{ Section = 'PARTITIONS'; Key = '8'; Label = 'Resize a partition'; Admin = $true; Action = { Invoke-PartitionResize } }
        @{ Section = 'PARTITIONS'; Key = '9'; Label = 'Change a drive letter'; Admin = $true; Action = { Invoke-DriveLetterChange } }
        @{ Section = 'IRREVERSIBLE OPERATIONS'; Key = '10'; Label = 'Format a volume'; Danger = $true; Admin = $true; Action = { Invoke-VolumeFormat } }
        @{ Section = 'IRREVERSIBLE OPERATIONS'; Key = '11'; Label = 'Delete a partition'; Danger = $true; Admin = $true; Action = { Invoke-PartitionDelete } }
    )
}

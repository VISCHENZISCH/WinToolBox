# Disks and partitions, through the Windows Storage module.

# Formatting or deleting these partitions would make Windows unusable.
function Test-PartitionProtected {
    param([Parameter(Mandatory)][object]$Partition, [string]$SystemDrive = $env:SystemDrive)
    if ($Partition.IsBoot -or $Partition.IsSystem) { return $true }
    $letter = "$($Partition.DriveLetter)".Trim([char]0, ' ')
    return ($letter -and $SystemDrive -and $SystemDrive.StartsWith($letter, [StringComparison]::OrdinalIgnoreCase))
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
        Write-Status FAIL "${letter}: is a system or boot partition, the operation is refused."
        return $null
    }
    return $partition
}

function Show-DiskOverview {
    Get-Disk | Sort-Object Number | Select-Object Number, FriendlyName, PartitionStyle, OperationalStatus,
    @{ n = 'Size'; e = { Format-Bytes $_.Size } },
    @{ n = 'Unallocated'; e = { Format-Bytes $_.LargestFreeExtent } } | Format-Table -AutoSize | Out-Host

    Get-Partition | Sort-Object DiskNumber, PartitionNumber | Select-Object @{ n = 'Disk'; e = { $_.DiskNumber } },
    @{ n = 'Part.'; e = { $_.PartitionNumber } }, DriveLetter, Type, IsBoot, IsSystem,
    @{ n = 'Size'; e = { Format-Bytes $_.Size } } | Format-Table -AutoSize | Out-Host

    Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
    @{ n = 'Free'; e = { Format-Bytes $_.SizeRemaining } },
    @{ n = 'Size'; e = { Format-Bytes $_.Size } } | Format-Table -AutoSize | Out-Host
}

function Show-DiskHealth {
    Get-PhysicalDisk | ForEach-Object {
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
    } | Format-Table -AutoSize | Out-Host
    Write-Status INFO 'An empty column means the disk does not report this measurement.'
}

function Invoke-VolumeScan {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    $result = Repair-Volume -DriveLetter $letter -Scan
    Write-Log -Message "Volume scan ${letter}: $result."
    if ("$result" -eq 'NoErrorsFound') { Write-Status OK "No errors on ${letter}:." }
    else { Write-Status WARN "Result on ${letter}: $result. Run the repair with chkdsk $letter`: /f." }
}

function Invoke-VolumeOptimize {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    Write-Status INFO 'Windows chooses TRIM for an SSD and defragmentation for a hard drive.'
    Optimize-Volume -DriveLetter $letter -Verbose
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
    Resize-Partition -DriveLetter $letter -Size $size
    Write-Log -Message "Partition $letter resized to $size bytes."
    Write-Status OK 'Partition resized.'
}

function Invoke-PartitionCreate {
    $disks = @(Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and -not $_.IsReadOnly -and ($_.LargestFreeExtent -gt 0 -or $_.PartitionStyle -eq 'RAW') })
    $disk = Select-FromList -Items $disks -Format { param($d) '{0}: {1}, {2} unallocated' -f $d.Number, $d.FriendlyName, (Format-Bytes $d.LargestFreeExtent) }
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
    if (-not (Confirm-Action "Create a $fileSystem partition on disk $($disk.Number)?")) { return }
    if ($disk.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $disk.Number -PartitionStyle GPT }
    $partition = New-Partition @parameters
    [void]($partition | Format-Volume -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false)
    Write-Log -Message "Partition created on disk $($disk.Number) ($fileSystem)."
    Write-Status OK "Partition created on $($partition.DriveLetter):."
}

function Invoke-VolumeFormat {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    $fileSystem = if ((Read-Text 'File system: [N]TFS or [E]xFAT') -ieq 'E') { 'exFAT' } else { 'NTFS' }
    $label = Read-Text 'Volume name'
    if (-not (Confirm-Phrase -Message "All data on ${letter}: will be erased." -Phrase "FORMAT $letter")) {
        Write-Status INFO 'Format cancelled.'
        return
    }
    [void](Format-Volume -DriveLetter $letter -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false)
    Write-Log -Level WARN -Message "Volume $letter formatted as $fileSystem."
    Write-Status OK "${letter}: formatted as $fileSystem."
}

function Invoke-PartitionDelete {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
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
        @{ Section = 'STATUS'; Key = '1'; Label = 'Overview'; Admin = $true; Action = { Show-DiskOverview } }
        @{ Section = 'STATUS'; Key = '2'; Label = 'Disk health'; Admin = $true; Action = { Show-DiskHealth } }
        @{ Section = 'MAINTENANCE'; Key = '3'; Label = 'Scan a volume'; Admin = $true; Action = { Invoke-VolumeScan } }
        @{ Section = 'MAINTENANCE'; Key = '4'; Label = 'Optimize a volume'; Admin = $true; Action = { Invoke-VolumeOptimize } }
        @{ Section = 'PARTITIONS'; Key = '5'; Label = 'Create a partition'; Admin = $true; Action = { Invoke-PartitionCreate } }
        @{ Section = 'PARTITIONS'; Key = '6'; Label = 'Resize a partition'; Admin = $true; Action = { Invoke-PartitionResize } }
        @{ Section = 'PARTITIONS'; Key = '7'; Label = 'Change a drive letter'; Admin = $true; Action = { Invoke-DriveLetterChange } }
        @{ Section = 'IRREVERSIBLE OPERATIONS'; Key = '8'; Label = 'Format a volume'; Admin = $true; Action = { Invoke-VolumeFormat } }
        @{ Section = 'IRREVERSIBLE OPERATIONS'; Key = '9'; Label = 'Delete a partition'; Admin = $true; Action = { Invoke-PartitionDelete } }
    )
}

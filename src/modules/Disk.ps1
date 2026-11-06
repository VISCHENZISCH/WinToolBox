# Disques et partitions, via le module Storage de Windows.

# Formater ou supprimer ces partitions rendrait Windows inutilisable.
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
    param([string]$Prompt = 'Lettre du lecteur')
    $letter = ConvertTo-DriveLetter (Read-Text $Prompt)
    if (-not $letter) { Write-Status WARN 'Lettre de lecteur invalide.' }
    return $letter
}

function Read-PartitionSafe {
    $letter = Read-DriveLetter
    if (-not $letter) { return $null }
    $partition = Get-Partition -DriveLetter $letter
    if (Test-PartitionProtected -Partition $partition) {
        Write-Status FAIL "$letter : est une partition systeme ou de demarrage, l'operation est refusee."
        return $null
    }
    return $partition
}

function Show-DiskOverview {
    Get-Disk | Sort-Object Number | Select-Object Number, FriendlyName, PartitionStyle, OperationalStatus,
    @{ n = 'Taille'; e = { Format-Bytes $_.Size } },
    @{ n = 'Non alloue'; e = { Format-Bytes $_.LargestFreeExtent } } | Format-Table -AutoSize | Out-Host

    Get-Partition | Sort-Object DiskNumber, PartitionNumber | Select-Object @{ n = 'Disque'; e = { $_.DiskNumber } },
    @{ n = 'Part.'; e = { $_.PartitionNumber } }, DriveLetter, Type, IsBoot, IsSystem,
    @{ n = 'Taille'; e = { Format-Bytes $_.Size } } | Format-Table -AutoSize | Out-Host

    Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
    @{ n = 'Libre'; e = { Format-Bytes $_.SizeRemaining } },
    @{ n = 'Taille'; e = { Format-Bytes $_.Size } } | Format-Table -AutoSize | Out-Host
}

function Show-DiskHealth {
    Get-PhysicalDisk | ForEach-Object {
        $counters = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Disque      = $_.FriendlyName
            Type        = $_.MediaType
            Taille      = Format-Bytes $_.Size
            Sante       = $_.HealthStatus
            Etat        = $_.OperationalStatus
            Temperature = $counters.Temperature
            Usure       = $counters.Wear
            ErreursLect = $counters.ReadErrorsTotal
            Heures      = $counters.PowerOnHours
        }
    } | Format-Table -AutoSize | Out-Host
    Write-Status INFO 'Une colonne vide signifie que le disque ne remonte pas cette mesure.'
}

function Invoke-VolumeScan {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    $result = Repair-Volume -DriveLetter $letter -Scan
    Write-Log -Message "Analyse du volume $letter : $result."
    if ("$result" -eq 'NoErrorsFound') { Write-Status OK "Aucune erreur sur $letter :." }
    else { Write-Status WARN "Resultat sur $letter : : $result. Lancez la reparation avec chkdsk $letter`: /f." }
}

function Invoke-VolumeOptimize {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    Write-Status INFO 'Windows choisit TRIM pour un SSD et la defragmentation pour un disque dur.'
    Optimize-Volume -DriveLetter $letter -Verbose
    Write-Log -Message "Optimisation du volume $letter."
    Write-Status OK 'Optimisation terminee.'
}

function Invoke-PartitionResize {
    $letter = Read-DriveLetter
    if (-not $letter) { return }
    $partition = Get-Partition -DriveLetter $letter
    $limits = Get-PartitionSupportedSize -DriveLetter $letter
    Write-Status INFO ('Taille actuelle {0}, minimum {1}, maximum {2}.' -f (Format-Bytes $partition.Size), (Format-Bytes $limits.SizeMin), (Format-Bytes $limits.SizeMax))
    $size = ConvertTo-BytesFromGb (Read-Text 'Nouvelle taille en Go')
    if ($null -eq $size) {
        Write-Status WARN 'Taille invalide.'
        return
    }
    if ($size -lt $limits.SizeMin -or $size -gt $limits.SizeMax) {
        Write-Status FAIL 'Cette taille sort des limites indiquees.'
        return
    }
    if (-not (Confirm-Action ('Redimensionner {0}: a {1} ? Faites une sauvegarde avant.' -f $letter, (Format-Bytes $size)))) { return }
    Resize-Partition -DriveLetter $letter -Size $size
    Write-Log -Message "Partition $letter redimensionnee a $size octets."
    Write-Status OK 'Partition redimensionnee.'
}

function Invoke-PartitionCreate {
    $disks = @(Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and -not $_.IsReadOnly -and ($_.LargestFreeExtent -gt 0 -or $_.PartitionStyle -eq 'RAW') })
    $disk = Select-FromList -Items $disks -Format { param($d) '{0} : {1}, {2} non alloues' -f $d.Number, $d.FriendlyName, (Format-Bytes $d.LargestFreeExtent) }
    if (-not $disk) {
        Write-Status INFO 'Aucun disque selectionne.'
        return
    }
    $sizeText = Read-Text 'Taille en Go (vide pour tout l''espace libre)'
    $parameters = @{ DiskNumber = $disk.Number; AssignDriveLetter = $true }
    if ($sizeText) {
        $size = ConvertTo-BytesFromGb $sizeText
        if ($null -eq $size) {
            Write-Status WARN 'Taille invalide.'
            return
        }
        $parameters.Size = $size
    }
    else { $parameters.UseMaximumSize = $true }
    $fileSystem = if ((Read-Text 'Systeme de fichiers : [N]TFS ou [E]xFAT') -ieq 'E') { 'exFAT' } else { 'NTFS' }
    $label = Read-Text 'Nom du volume'
    if (-not (Confirm-Action "Creer une partition $fileSystem sur le disque $($disk.Number) ?")) { return }
    if ($disk.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $disk.Number -PartitionStyle GPT }
    $partition = New-Partition @parameters
    [void]($partition | Format-Volume -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false)
    Write-Log -Message "Partition creee sur le disque $($disk.Number) ($fileSystem)."
    Write-Status OK "Partition creee sur $($partition.DriveLetter) :."
}

function Invoke-VolumeFormat {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    $fileSystem = if ((Read-Text 'Systeme de fichiers : [N]TFS ou [E]xFAT') -ieq 'E') { 'exFAT' } else { 'NTFS' }
    $label = Read-Text 'Nom du volume'
    if (-not (Confirm-Phrase -Message "Toutes les donnees de $letter : seront effacees." -Phrase "FORMATER $letter")) {
        Write-Status INFO 'Formatage annule.'
        return
    }
    [void](Format-Volume -DriveLetter $letter -FileSystem $fileSystem -NewFileSystemLabel $label -Confirm:$false)
    Write-Log -Level WARN -Message "Volume $letter formate en $fileSystem."
    Write-Status OK "$letter : formate en $fileSystem."
}

function Invoke-PartitionDelete {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $letter = $partition.DriveLetter
    if (-not (Confirm-Phrase -Message "La partition $letter : et ses donnees seront supprimees." -Phrase "SUPPRIMER $letter")) {
        Write-Status INFO 'Suppression annulee.'
        return
    }
    Remove-Partition -DriveLetter $letter -Confirm:$false
    Write-Log -Level WARN -Message "Partition $letter supprimee."
    Write-Status OK "Partition $letter supprimee."
}

function Invoke-DriveLetterChange {
    $partition = Read-PartitionSafe
    if (-not $partition) { return }
    $new = Read-DriveLetter -Prompt 'Nouvelle lettre'
    if (-not $new) { return }
    if (Test-Path -LiteralPath "${new}:\") {
        Write-Status FAIL "La lettre $new est deja utilisee."
        return
    }
    if (-not (Confirm-Action "Remplacer $($partition.DriveLetter): par ${new}: ?")) { return }
    Set-Partition -DriveLetter $partition.DriveLetter -NewDriveLetter $new
    Write-Log -Message "Lettre $($partition.DriveLetter) remplacee par $new."
    Write-Status OK "Nouvelle lettre : $new."
}

function Show-DiskMenu {
    Show-Menu -Title 'Disques et partitions' -Items @(
        @{ Section = 'ETAT'; Key = '1'; Label = 'Vue d''ensemble'; Admin = $true; Action = { Show-DiskOverview } }
        @{ Section = 'ETAT'; Key = '2'; Label = 'Sante des disques'; Admin = $true; Action = { Show-DiskHealth } }
        @{ Section = 'ENTRETIEN'; Key = '3'; Label = 'Analyser un volume'; Admin = $true; Action = { Invoke-VolumeScan } }
        @{ Section = 'ENTRETIEN'; Key = '4'; Label = 'Optimiser un volume'; Admin = $true; Action = { Invoke-VolumeOptimize } }
        @{ Section = 'PARTITIONS'; Key = '5'; Label = 'Creer une partition'; Admin = $true; Action = { Invoke-PartitionCreate } }
        @{ Section = 'PARTITIONS'; Key = '6'; Label = 'Redimensionner une partition'; Admin = $true; Action = { Invoke-PartitionResize } }
        @{ Section = 'PARTITIONS'; Key = '7'; Label = 'Changer une lettre de lecteur'; Admin = $true; Action = { Invoke-DriveLetterChange } }
        @{ Section = 'OPERATIONS IRREVERSIBLES'; Key = '8'; Label = 'Formater un volume'; Admin = $true; Action = { Invoke-VolumeFormat } }
        @{ Section = 'OPERATIONS IRREVERSIBLES'; Key = '9'; Label = 'Supprimer une partition'; Admin = $true; Action = { Invoke-PartitionDelete } }
    )
}

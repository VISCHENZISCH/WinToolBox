# Sauvegarde de fichiers versionnee.
#
# Depot : <destination>\<jeu>\<id>\ avec data\ (fichiers copies), files.tsv (etat complet de la
# source), dirs.txt, errors.txt et meta.json. Une sauvegarde est construite dans .tmp-<id> puis
# renommee : un dossier <id> present est donc toujours complet. files.tsv indique pour chaque
# fichier la sauvegarde qui le stocke, ce qui rend chaque version restaurable directement.

function Get-BackupSetName {
    param([Parameter(Mandatory)][string]$Source)
    $clean = $Source.TrimEnd('\', '/')
    $leaf = [IO.Path]::GetFileName($clean)
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

# Format TSV : la tabulation est interdite dans les noms de fichiers NTFS.
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
    if (-not [IO.Directory]::Exists($Source)) { throw "Source introuvable : $Source" }
    if ((Test-PathInside -Child $Destination -Parent $Source) -or (Test-PathInside -Child $Source -Parent $Destination)) {
        throw 'La source et la destination ne doivent pas etre imbriquees.'
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
        throw ('Espace insuffisant sur {0} : {1} requis, {2} libres.' -f $Path, (Format-Bytes $Needed), (Format-Bytes $free))
    }
}

function Remove-Tree {
    param([Parameter(Mandatory)][string]$Path)
    Remove-Item -LiteralPath (ConvertTo-LongPath $Path) -Recurse -Force
}

function Get-RobocopyCommonArgs {
    $arguments = @('/COPY:DAT', '/DCOPY:T', '/R:2', '/W:5', '/NP', '/NFL', '/NDL', '/NJH', '/NJS')
    if ($script:LogFile) { $arguments += "/UNILOG+:$($script:LogFile).robocopy" }
    # /B lit les fichiers proteges par leurs droits, mais exige le privilege de sauvegarde.
    if (Test-IsAdmin) { $arguments += '/B' }
    return $arguments
}

# Robocopy renvoie un masque : 8 ou plus signale des fichiers non copies.
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

# Copie des fichiers precis d'un meme dossier, par lots pour respecter la longueur de commande.
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

# Instantane VSS : permet de lire les fichiers ouverts (droits administrateur requis).
function New-VssSnapshot {
    param([Parameter(Mandatory)][string]$Volume)
    $created = Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{ Volume = $Volume; Context = 'ClientAccessible' }
    if ($created.ReturnValue -ne 0) { throw "Creation de l'instantane VSS impossible (code $($created.ReturnValue))." }
    $shadow = Get-CimInstance -ClassName Win32_ShadowCopy -Filter "ID='$($created.ShadowID)'"
    # %SystemRoot%\Temp n'est pas modifiable par un compte standard, contrairement a %TEMP%.
    $link = Join-Path $env:SystemRoot ("Temp\wtb-vss-{0}" -f [guid]::NewGuid().ToString('N'))
    & cmd.exe /c mklink /d "$link" "$($shadow.DeviceObject)\" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-CimInstance -InputObject $shadow
        throw "Montage de l'instantane VSS impossible."
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
    # Le verrou exclusif empeche une sauvegarde manuelle et une tache planifiee de se croiser.
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
            if ($volume.StartsWith('\\')) { throw 'VSS ne fonctionne pas sur un partage reseau.' }
            $snapshot = New-VssSnapshot -Volume $volume
            $readRoot = [IO.Path]::Combine($snapshot.Link, $Source.Substring($volume.Length))
        }

        Write-Progress -Activity 'Sauvegarde' -Status 'Analyse de la source'
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
            Write-Log -Message "Sauvegarde $Source : aucun changement."
            return [pscustomobject]@{ Status = 'NoChange'; Id = $catalog[-1].Id; SetPath = $setPath; CopiedFiles = 0; CopiedBytes = 0; TotalFiles = $entries.Count; Failed = 0; Unreadable = $listing.Errors.Count; Links = $listing.Links.Count; Chain = $effectiveMode }
        }
        Assert-FreeSpace -Path $Destination -Needed $bytesToCopy

        $suffix = if ($effectiveMode -eq 'Full') { 'full' } else { 'incr' }
        $id = '{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff'), $suffix
        $tempDir = [IO.Path]::Combine($setPath, ".tmp-$id")
        $dataDir = [IO.Path]::Combine($tempDir, 'data')
        [void][IO.Directory]::CreateDirectory($dataDir)

        # Une copie globale est bien plus rapide pour une sauvegarde complete, tant que la
        # liste d'exclusions des liens tient dans la longueur maximale d'une commande.
        $linkPaths = @($listing.Links | ForEach-Object { [IO.Path]::Combine($readRoot, $_) })
        $linkLength = ($linkPaths | Measure-Object -Property Length -Sum).Sum
        Write-Progress -Activity 'Sauvegarde' -Status ('Copie de {0} fichiers ({1})' -f $toCopy.Count, (Format-Bytes $bytesToCopy))
        if ($effectiveMode -eq 'Full' -and $linkLength -lt 20000) {
            [void](Copy-Tree -From $readRoot -To $dataDir -ExcludeDirs (@($ExcludeDirs) + $linkPaths) -ExcludeFiles (@($ExcludeFiles) + $linkPaths))
            # Copier une racine de lecteur rend le dossier cible cache et systeme.
            if (Test-IsWindows) { [IO.File]::SetAttributes($dataDir, [IO.FileAttributes]::Directory) }
        }
        else {
            foreach ($group in Group-EntriesForCopy -Entries $toCopy -StoreSelector { 'source' }) {
                $fromDir = [IO.Path]::Combine($readRoot, $group.Dir)
                $toDir = [IO.Path]::Combine($dataDir, $group.Dir)
                [void](Copy-FileGroup -FromDir $fromDir -ToDir $toDir -Names $group.Names.ToArray())
            }
        }

        # Chaque copie est controlee individuellement : le code de robocopy ne dit pas quels
        # fichiers manquent. Un fichier rate garde sa version precedente dans le manifeste.
        $failed = New-Object 'System.Collections.Generic.List[string]'
        $copiedBytes = [long]0
        $done = 0
        foreach ($file in $toCopy) {
            $done++
            if ($done % 200 -eq 0) {
                Write-Progress -Activity 'Sauvegarde' -Status 'Controle des copies' -PercentComplete ([int](100 * $done / $toCopy.Count))
            }
            $stored = [IO.Path]::Combine($dataDir, $file.Rel)
            try {
                $copy = [IO.FileInfo]::new((ConvertTo-LongPath $stored))
                if (-not $copy.Exists -or $copy.Length -ne $file.Size) { throw 'copie absente ou incomplete' }
                $entries.Add([pscustomobject]@{ Size = $file.Size; Ticks = $file.Ticks; Hash = (Get-FileSha256 $stored); Store = $id; Rel = $file.Rel })
                $copiedBytes += $file.Size
            }
            catch {
                $failed.Add($file.Rel)
                $known = $previous[$file.Rel]
                if ($known) { $entries.Add($known) }
            }
        }
        Write-Progress -Activity 'Sauvegarde' -Completed

        $status = if ($failed.Count -or $listing.Errors.Count) { 'Partial' } else { 'Complete' }
        Write-Manifest -Path ([IO.Path]::Combine($tempDir, 'files.tsv')) -Entries $entries.ToArray()
        [IO.File]::WriteAllLines([IO.Path]::Combine($tempDir, 'dirs.txt'), [string[]]$listing.Dirs.ToArray())
        [IO.File]::WriteAllLines([IO.Path]::Combine($tempDir, 'errors.txt'), [string[]](@($failed | ForEach-Object { "COPIE`t$_" }) + @($listing.Errors | ForEach-Object { "LECTURE`t$_" })))

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
        Write-Log -Level $level -Message ('Sauvegarde {0} -> {1} : {2}, {3}, {4} fichiers copies, {5} echecs, {6} dossiers illisibles.' -f $Source, $id, $effectiveMode, $status, $meta.CopiedFiles, $failed.Count, $listing.Errors.Count)
        return [pscustomobject]@{ Status = $status; Id = $id; SetPath = $setPath; CopiedFiles = $meta.CopiedFiles; CopiedBytes = $copiedBytes; TotalFiles = $entries.Count; Failed = $failed.Count; Unreadable = $listing.Errors.Count; Links = $listing.Links.Count; Chain = $effectiveMode }
    }
    finally {
        if ($tempDir -and [IO.Directory]::Exists($tempDir)) {
            try { Remove-Tree $tempDir } catch { Write-Log -Level WARN -Message "Dossier temporaire non supprime : $tempDir" }
        }
        if ($snapshot) {
            try { Remove-VssSnapshot -Snapshot $snapshot } catch { Write-Log -Level WARN -Message "Instantane VSS non supprime : $($_.Exception.Message)" }
        }
        $lock.Dispose()
    }
}

# Controle chaque fichier d'une version avec son empreinte SHA-256.
function Test-Backup {
    param([Parameter(Mandatory)][string]$BackupPath)
    $setPath = [IO.Path]::GetDirectoryName($BackupPath)
    $missing = New-Object 'System.Collections.Generic.List[string]'
    $corrupt = New-Object 'System.Collections.Generic.List[string]'
    $checked = 0
    foreach ($entry in Read-Manifest -Path ([IO.Path]::Combine($BackupPath, 'files.tsv'))) {
        $checked++
        if ($checked % 200 -eq 0) { Write-Progress -Activity 'Verification' -Status "$checked fichiers" }
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
    if (Test-PathInside -Child $Target -Parent $setPath) { throw 'La cible ne doit pas se trouver dans le depot de sauvegarde.' }

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
        if ($done % 200 -eq 0) { Write-Progress -Activity 'Restauration' -Status 'Controle' -PercentComplete ([int](100 * $done / $selected.Count)) }
        $restored = [IO.Path]::Combine($Target, $entry.Rel)
        try {
            if ((Get-FileSha256 $restored) -ne $entry.Hash) { $failed.Add($entry.Rel) }
        }
        catch { $failed.Add($entry.Rel) }
    }
    Write-Progress -Activity 'Restauration' -Completed
    Write-Log -Level $(if ($failed.Count) { 'WARN' } else { 'INFO' }) -Message ('Restauration {0} -> {1} : {2} fichiers, {3} echecs.' -f $BackupPath, $Target, $selected.Count, $failed.Count)
    return [pscustomobject]@{ Restored = $selected.Count - $failed.Count; Failed = $failed; Ok = ($failed.Count -eq 0) }
}

# Conserve les N chaines les plus recentes. Une chaine (une complete et ses incrementales)
# est supprimee d'un bloc : aucune version conservee ne depend d'une chaine plus ancienne.
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
    Write-Log -Message "Retention $SetPath : $($removed.Count) versions supprimees."
    return $removed
}

function Start-SystemImageBackup {
    param([Parameter(Mandatory)][string]$TargetDrive)
    if ($TargetDrive -notmatch '^[A-Za-z]:$') { throw 'Indiquez un lecteur au format E:' }
    if ($TargetDrive -ieq $env:SystemDrive) { throw "L'image systeme ne peut pas etre stockee sur le disque systeme." }
    & wbadmin.exe start backup "-backupTarget:$TargetDrive" -allCritical -quiet | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "wbadmin a echoue (code $LASTEXITCODE)." }
    Write-Log -Message "Image systeme creee sur $TargetDrive."
}

# Un \ final echapperait le guillemet fermant : "D:\" doit s'ecrire "D:\\".
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
    if ($Name -notmatch '^[\w -]{1,50}$') { throw 'Nom de tache invalide.' }
    $Source = Resolve-FullPath $Source
    $Destination = Resolve-FullPath $Destination
    Assert-BackupPaths -Source $Source -Destination $Destination
    $at = [datetime]::ParseExact($Time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -Task Backup -Source {1} -Destination {2} -Mode Incremental -FullEvery {3} -KeepChains {4}' -f (ConvertTo-QuotedArgument $script:EntryScript), (ConvertTo-QuotedArgument $Source), (ConvertTo-QuotedArgument $Destination), $FullEvery, $KeepChains
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = if ($Frequency -eq 'Daily') { New-ScheduledTaskTrigger -Daily -At $at } else { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $at }
    # Droits limites du compte courant : le script vit dans un dossier modifiable par
    # l'utilisateur, l'executer en SYSTEM offrirait une elevation de privileges.
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    [void](Register-ScheduledTask -TaskPath '\WinToolBox\' -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force)
    Write-Log -Message "Tache planifiee creee : $Name."
}

# --- Interface ---

function Select-BackupSet {
    $root = Read-Text 'Dossier de destination des sauvegardes'
    if (-not $root) { return $null }
    $root = Resolve-FullPath $root
    if (-not [IO.Directory]::Exists($root)) { throw "Dossier introuvable : $root" }
    $sets = @([IO.Directory]::GetDirectories($root) | Where-Object { @(Get-BackupCatalog -SetPath $_).Count -gt 0 })
    if ($sets.Count -eq 0) {
        Write-Status WARN 'Aucune sauvegarde dans ce dossier.'
        return $null
    }
    return (Select-FromList -Items $sets -Format { param($s) [IO.Path]::GetFileName($s) })
}

function Format-BackupLabel {
    param([Parameter(Mandatory)][object]$Backup)
    # ConvertFrom-Json renvoie une chaine sous PowerShell 5.1 et une date sous PowerShell 7.
    $when = ([datetime]$Backup.CreatedUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    return ('{0}  {1,-11}  {2,-8}  {3} fichiers  {4}' -f $when, $Backup.Type, $Backup.Status, $Backup.FileCount, (Format-Bytes $Backup.TotalBytes))
}

function Select-Backup {
    $set = Select-BackupSet
    if (-not $set) { return $null }
    return (Select-FromList -Items @(Get-BackupCatalog -SetPath $set) -Format { param($b) Format-BackupLabel $b })
}

function Write-BackupResult {
    param([Parameter(Mandatory)][object]$Result)
    switch ($Result.Status) {
        'NoChange' { Write-Status OK 'Aucun changement depuis la derniere sauvegarde.' }
        'Complete' { Write-Status OK ('Sauvegarde terminee ({0}) : {1} fichiers copies, {2}.' -f $Result.Chain, $Result.CopiedFiles, (Format-Bytes $Result.CopiedBytes)) }
        default { Write-Status WARN ('Sauvegarde partielle : {0} copies, {1} echecs, {2} dossiers illisibles. Voir errors.txt dans {3}.' -f $Result.CopiedFiles, $Result.Failed, $Result.Unreadable, $Result.Id) }
    }
    if ($Result.Links) { Write-Status INFO "$($Result.Links) liens et jonctions ignores." }
}

function Invoke-BackupWizard {
    $source = Read-Text 'Dossier a sauvegarder'
    $destination = Read-Text 'Dossier de destination'
    if (-not $source -or -not $destination) { return }
    $mode = if ((Read-Text 'Type : [I]ncrementale ou [C]omplete') -ieq 'C') { 'Full' } else { 'Incremental' }
    $useVss = (Test-IsAdmin) -and (Confirm-Action 'Inclure les fichiers ouverts avec VSS ?')
    Write-BackupResult -Result (New-Backup -Source $source -Destination $destination -Mode $mode -UseVss:$useVss)
}

function Invoke-RestoreWizard {
    $backup = Select-Backup
    if (-not $backup) { return }
    $target = Read-Text 'Dossier de restauration'
    if (-not $target) { return }
    $filter = Read-Text 'Filtre, par exemple Photos\* (vide pour tout restaurer)'
    if (-not $filter) { $filter = '*' }
    if (-not (Confirm-Action "Les fichiers de meme nom seront ecrases dans $target. Continuer ?")) { return }
    $result = Restore-Backup -BackupPath $backup.Path -Target $target -Filter $filter
    if ($result.Ok) { Write-Status OK "$($result.Restored) fichiers restaures et verifies." }
    else {
        Write-Status FAIL "$($result.Failed.Count) fichiers non restaures :"
        $result.Failed | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    }
}

function Invoke-VerifyWizard {
    $backup = Select-Backup
    if (-not $backup) { return }
    $result = Test-Backup -BackupPath $backup.Path
    if ($result.Ok) { Write-Status OK "$($result.Checked) fichiers verifies, aucune anomalie." }
    else {
        Write-Status FAIL ('{0} fichiers manquants et {1} corrompus sur {2}.' -f $result.Missing.Count, $result.Corrupt.Count, $result.Checked)
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
    if (-not [int]::TryParse((Read-Text 'Nombre de chaines completes a conserver'), [ref]$keep) -or $keep -lt 1) {
        Write-Status WARN 'Nombre invalide.'
        return
    }
    if (-not (Confirm-Phrase -Message 'Les versions plus anciennes seront supprimees definitivement.' -Phrase 'SUPPRIMER')) { return }
    $removed = @(Remove-OldBackupChains -SetPath $set -KeepChains $keep)
    Write-Status OK "$($removed.Count) versions supprimees."
}

function Invoke-ScheduleWizard {
    $tasks = @(Get-ScheduledTask -TaskPath '\WinToolBox\' -ErrorAction SilentlyContinue)
    if ($tasks.Count) { $tasks | Select-Object TaskName, State | Format-Table -AutoSize | Out-Host }
    else { Write-Status INFO 'Aucune tache planifiee.' }
    switch ((Read-Text '[A]jouter, [S]upprimer (vide pour revenir)').ToUpperInvariant()) {
        'A' {
            $name = Read-Text 'Nom de la tache'
            $source = Read-Text 'Dossier a sauvegarder'
            $destination = Read-Text 'Destination locale ou disque externe'
            $time = Read-Text 'Heure (HH:mm)'
            $frequency = if ((Read-Text '[Q]uotidienne ou [H]ebdomadaire') -ieq 'H') { 'Weekly' } else { 'Daily' }
            Write-Status INFO 'Windows va demander de confirmer le compte si necessaire.'
            Register-BackupSchedule -Name $name -Source $source -Destination $destination -Time $time -Frequency $frequency
            Write-Status OK "Tache '$name' creee : une complete toutes les 7 executions, 4 chaines conservees."
        }
        'S' {
            $task = Select-FromList -Items $tasks -Format { param($t) $t.TaskName }
            if ($task -and (Confirm-Action "Supprimer la tache $($task.TaskName) ?")) {
                Unregister-ScheduledTask -InputObject $task -Confirm:$false
                Write-Status OK 'Tache supprimee. Les sauvegardes existantes sont conservees.'
            }
        }
    }
}

function Invoke-SystemImageWizard {
    Write-Status INFO "L'image se restaure depuis l'environnement de recuperation Windows."
    $target = (Read-Text 'Lecteur cible, par exemple E:').ToUpperInvariant()
    if ($target -and (Confirm-Action "Creer une image systeme sur $target ?")) { Start-SystemImageBackup -TargetDrive $target }
}

function Invoke-RestorePoint {
    Checkpoint-Computer -Description "WinToolBox $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType MODIFY_SETTINGS
    Write-Status OK 'Demande de point de restauration envoyee (Windows limite la frequence a un par 24 h).'
}

function Show-BackupMenu {
    Show-Menu -Title 'Sauvegarde et restauration' -Items @(
        @{ Section = 'FICHIERS'; Key = '1'; Label = 'Nouvelle sauvegarde'; Action = { Invoke-BackupWizard } }
        @{ Section = 'FICHIERS'; Key = '2'; Label = 'Restaurer une version'; Action = { Invoke-RestoreWizard } }
        @{ Section = 'FICHIERS'; Key = '3'; Label = 'Verifier une version'; Action = { Invoke-VerifyWizard } }
        @{ Section = 'FICHIERS'; Key = '4'; Label = 'Lister les versions'; Action = { Show-BackupList } }
        @{ Section = 'FICHIERS'; Key = '5'; Label = 'Supprimer les anciennes versions'; Action = { Invoke-RetentionWizard } }
        @{ Section = 'AUTOMATISATION'; Key = '6'; Label = 'Taches planifiees'; Admin = $true; Action = { Invoke-ScheduleWizard } }
        @{ Section = 'SYSTEME'; Key = '7'; Label = 'Image systeme complete'; Admin = $true; Action = { Invoke-SystemImageWizard } }
        @{ Section = 'SYSTEME'; Key = '8'; Label = 'Point de restauration'; Admin = $true; Action = { Invoke-RestorePoint } }
    )
}

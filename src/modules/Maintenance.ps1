# Nettoyage avec analyse prealable, et reparation de Windows.

function Get-CleanupTargets {
    $targets = @(
        @{ Name = 'Fichiers temporaires utilisateur'; Root = $env:TEMP; MinAgeDays = 1; Admin = $false; Filter = '*' }
        @{ Name = 'Fichiers temporaires Windows'; Root = (Join-Path $env:SystemRoot 'Temp'); MinAgeDays = 1; Admin = $true; Filter = '*' }
        @{ Name = 'Cache Windows Update'; Root = (Join-Path $env:SystemRoot 'SoftwareDistribution\Download'); MinAgeDays = 0; Admin = $true; Filter = '*'; Service = 'wuauserv' }
        @{ Name = 'Miniatures de l''explorateur'; Root = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'); MinAgeDays = 0; Admin = $false; Filter = 'thumbcache_*.db' }
        @{ Name = 'Rapports de plantage'; Root = (Join-Path $env:LOCALAPPDATA 'CrashDumps'); MinAgeDays = 0; Admin = $false; Filter = '*' }
        @{ Name = 'Vidages memoire systeme'; Root = (Join-Path $env:SystemRoot 'Minidump'); MinAgeDays = 0; Admin = $true; Filter = '*' }
    )
    return $targets
}

# Selectionne les fichiers eligibles sans rien modifier.
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

# Supprime les candidats puis les dossiers vides ; les fichiers verrouilles sont comptes, pas caches.
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
        catch { Write-Verbose "Dossier conserve : $dir" }
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
    Write-Status INFO 'Analyse en cours, rien n''est supprime a cette etape.'
    foreach ($target in Get-CleanupTargets) {
        if ($target.Admin -and -not $isAdmin) { continue }
        $candidates = @(Get-CleanupCandidates -Root $target.Root -MinAgeDays $target.MinAgeDays -Filter $target.Filter)
        $size = ($candidates | Measure-Object -Property Size -Sum).Sum
        $rows.Add([pscustomobject]@{ Name = $target.Name; Target = $target; Candidates = $candidates; Size = [long]$size })
    }
    $rows.Add([pscustomobject]@{ Name = 'Corbeille (tous les lecteurs)'; Target = $null; Candidates = @(); Size = (Get-RecycleBinSize) })

    for ($i = 0; $i -lt $rows.Count; $i++) {
        Write-Host ('   [{0}] {1,-38} {2,10}' -f ($i + 1), $rows[$i].Name, (Format-Bytes $rows[$i].Size))
    }
    if (-not $isAdmin) { Write-Status INFO 'Les caches systeme demandent les droits administrateur.' }
    $answer = Read-Text 'Numeros separes par des virgules, A pour tout, vide pour annuler'
    if (-not $answer) { return }

    $selected = if ($answer -ieq 'A') { @($rows) } else {
        @($answer -split '[,; ]+' | ForEach-Object {
                $n = 0
                if ([int]::TryParse($_, [ref]$n) -and $n -ge 1 -and $n -le $rows.Count) { $rows[$n - 1] }
            })
    }
    if ($selected.Count -eq 0) {
        Write-Status WARN 'Aucune selection valide.'
        return
    }
    $announced = ($selected | Measure-Object -Property Size -Sum).Sum
    if (-not (Confirm-Action ('Supprimer environ {0} ?' -f (Format-Bytes $announced)))) { return }

    $totalFreed = [long]0
    $totalLocked = 0
    foreach ($row in $selected) {
        if ($null -eq $row.Target) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            $totalFreed += $row.Size
            Write-Status OK "$($row.Name) : videe."
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
        Write-Status OK ('{0} : {1} liberes, {2} fichiers utilises conserves.' -f $row.Name, (Format-Bytes $result.Freed), $result.Locked)
    }
    Write-Log -Message "Nettoyage : $totalFreed octets liberes, $totalLocked fichiers conserves."
    Write-Host ''
    Write-Status OK ('Total libere : {0}.' -f (Format-Bytes $totalFreed))
}

# Les commandes affichent leur progression ; seul leur code de retour decide du resultat.
function Invoke-RepairCommand {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Command, [string[]]$Arguments)
    Write-Status INFO "$Label : cette operation peut durer plusieurs minutes."
    & $Command @Arguments | Out-Host
    $code = $LASTEXITCODE
    Write-Log -Message "$Label : code $code."
    if ($code -eq 0) { Write-Status OK "$Label termine." }
    else { Write-Status FAIL "$Label a renvoye le code $code." }
}

function Show-MaintenanceMenu {
    Show-Menu -Title 'Nettoyage et reparation' -Items @(
        @{ Section = 'NETTOYAGE'; Key = '1'; Label = 'Analyser et nettoyer'; Action = { Invoke-CleanupWizard } }
        @{ Section = 'NETTOYAGE'; Key = '2'; Label = 'Reduire le magasin de composants Windows'; Admin = $true; Action = { Invoke-RepairCommand -Label 'Nettoyage des composants' -Command 'dism.exe' -Arguments '/Online', '/Cleanup-Image', '/StartComponentCleanup' } }
        @{ Section = 'REPARATION'; Key = '3'; Label = 'Reparer l''image Windows (DISM)'; Admin = $true; Action = { Invoke-RepairCommand -Label 'Reparation DISM' -Command 'dism.exe' -Arguments '/Online', '/Cleanup-Image', '/RestoreHealth' } }
        @{ Section = 'REPARATION'; Key = '4'; Label = 'Verifier les fichiers systeme (SFC)'; Admin = $true; Action = { Invoke-RepairCommand -Label 'Verification SFC' -Command 'sfc.exe' -Arguments '/scannow' } }
    )
}

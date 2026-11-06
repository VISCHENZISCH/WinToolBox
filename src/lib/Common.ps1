# Socle commun : environnement, journal, affichage, saisies et parcours de fichiers.

$script:LogFile = $null
$script:ReportDir = $null
$script:MaxLogBytes = 5MB

function Test-IsWindows { return ($env:OS -eq 'Windows_NT') }

function Test-IsAdmin {
    if (-not (Test-IsWindows)) { return $false }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-App {
    param([Parameter(Mandatory)][string]$Root)
    $logDir = Join-Path $Root 'logs'
    $script:ReportDir = Join-Path $Root 'reports'
    foreach ($dir in $logDir, $script:ReportDir) { [void][IO.Directory]::CreateDirectory($dir) }
    $script:LogFile = Join-Path $logDir 'wintoolbox.log'
}

# Le journal ne doit jamais faire echouer l'operation qu'il documente.
function Write-Log {
    param(
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $script:LogFile) { return }
    try {
        if ((Test-Path -LiteralPath $script:LogFile) -and (Get-Item -LiteralPath $script:LogFile).Length -gt $script:MaxLogBytes) {
            Move-Item -LiteralPath $script:LogFile -Destination "$script:LogFile.1" -Force
        }
        $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        [IO.File]::AppendAllText($script:LogFile, $line + [Environment]::NewLine)
    }
    catch { Write-Verbose "Journal indisponible : $($_.Exception.Message)" }
}

function Format-Bytes {
    param([double]$Bytes)
    $units = 'o', 'Ko', 'Mo', 'Go', 'To', 'Po'
    $index = 0
    while ($Bytes -ge 1024 -and $index -lt $units.Count - 1) {
        $Bytes /= 1024
        $index++
    }
    if ($index -eq 0) { return ('{0:0} {1}' -f $Bytes, $units[$index]) }
    return ('{0:0.0} {1}' -f $Bytes, $units[$index])
}

# Convertit une taille saisie en Go ("1,5" ou "1.5") en octets ; $null si invalide.
function ConvertTo-BytesFromGb {
    param([string]$Text)
    $value = 0.0
    $normalized = "$Text".Trim().Replace(',', '.')
    $ok = [double]::TryParse($normalized, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)
    if (-not $ok -or $value -le 0) { return $null }
    return [long]($value * 1GB)
}

function Write-Title {
    param([string]$Text)
    Write-Host ''
    Write-Host "  $Text" -ForegroundColor White
    Write-Host ('  ' + ('-' * 72)) -ForegroundColor DarkGray
}

function Write-Status {
    param(
        [ValidateSet('OK', 'WARN', 'FAIL', 'INFO')][string]$Level,
        [string]$Message
    )
    $colors = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red'; INFO = 'Gray' }
    Write-Host ('  [{0,-4}] {1}' -f $Level, $Message) -ForegroundColor $colors[$Level]
}

function Wait-Key {
    Write-Host ''
    [void](Read-Host '  Entree pour continuer')
}

function Read-Text {
    param([string]$Prompt)
    return "$(Read-Host "  $Prompt")".Trim().Trim('"')
}

function Confirm-Action {
    param([string]$Message)
    return ((Read-Text "$Message [O/N]") -ieq 'O')
}

# Pour les actions irreversibles : la phrase exacte doit etre retapee.
function Confirm-Phrase {
    param([string]$Message, [Parameter(Mandatory)][string]$Phrase)
    Write-Status WARN $Message
    return ((Read-Text "Tapez exactement '$Phrase' pour confirmer") -ceq $Phrase)
}

# Affiche une liste numerotee et renvoie l'element choisi, ou $null.
function Select-FromList {
    param(
        [object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Format,
        [string]$Prompt = 'Numero (vide pour annuler)'
    )
    $Items = @($Items)
    if ($Items.Count -eq 0) { return $null }
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ('   [{0}] {1}' -f ($i + 1), (& $Format $Items[$i]))
    }
    $number = 0
    if (-not [int]::TryParse((Read-Text $Prompt), [ref]$number)) { return $null }
    if ($number -lt 1 -or $number -gt $Items.Count) { return $null }
    return $Items[$number - 1]
}

function Invoke-MenuAction {
    param([Parameter(Mandatory)][hashtable]$Item)
    if ($Item.Admin -and -not (Test-IsAdmin)) {
        Write-Status WARN 'Cette action demande les droits administrateur.'
        Wait-Key
        return
    }
    try {
        & $Item.Action | Out-Host
    }
    catch {
        Write-Status FAIL $_.Exception.Message
        Write-Log -Level ERROR -Message "$($Item.Label) : $($_.Exception.Message)"
    }
    if (-not $Item.Submenu) { Wait-Key }
}

# Menu pilote par les donnees. Chaque element : Key, Label, Action, et en option
# Section, Admin (droits requis) et Submenu (pas de pause au retour).
function Show-Menu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable[]]$Items,
        [string]$ExitLabel = 'Retour',
        [scriptblock]$Header
    )
    while ($true) {
        $isAdmin = Test-IsAdmin
        Clear-Host
        Write-Title $Title
        if ($Header) { & $Header }
        $section = $null
        foreach ($item in $Items) {
            if ($item.Section -and $item.Section -ne $section) {
                $section = $item.Section
                Write-Host ''
                Write-Host "  $section" -ForegroundColor Cyan
            }
            $suffix = if ($item.Admin -and -not $isAdmin) { '  (admin requis)' } else { '' }
            Write-Host ('   [{0}] {1}{2}' -f $item.Key, $item.Label, $suffix)
        }
        Write-Host ''
        Write-Host "   [Q] $ExitLabel"
        Write-Host ''
        $choice = Read-Text 'Choix'
        if ($choice -ieq 'Q') { return }
        if (-not $choice) { continue }
        $selected = $Items | Where-Object { $_.Key -ieq $choice } | Select-Object -First 1
        if (-not $selected) {
            Write-Status WARN "Option '$choice' invalide."
            Start-Sleep -Seconds 1
            continue
        }
        Write-Host ''
        Invoke-MenuAction -Item $selected
    }
}

function Resolve-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) { $full = $full.TrimEnd('\', '/') }
    return $full
}

# Vrai si $Child est $Parent ou se trouve a l'interieur.
function Test-PathInside {
    param([Parameter(Mandatory)][string]$Child, [Parameter(Mandatory)][string]$Parent)
    $separators = '\', '/'
    $childNorm = $Child.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    $parentNorm = $Parent.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    return $childNorm.StartsWith($parentNorm, [StringComparison]::OrdinalIgnoreCase)
}

# Prefixe \\?\ pour franchir la limite de 260 caracteres dans les appels .NET.
function ConvertTo-LongPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-IsWindows) -or $Path.StartsWith('\\?\')) { return $Path }
    if ($Path.StartsWith('\\')) { return '\\?\UNC\' + $Path.Substring(2) }
    return '\\?\' + $Path
}

function Test-LinkItem {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)
    # Les dossiers OneDrive sont aussi des points d'analyse : seuls les vrais liens sont ignores.
    try { return ($Item.LinkType -in 'Junction', 'SymbolicLink') }
    catch { return $true }
}

# Parcours iteratif resistant aux erreurs d'acces : renvoie Files, Dirs, Links et Errors.
# Les chemins sont relatifs a $Root ; les liens ne sont jamais suivis, ce qui evite les boucles.
function Get-FileEntries {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )
    $files = New-Object 'System.Collections.Generic.List[object]'
    $dirs = New-Object 'System.Collections.Generic.List[string]'
    $links = New-Object 'System.Collections.Generic.List[string]'
    $errors = New-Object 'System.Collections.Generic.List[string]'
    $separator = [IO.Path]::DirectorySeparatorChar
    $prefix = (ConvertTo-LongPath $Root).TrimEnd('\', '/') + $separator
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($prefix)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try { $children = ([IO.DirectoryInfo]::new($current)).GetFileSystemInfos() }
        catch {
            $relative = if ($current.Length -gt $prefix.Length) { $current.Substring($prefix.Length) } else { '.' }
            $errors.Add($relative)
            continue
        }
        foreach ($child in $children) {
            $relative = $child.FullName.Substring($prefix.Length)
            $isReparse = ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($isReparse -and (Test-LinkItem $child)) {
                $links.Add($relative)
            }
            elseif ($child -is [IO.DirectoryInfo]) {
                if ($ExcludeDirs -notcontains $child.Name) {
                    $dirs.Add($relative)
                    $stack.Push($child.FullName)
                }
            }
            elseif ($ExcludeFiles -notcontains $child.Name) {
                $files.Add([pscustomobject]@{
                        Rel   = $relative
                        Size  = $child.Length
                        Ticks = $child.LastWriteTimeUtc.Ticks
                    })
            }
        }
    }
    return [pscustomobject]@{ Files = $files; Dirs = $dirs; Links = $links; Errors = $errors }
}

function New-ReportPath {
    param([Parameter(Mandatory)][string]$Prefix)
    return (Join-Path $script:ReportDir ('{0}-{1}.txt' -f $Prefix, (Get-Date -Format 'yyyyMMdd-HHmmss')))
}

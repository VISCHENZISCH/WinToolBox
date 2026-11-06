# Shared foundation: environment, logging, display, input and file traversal.

$script:LogFile = $null
$script:ReportDir = $null
$script:MaxLogBytes = 5MB
$script:RuleWidth = 72
$script:MenuPath = New-Object 'System.Collections.Generic.List[string]'
$script:LongPathSupported = $null

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

# Logging must never make the operation it documents fail.
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
    catch { Write-Verbose "Log unavailable: $($_.Exception.Message)" }
}

function Format-Bytes {
    param([double]$Bytes)
    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
    $index = 0
    while ($Bytes -ge 1024 -and $index -lt $units.Count - 1) {
        $Bytes /= 1024
        $index++
    }
    if ($index -eq 0) { return ('{0:0} {1}' -f $Bytes, $units[$index]) }
    return ('{0:0.0} {1}' -f $Bytes, $units[$index])
}

# Converts a size entered in GB ("1,5" or "1.5") to bytes; $null if invalid.
function ConvertTo-BytesFromGb {
    param([string]$Text)
    $value = 0.0
    # "1,000" could mean 1 or 1000: an ambiguous size must not be guessed for a disk operation.
    if ("$Text".Trim() -match '^\d{1,3}([.,]\d{3})+$') { return $null }
    $normalized = "$Text".Trim().Replace(',', '.')
    $ok = [double]::TryParse($normalized, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)
    if (-not $ok -or $value -le 0) { return $null }
    return [long]($value * 1GB)
}

# Clear-Host was seen moving the cursor home without erasing, so new text landed on top of the
# previous screen. [Console]::Clear() erases the whole buffer directly; it throws without a real console.
function Clear-Screen {
    try { [Console]::Clear() }
    catch { Clear-Host }
}

function Write-Separator {
    Write-Host ('  ' + ('*' * $script:RuleWidth)) -ForegroundColor DarkGray
}

function Write-Title {
    param([string]$Text)
    Write-Host ''
    Write-Separator
    Write-Host "  $Text" -ForegroundColor White
    Write-Separator
}

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host "  *** $Text" -ForegroundColor Cyan
}

function Get-ConsoleWidth {
    try {
        $width = [Console]::WindowWidth - 4
        if ($width -ge 40) { return $width }
    }
    catch { Write-Verbose 'No console: using the default width.' }
    return 116
}

function Format-Cell {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [bool]) { return $(if ($Value) { 'Yes' } else { 'No' }) }
    if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd HH:mm') }
    return ("$Value" -replace '[\x00-\x1F]', ' ').Trim()
}

# Renders objects as text lines: header, a rule of stars, then rows. PowerShell's own table
# format draws a rule of dashes that cannot be changed. When the width is too small, the widest columns are cut first.
function Format-TextTable {
    param([object[]]$Rows, [int]$Width = 116)
    $Rows = @($Rows | Where-Object { $null -ne $_ })
    if ($Rows.Count -eq 0) { return @() }
    $columns = @($Rows[0].PSObject.Properties | ForEach-Object { $_.Name })
    $widths = @($columns | ForEach-Object { $_.Length })
    $cells = New-Object 'System.Collections.Generic.List[object]'
    foreach ($row in $Rows) {
        $line = New-Object 'string[]' $columns.Count
        for ($i = 0; $i -lt $columns.Count; $i++) {
            $line[$i] = Format-Cell $row.($columns[$i])
            if ($line[$i].Length -gt $widths[$i]) { $widths[$i] = $line[$i].Length }
        }
        $cells.Add($line)
    }

    $available = $Width - (2 * ($columns.Count - 1))
    while (($widths | Measure-Object -Sum).Sum -gt $available) {
        $widest = 0
        for ($i = 1; $i -lt $widths.Count; $i++) { if ($widths[$i] -gt $widths[$widest]) { $widest = $i } }
        if ($widths[$widest] -le 6) { break }
        $widths[$widest]--
    }

    $render = {
        param([string[]]$Values)
        $parts = for ($i = 0; $i -lt $Values.Count; $i++) {
            $text = $Values[$i]
            if ($text.Length -gt $widths[$i]) { $text = $text.Substring(0, $widths[$i] - 3) + '...' }
            $text.PadRight($widths[$i])
        }
        return ($parts -join '  ').TrimEnd()
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add((& $render $columns))
    $lines.Add((& $render @($widths | ForEach-Object { '*' * $_ })))
    foreach ($line in $cells) { $lines.Add((& $render $line)) }
    return $lines.ToArray()
}

function Write-Table {
    param([object[]]$Rows, [string]$Empty = 'Nothing to show.')
    $lines = @(Format-TextTable -Rows $Rows -Width (Get-ConsoleWidth))
    if ($lines.Count -eq 0) {
        Write-Status INFO $Empty
        return
    }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $color = switch ($i) { 0 { 'White' } 1 { 'DarkGray' } default { 'Gray' } }
        Write-Host "   $($lines[$i])" -ForegroundColor $color
    }
}

# Aligned "name  value" lines, for results that describe a single thing.
function Write-Details {
    param([Parameter(Mandatory)][Collections.IDictionary]$Items)
    $width = ($Items.Keys | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum
    foreach ($key in $Items.Keys) {
        Write-Host ("   {0}  {1}" -f "$key".PadRight($width), (Format-Cell $Items[$key]))
    }
}

function Write-PathList {
    param([object[]]$Paths, [int]$Limit = 20)
    $Paths = @($Paths)
    $Paths | Select-Object -First $Limit | ForEach-Object { Write-Host "    $_" }
    if ($Paths.Count -gt $Limit) { Write-Host "    ... and $($Paths.Count - $Limit) more" -ForegroundColor DarkGray }
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
    [void](Read-Host '  Press Enter to continue')
}

function Read-Text {
    param([string]$Prompt)
    return "$(Read-Host "  $Prompt")".Trim().Trim('"')
}

function Confirm-Action {
    param([string]$Message)
    return ((Read-Text "$Message [Y/N]") -ieq 'Y')
}

# For irreversible actions: the exact phrase must be typed back.
function Confirm-Phrase {
    param([string]$Message, [Parameter(Mandatory)][string]$Phrase)
    Write-Status WARN $Message
    return ((Read-Text "Type exactly '$Phrase' to confirm") -ceq $Phrase)
}

# Displays a numbered list and returns the chosen item, or $null.
function Select-FromList {
    param(
        [object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Format,
        [string]$Prompt = 'Number (leave blank to cancel)'
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
    # Each result starts on a clean screen that says where it comes from.
    if (-not $Item.Submenu) {
        Clear-Screen
        Write-Title ((@($script:MenuPath) + $Item.Label) -join ' > ')
    }
    if ($Item.Admin -and -not (Test-IsAdmin)) {
        Write-Status WARN 'This action requires administrator rights.'
        Wait-Key
        return
    }
    try {
        & $Item.Action | Out-Host
    }
    catch {
        Write-Status FAIL $_.Exception.Message
        Write-Log -Level ERROR -Message "$($Item.Label): $($_.Exception.Message)"
    }
    if (-not $Item.Submenu) { Wait-Key }
}

# Data-driven menu. Each item: Key, Label, Action, and optionally Section, Hint (short
# description), Admin (rights required), Danger (destroys data) and Submenu (no pause on return).
function Show-Menu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable[]]$Items,
        [string]$ExitLabel = 'Back',
        [scriptblock]$Header
    )
    $script:MenuPath.Add($Title)
    try {
        $labelWidth = ($Items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
        while ($true) {
            $isAdmin = Test-IsAdmin
            Clear-Screen
            Write-Title ($script:MenuPath -join ' > ')
            if ($Header) { & $Header }
            $section = $null
            foreach ($item in $Items) {
                if ($item.Section -and $item.Section -ne $section) {
                    $section = $item.Section
                    Write-Section $section
                }
                $locked = $item.Admin -and -not $isAdmin
                $color = if ($locked) { 'DarkGray' } elseif ($item.Danger) { 'Yellow' } else { 'Gray' }
                Write-Host ('   [{0}] {1}' -f $item.Key, $item.Label.PadRight($labelWidth)) -ForegroundColor $color -NoNewline
                $note = @($(if ($locked) { '(admin required)' }), $item.Hint) | Where-Object { $_ }
                Write-Host ('  ' + ($note -join ' ')) -ForegroundColor DarkGray
            }
            Write-Host ''
            Write-Separator
            Write-Host "   [Q] $ExitLabel"
            Write-Host ''
            $choice = Read-Text 'Choice'
            if ($choice -ieq 'Q') { return }
            if (-not $choice) { continue }
            $selected = $Items | Where-Object { $_.Key -ieq $choice } | Select-Object -First 1
            if (-not $selected) {
                Write-Status WARN "Invalid option '$choice'."
                Start-Sleep -Seconds 1
                continue
            }
            Invoke-MenuAction -Item $selected
        }
    }
    finally { $script:MenuPath.RemoveAt($script:MenuPath.Count - 1) }
}

function Resolve-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) { $full = $full.TrimEnd('\', '/') }
    return $full
}

# True if $Child is $Parent or is located inside it.
function Test-PathInside {
    param([Parameter(Mandatory)][string]$Child, [Parameter(Mandatory)][string]$Parent)
    $separators = '\', '/'
    $childNorm = $Child.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    $parentNorm = $Parent.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    return $childNorm.StartsWith($parentNorm, [StringComparison]::OrdinalIgnoreCase)
}

# Some .NET configurations reject the \\?\ prefix or drop it from FullName, and either would make
# every path fail. So it is tested once on a real folder and only used when it fully works.
function Test-LongPathSupport {
    if ($null -eq $script:LongPathSupported) {
        try {
            $probe = [IO.DirectoryInfo]::new('\\?\' + $env:SystemRoot + '\')
            $child = $probe.GetFileSystemInfos() | Select-Object -First 1
            $script:LongPathSupported = $probe.FullName.StartsWith('\\?\') -and $child.FullName.StartsWith('\\?\')
        }
        catch { $script:LongPathSupported = $false }
        if (-not $script:LongPathSupported) { Write-Log -Level WARN -Message 'The \\?\ prefix is not usable here: paths over 260 characters will be reported as errors.' }
    }
    return $script:LongPathSupported
}

# \\?\ prefix to get past the 260-character limit in .NET calls, when it is available.
function ConvertTo-LongPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-IsWindows) -or $Path.StartsWith('\\?\')) { return $Path }
    if (-not (Test-LongPathSupport)) { return $Path }
    if ($Path.StartsWith('\\')) { return '\\?\UNC\' + $Path.Substring(2) }
    return '\\?\' + $Path
}

function Test-LinkItem {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)
    # OneDrive folders are also reparse points: only real links are skipped.
    try { return ($Item.LinkType -in 'Junction', 'SymbolicLink') }
    catch { return $true }
}

# Iterative traversal that tolerates access errors: returns Files, Dirs, Links and Errors.
# Paths are relative to $Root; links are never followed, which prevents loops.
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

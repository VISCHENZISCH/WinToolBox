# Tests Pester 5. La sauvegarde utilise le vrai robocopy : ces tests se lancent sous Windows.
# Les fonctions sans dependance systeme s'executent aussi sur d'autres plateformes.

BeforeAll {
    $src = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..', 'src'))
    . ([IO.Path]::Combine($src, 'lib', 'Common.ps1'))
    foreach ($module in 'Backup', 'Disk', 'Maintenance', 'Network', 'Users', 'Security') {
        . ([IO.Path]::Combine($src, 'modules', "$module.ps1"))
    }

    function Write-TestFile {
        param([string]$Root, [string]$Relative, [string]$Content)
        $path = [IO.Path]::Combine($Root, $Relative)
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
        [IO.File]::WriteAllText($path, $Content)
        return $path
    }
}

Describe 'Format-Bytes' {
    It 'choisit la bonne unite' {
        Format-Bytes 512 | Should -Be '512 o'
        (Format-Bytes 1536) -replace ',', '.' | Should -Be '1.5 Ko'
        (Format-Bytes (2 * 1GB)) -replace ',', '.' | Should -Be '2.0 Go'
    }
}

Describe 'ConvertTo-BytesFromGb' {
    It 'accepte la virgule et le point' {
        ConvertTo-BytesFromGb '1,5' | Should -Be ([long](1.5 * 1GB))
        ConvertTo-BytesFromGb '2.0' | Should -Be ([long](2 * 1GB))
    }
    It 'refuse les valeurs invalides' {
        ConvertTo-BytesFromGb 'abc' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '-3' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '' | Should -BeNullOrEmpty
    }
}

Describe 'Test-PathInside' {
    It 'detecte une imbrication sans confondre les prefixes' {
        Test-PathInside -Child 'C:\Data\Sub' -Parent 'C:\Data' | Should -BeTrue
        Test-PathInside -Child 'C:\Data' -Parent 'C:\Data' | Should -BeTrue
        Test-PathInside -Child 'C:\Database' -Parent 'C:\Data' | Should -BeFalse
    }
}

Describe 'Confirmations' {
    It 'Confirm-Phrase exige la phrase exacte' {
        Mock Read-Host { 'formater e' }
        Confirm-Phrase -Message 'x' -Phrase 'FORMATER E' | Should -BeFalse
        Mock Read-Host { 'FORMATER E' }
        Confirm-Phrase -Message 'x' -Phrase 'FORMATER E' | Should -BeTrue
    }
    It 'Confirm-Action refuse tout sauf O' {
        Mock Read-Host { '' }
        Confirm-Action 'x' | Should -BeFalse
        Mock Read-Host { 'o' }
        Confirm-Action 'x' | Should -BeTrue
    }
}

Describe 'Protection des partitions' {
    It 'protege les partitions de demarrage, systeme et le lecteur Windows' {
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $true; IsSystem = $false; DriveLetter = 'D' }) -SystemDrive 'C:' | Should -BeTrue
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $true; DriveLetter = [char]0 }) -SystemDrive 'C:' | Should -BeTrue
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $false; DriveLetter = 'C' }) -SystemDrive 'C:' | Should -BeTrue
    }
    It 'autorise une partition de donnees' {
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $false; DriveLetter = 'E' }) -SystemDrive 'C:' | Should -BeFalse
    }
    It 'normalise les lettres de lecteur' {
        ConvertTo-DriveLetter 'e:' | Should -Be 'E'
        ConvertTo-DriveLetter 'E:\' | Should -Be 'E'
        ConvertTo-DriveLetter 'EF' | Should -BeNullOrEmpty
    }
}

Describe 'Ports sensibles' {
    It 'compare le numero exact' {
        Get-SensitivePortLabel -Port 445 | Should -Be 'SMB'
        Get-SensitivePortLabel -Port 4450 | Should -BeNullOrEmpty
        Get-SensitivePortLabel -Port 2179 | Should -BeNullOrEmpty
    }
}

Describe 'Noms de comptes' {
    It 'valide les noms' {
        Test-LocalUserName 'alice' | Should -BeTrue
        Test-LocalUserName 'a"b' | Should -BeFalse
        Test-LocalUserName 'fin.' | Should -BeFalse
        Test-LocalUserName ('x' * 21) | Should -BeFalse
        Test-LocalUserName '' | Should -BeFalse
    }
}

Describe 'Audit de securite' {
    It 'ne transforme jamais une verification en echec en succes' {
        $checks = @(@{ Name = 'Casse'; Test = { throw 'indisponible' } }, @{ Name = 'Bon'; Test = { 'OK', 'fine' } })
        $findings = @(Invoke-SecurityAudit -Checks $checks)
        $findings[0].Status | Should -Be 'INFO'
        $findings[0].Detail | Should -Match 'Non verifie'
        $findings[1].Status | Should -Be 'OK'
    }
}

Describe 'Get-FileEntries' {
    It 'liste fichiers et dossiers et applique les exclusions' {
        $root = Join-Path $TestDrive 'scan'
        [void](Write-TestFile $root 'a.txt' 'a')
        [void](Write-TestFile $root ('sub' + [IO.Path]::DirectorySeparatorChar + 'b.txt') 'bb')
        [void](Write-TestFile $root ('skip' + [IO.Path]::DirectorySeparatorChar + 'c.txt') 'c')
        [void](Write-TestFile $root 'ignore.sys' 'x')
        $listing = Get-FileEntries -Root $root -ExcludeDirs 'skip' -ExcludeFiles 'ignore.sys'
        ($listing.Files | ForEach-Object { [IO.Path]::GetFileName($_.Rel) } | Sort-Object) -join ',' | Should -Be 'a.txt,b.txt'
        $listing.Dirs -join ',' | Should -Be 'sub'
        $listing.Errors.Count | Should -Be 0
    }
}

Describe 'Nettoyage' {
    It 'ne selectionne que les fichiers assez anciens et conformes au filtre' {
        $root = Join-Path $TestDrive 'clean'
        $old = Write-TestFile $root 'thumbcache_1.db' 'x'
        [IO.File]::SetLastWriteTimeUtc($old, [DateTime]::UtcNow.AddDays(-10))
        [void](Write-TestFile $root 'thumbcache_2.db' 'recent')
        $oldOther = Write-TestFile $root 'autre.txt' 'x'
        [IO.File]::SetLastWriteTimeUtc($oldOther, [DateTime]::UtcNow.AddDays(-10))
        $found = @(Get-CleanupCandidates -Root $root -MinAgeDays 1 -Filter 'thumbcache_*.db')
        $found.Count | Should -Be 1
        $found[0].Rel | Should -Be 'thumbcache_1.db'
    }
    It 'supprime les candidats, compte l''espace et retire les dossiers vides' {
        $root = Join-Path $TestDrive 'clean2'
        [void](Write-TestFile $root ('d' + [IO.Path]::DirectorySeparatorChar + 'a.tmp') '12345')
        $result = Remove-CleanupCandidates -Root $root -Candidates @(Get-CleanupCandidates -Root $root)
        $result.Freed | Should -Be 5
        $result.Locked | Should -Be 0
        [IO.Directory]::Exists((Join-Path $root 'd')) | Should -BeFalse
        [IO.Directory]::Exists($root) | Should -BeTrue
    }
}

Describe 'Choix du mode de sauvegarde' {
    It 'fait une complete sans historique' {
        Resolve-BackupMode -Requested 'Incremental' -Catalog @() | Should -Be 'Full'
    }
    It 'respecte le cycle FullEvery' {
        $chain = @([pscustomobject]@{ Type = 'Full' }, [pscustomobject]@{ Type = 'Incremental' })
        Resolve-BackupMode -Requested 'Incremental' -Catalog $chain -FullEvery 3 | Should -Be 'Incremental'
        $chain += [pscustomobject]@{ Type = 'Incremental' }
        Resolve-BackupMode -Requested 'Incremental' -Catalog $chain -FullEvery 3 | Should -Be 'Full'
    }
}

Describe 'Manifeste' {
    It 'relit exactement ce qu''il ecrit, y compris espaces et accents' {
        $path = Join-Path $TestDrive 'files.tsv'
        $name = 'dossier ' + [char]0xE9 + '\fichier (1).txt'
        Write-Manifest -Path $path -Entries @([pscustomobject]@{ Size = 12; Ticks = 34; Hash = 'AB'; Store = 'id'; Rel = $name })
        $read = @(Read-Manifest -Path $path)
        $read.Count | Should -Be 1
        $read[0].Rel | Should -Be $name
        $read[0].Size | Should -Be 12
    }
}

Describe 'Sauvegarde et restauration' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeEach {
        $script:Source = Join-Path $TestDrive ('src-' + [guid]::NewGuid().ToString('N'))
        $script:Repo = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N'))
        [void](Write-TestFile $script:Source 'keep.txt' 'keep')
        [void](Write-TestFile $script:Source 'change.txt' 'v1')
        [void](Write-TestFile $script:Source 'sub\delete me.txt' 'delete')
        [void][IO.Directory]::CreateDirectory((Join-Path $script:Source 'vide'))
    }

    It 'restaure une version incrementale : fichier modifie, supprime et dossier vide' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $first.Status | Should -Be 'Complete'

        Write-TestFile $script:Source 'change.txt' 'version deux' | Out-Null
        Remove-Item (Join-Path $script:Source 'sub\delete me.txt')
        Write-TestFile $script:Source 'new.txt' 'new' | Out-Null
        $second = New-Backup -Source $script:Source -Destination $script:Repo -Mode Incremental
        $second.Chain | Should -Be 'Incremental'
        $second.CopiedFiles | Should -Be 2

        $target = Join-Path $TestDrive 'restored'
        $result = Restore-Backup -BackupPath ([IO.Path]::Combine($second.SetPath, $second.Id)) -Target $target
        $result.Ok | Should -BeTrue
        [IO.File]::ReadAllText((Join-Path $target 'change.txt')) | Should -Be 'version deux'
        [IO.File]::ReadAllText((Join-Path $target 'keep.txt')) | Should -Be 'keep'
        [IO.File]::Exists((Join-Path $target 'new.txt')) | Should -BeTrue
        [IO.File]::Exists((Join-Path $target 'sub\delete me.txt')) | Should -BeFalse
        [IO.Directory]::Exists((Join-Path $target 'vide')) | Should -BeTrue
    }

    It 'peut encore restaurer la premiere version' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        Write-TestFile $script:Source 'change.txt' 'version deux' | Out-Null
        [void](New-Backup -Source $script:Source -Destination $script:Repo)
        $target = Join-Path $TestDrive 'restored-v1'
        [void](Restore-Backup -BackupPath ([IO.Path]::Combine($first.SetPath, $first.Id)) -Target $target)
        [IO.File]::ReadAllText((Join-Path $target 'change.txt')) | Should -Be 'v1'
    }

    It 'ne cree pas de version quand rien ne change' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo
        $second = New-Backup -Source $script:Source -Destination $script:Repo
        $second.Status | Should -Be 'NoChange'
        @(Get-BackupCatalog -SetPath $first.SetPath).Count | Should -Be 1
    }

    It 'detecte une copie corrompue ou manquante' {
        $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
        (Test-Backup -BackupPath $path).Ok | Should -BeTrue
        [IO.File]::WriteAllText([IO.Path]::Combine($path, 'data', 'keep.txt'), 'altere')
        Remove-Item ([IO.Path]::Combine($path, 'data', 'change.txt'))
        $check = Test-Backup -BackupPath $path
        $check.Ok | Should -BeFalse
        $check.Corrupt | Should -Contain 'keep.txt'
        $check.Missing | Should -Contain 'change.txt'
    }

    It 'refuse une destination dans la source' {
        { New-Backup -Source $script:Source -Destination (Join-Path $script:Source 'repo') } | Should -Throw
    }

    It 'ignore une sauvegarde interrompue' {
        $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $stale = [IO.Path]::Combine($backup.SetPath, '.tmp-20200101-000000000-full')
        [void][IO.Directory]::CreateDirectory($stale)
        @(Get-BackupCatalog -SetPath $backup.SetPath).Count | Should -Be 1
        [void](New-Backup -Source $script:Source -Destination $script:Repo -Mode Full)
        [IO.Directory]::Exists($stale) | Should -BeFalse
    }

    It 'la retention conserve les chaines recentes et leurs dependances' {
        $a = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        Write-TestFile $script:Source 'change.txt' 'v2' | Out-Null
        [void](New-Backup -Source $script:Source -Destination $script:Repo)
        [void](New-Backup -Source $script:Source -Destination $script:Repo -Mode Full)
        Write-TestFile $script:Source 'change.txt' 'v3' | Out-Null
        $last = New-Backup -Source $script:Source -Destination $script:Repo -KeepChains 1
        @(Get-BackupCatalog -SetPath $a.SetPath).Count | Should -Be 2
        (Test-Backup -BackupPath ([IO.Path]::Combine($last.SetPath, $last.Id))).Ok | Should -BeTrue
    }
}

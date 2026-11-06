# Pester 5 tests. The backup uses the real robocopy, so these tests run on Windows.
# Functions with no system dependency also run on other platforms.

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
    It 'picks the right unit' {
        Format-Bytes 512 | Should -Be '512 B'
        (Format-Bytes 1536) -replace ',', '.' | Should -Be '1.5 KB'
        (Format-Bytes (2 * 1GB)) -replace ',', '.' | Should -Be '2.0 GB'
    }
}

Describe 'ConvertTo-BytesFromGb' {
    It 'accepts both comma and dot' {
        ConvertTo-BytesFromGb '1,5' | Should -Be ([long](1.5 * 1GB))
        ConvertTo-BytesFromGb '2.0' | Should -Be ([long](2 * 1GB))
    }
    It 'rejects invalid values' {
        ConvertTo-BytesFromGb 'abc' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '-3' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '' | Should -BeNullOrEmpty
    }
}

Describe 'Test-PathInside' {
    It 'detects nesting without confusing prefixes' {
        Test-PathInside -Child 'C:\Data\Sub' -Parent 'C:\Data' | Should -BeTrue
        Test-PathInside -Child 'C:\Data' -Parent 'C:\Data' | Should -BeTrue
        Test-PathInside -Child 'C:\Database' -Parent 'C:\Data' | Should -BeFalse
    }
}

Describe 'Confirmation prompts' {
    It 'Confirm-Phrase requires the exact phrase' {
        Mock Read-Host { 'format e' }
        Confirm-Phrase -Message 'x' -Phrase 'FORMAT E' | Should -BeFalse
        Mock Read-Host { 'FORMAT E' }
        Confirm-Phrase -Message 'x' -Phrase 'FORMAT E' | Should -BeTrue
    }
    It 'Confirm-Action rejects everything except Y' {
        Mock Read-Host { '' }
        Confirm-Action 'x' | Should -BeFalse
        Mock Read-Host { 'y' }
        Confirm-Action 'x' | Should -BeTrue
    }
}

Describe 'Partition protection' {
    It 'protects boot and system partitions and the Windows drive' {
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $true; IsSystem = $false; DriveLetter = 'D' }) -SystemDrive 'C:' | Should -BeTrue
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $true; DriveLetter = [char]0 }) -SystemDrive 'C:' | Should -BeTrue
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $false; DriveLetter = 'C' }) -SystemDrive 'C:' | Should -BeTrue
    }
    It 'allows a data partition' {
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $false; DriveLetter = 'E' }) -SystemDrive 'C:' | Should -BeFalse
    }
    It 'normalizes drive letters' {
        ConvertTo-DriveLetter 'e:' | Should -Be 'E'
        ConvertTo-DriveLetter 'E:\' | Should -Be 'E'
        ConvertTo-DriveLetter 'EF' | Should -BeNullOrEmpty
    }
}

Describe 'Sensitive ports' {
    It 'matches the exact number' {
        Get-SensitivePortLabel -Port 445 | Should -Be 'SMB'
        Get-SensitivePortLabel -Port 4450 | Should -BeNullOrEmpty
        Get-SensitivePortLabel -Port 2179 | Should -BeNullOrEmpty
    }
}

Describe 'Account names' {
    It 'validates names' {
        Test-LocalUserName 'alice' | Should -BeTrue
        Test-LocalUserName 'a"b' | Should -BeFalse
        Test-LocalUserName 'end.' | Should -BeFalse
        Test-LocalUserName ('x' * 21) | Should -BeFalse
        Test-LocalUserName '' | Should -BeFalse
    }
}

Describe 'Security audit' {
    It 'never turns a failed check into a success' {
        $checks = @(@{ Name = 'Broken'; Test = { throw 'unavailable' } }, @{ Name = 'Good'; Test = { 'OK', 'fine' } })
        $findings = @(Invoke-SecurityAudit -Checks $checks)
        $findings[0].Status | Should -Be 'INFO'
        $findings[0].Detail | Should -Match 'Not checked'
        $findings[1].Status | Should -Be 'OK'
    }
}

Describe 'Get-FileEntries' {
    It 'lists files and folders and applies exclusions' {
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

Describe 'Cleanup' {
    It 'selects only files that are old enough and match the filter' {
        $root = Join-Path $TestDrive 'clean'
        $old = Write-TestFile $root 'thumbcache_1.db' 'x'
        [IO.File]::SetLastWriteTimeUtc($old, [DateTime]::UtcNow.AddDays(-10))
        [void](Write-TestFile $root 'thumbcache_2.db' 'recent')
        $oldOther = Write-TestFile $root 'other.txt' 'x'
        [IO.File]::SetLastWriteTimeUtc($oldOther, [DateTime]::UtcNow.AddDays(-10))
        $found = @(Get-CleanupCandidates -Root $root -MinAgeDays 1 -Filter 'thumbcache_*.db')
        $found.Count | Should -Be 1
        $found[0].Rel | Should -Be 'thumbcache_1.db'
    }
    It 'deletes candidates, counts the space and removes empty folders' {
        $root = Join-Path $TestDrive 'clean2'
        [void](Write-TestFile $root ('d' + [IO.Path]::DirectorySeparatorChar + 'a.tmp') '12345')
        $result = Remove-CleanupCandidates -Root $root -Candidates @(Get-CleanupCandidates -Root $root)
        $result.Freed | Should -Be 5
        $result.Locked | Should -Be 0
        [IO.Directory]::Exists((Join-Path $root 'd')) | Should -BeFalse
        [IO.Directory]::Exists($root) | Should -BeTrue
    }
}

Describe 'Backup mode selection' {
    It 'runs a full backup when there is no history' {
        Resolve-BackupMode -Requested 'Incremental' -Catalog @() | Should -Be 'Full'
    }
    It 'honors the FullEvery cycle' {
        $chain = @([pscustomobject]@{ Type = 'Full' }, [pscustomobject]@{ Type = 'Incremental' })
        Resolve-BackupMode -Requested 'Incremental' -Catalog $chain -FullEvery 3 | Should -Be 'Incremental'
        $chain += [pscustomobject]@{ Type = 'Incremental' }
        Resolve-BackupMode -Requested 'Incremental' -Catalog $chain -FullEvery 3 | Should -Be 'Full'
    }
}

Describe 'Manifest' {
    It 'reads back exactly what it writes, including spaces and non-ASCII characters' {
        $path = Join-Path $TestDrive 'files.tsv'
        $name = 'folder ' + [char]0xE9 + '\file (1).txt'
        Write-Manifest -Path $path -Entries @([pscustomobject]@{ Size = 12; Ticks = 34; Hash = 'AB'; Store = 'id'; Rel = $name })
        $read = @(Read-Manifest -Path $path)
        $read.Count | Should -Be 1
        $read[0].Rel | Should -Be $name
        $read[0].Size | Should -Be 12
    }
}

Describe 'Backup and restore' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeEach {
        $script:Source = Join-Path $TestDrive ('src-' + [guid]::NewGuid().ToString('N'))
        $script:Repo = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N'))
        [void](Write-TestFile $script:Source 'keep.txt' 'keep')
        [void](Write-TestFile $script:Source 'change.txt' 'v1')
        [void](Write-TestFile $script:Source 'sub\delete me.txt' 'delete')
        [void][IO.Directory]::CreateDirectory((Join-Path $script:Source 'empty'))
    }

    It 'restores an incremental version: changed file, deleted file and empty folder' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $first.Status | Should -Be 'Complete'

        Write-TestFile $script:Source 'change.txt' 'version two' | Out-Null
        Remove-Item (Join-Path $script:Source 'sub\delete me.txt')
        Write-TestFile $script:Source 'new.txt' 'new' | Out-Null
        $second = New-Backup -Source $script:Source -Destination $script:Repo -Mode Incremental
        $second.Chain | Should -Be 'Incremental'
        $second.CopiedFiles | Should -Be 2

        $target = Join-Path $TestDrive 'restored'
        $result = Restore-Backup -BackupPath ([IO.Path]::Combine($second.SetPath, $second.Id)) -Target $target
        $result.Ok | Should -BeTrue
        [IO.File]::ReadAllText((Join-Path $target 'change.txt')) | Should -Be 'version two'
        [IO.File]::ReadAllText((Join-Path $target 'keep.txt')) | Should -Be 'keep'
        [IO.File]::Exists((Join-Path $target 'new.txt')) | Should -BeTrue
        [IO.File]::Exists((Join-Path $target 'sub\delete me.txt')) | Should -BeFalse
        [IO.Directory]::Exists((Join-Path $target 'empty')) | Should -BeTrue
    }

    It 'can still restore the first version' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        Write-TestFile $script:Source 'change.txt' 'version two' | Out-Null
        [void](New-Backup -Source $script:Source -Destination $script:Repo)
        $target = Join-Path $TestDrive 'restored-v1'
        [void](Restore-Backup -BackupPath ([IO.Path]::Combine($first.SetPath, $first.Id)) -Target $target)
        [IO.File]::ReadAllText((Join-Path $target 'change.txt')) | Should -Be 'v1'
    }

    It 'does not create a version when nothing changes' {
        $first = New-Backup -Source $script:Source -Destination $script:Repo
        $second = New-Backup -Source $script:Source -Destination $script:Repo
        $second.Status | Should -Be 'NoChange'
        @(Get-BackupCatalog -SetPath $first.SetPath).Count | Should -Be 1
    }

    It 'detects a corrupt or missing copy' {
        $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
        (Test-Backup -BackupPath $path).Ok | Should -BeTrue
        [IO.File]::WriteAllText([IO.Path]::Combine($path, 'data', 'keep.txt'), 'tampered')
        Remove-Item ([IO.Path]::Combine($path, 'data', 'change.txt'))
        $check = Test-Backup -BackupPath $path
        $check.Ok | Should -BeFalse
        $check.Corrupt | Should -Contain 'keep.txt'
        $check.Missing | Should -Contain 'change.txt'
    }

    It 'rejects a destination inside the source' {
        { New-Backup -Source $script:Source -Destination (Join-Path $script:Source 'repo') } | Should -Throw
    }

    It 'ignores an interrupted backup' {
        $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
        $stale = [IO.Path]::Combine($backup.SetPath, '.tmp-20200101-000000000-full')
        [void][IO.Directory]::CreateDirectory($stale)
        @(Get-BackupCatalog -SetPath $backup.SetPath).Count | Should -Be 1
        [void](New-Backup -Source $script:Source -Destination $script:Repo -Mode Full)
        [IO.Directory]::Exists($stale) | Should -BeFalse
    }

    It 'retention keeps recent chains and their dependencies' {
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

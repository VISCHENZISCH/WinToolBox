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
    It 'rejects an ambiguous size instead of guessing' {
        ConvertTo-BytesFromGb '1,000' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '1.000' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '1,000,000' | Should -BeNullOrEmpty
        ConvertTo-BytesFromGb '1000' | Should -Be ([long](1000 * 1GB))
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

Describe 'Display' {
    It 'separates the header with stars and shows readable values' {
        $lines = @(Format-TextTable -Rows @([pscustomobject]@{ Name = 'alpha'; Active = $true; Letter = [char]0 }) -Width 80)
        $lines.Count | Should -Be 3
        $lines[0] | Should -Match '^Name\s+Active\s+Letter$'
        $lines[1] | Should -Match '^\*{5}  \*{6}  \*{6}$'
        $lines[2] | Should -Match '^alpha\s+Yes$'
    }
    It 'cuts the widest column to fit the width' {
        $lines = @(Format-TextTable -Rows @([pscustomobject]@{ Name = 'short'; Command = 'x' * 200 }) -Width 40)
        $lines | ForEach-Object { $_.Length | Should -BeLessOrEqual 40 }
        $lines[2] | Should -Match '^short  x+\.\.\.$'
    }
    It 'returns nothing for no rows' {
        @(Format-TextTable -Rows @()).Count | Should -Be 0
    }
    It 'draws a menu, shows the path of nested menus and restores it on exit' {
        Mock Clear-Screen { }
        Mock Read-Host { 'q' }
        $script:seen = $null
        Mock Write-Title { $script:seen = $Text }
        Show-Menu -Title 'Main' -Items @(@{ Section = 'S'; Key = '1'; Label = 'One'; Hint = 'first'; Danger = $true; Action = { } })
        $script:seen | Should -Be 'Main'
        $script:MenuPath.Count | Should -Be 0
    }
    It 'names the menu path above the result of an action' {
        Mock Clear-Screen { }
        Mock Read-Host { '' }
        $script:seen = $null
        Mock Write-Title { $script:seen = $Text }
        $script:MenuPath.Add('Main')
        try { Invoke-MenuAction -Item @{ Key = '1'; Label = 'One'; Action = { } } }
        finally { $script:MenuPath.Clear() }
        $script:seen | Should -Be 'Main > One'
    }
    It 'clears the screen only through Clear-Screen, because Clear-Host can leave old text behind' {
        $src = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..', 'src'))
        $uses = @(Get-ChildItem -Path $src -Recurse -Filter '*.ps1' | Select-String -Pattern '^\s*(catch \{ )?Clear-Host\b')
        $uses.Count | Should -Be 1
        $uses[0].Filename | Should -Be 'Common.ps1'
        $uses[0].Line | Should -Match 'catch'
    }
    It 'no longer uses Format-Table, whose rule is made of dashes' {
        $src = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..', 'src'))
        @(Get-ChildItem -Path $src -Recurse -Filter '*.ps1' | Select-String -SimpleMatch 'Format-Table').Count | Should -Be 0
    }
}

Describe 'Long paths' {
    It 'adds the prefix only when it works' {
        Mock Test-IsWindows { $true }
        Mock Test-LongPathSupport { $true }
        ConvertTo-LongPath 'C:\data' | Should -Be '\\?\C:\data'
        ConvertTo-LongPath '\\server\share' | Should -Be '\\?\UNC\server\share'
        Mock Test-LongPathSupport { $false }
        ConvertTo-LongPath 'C:\data' | Should -Be 'C:\data'
    }
}

Describe 'Listening ports' {
    It 'keeps the exposed listener when the same port also listens on loopback' {
        $rows = @(Get-ListeningPortRows -Connections @(
                [pscustomobject]@{ LocalPort = 445; LocalAddress = '127.0.0.1'; OwningProcess = 4 }
                [pscustomobject]@{ LocalPort = 445; LocalAddress = '0.0.0.0'; OwningProcess = 4 }
            ) -Processes @{ 4 = 'System' })
        $rows.Count | Should -Be 2
        @($rows | Where-Object { $_.Alert -eq 'SENSITIVE: SMB' }).Count | Should -Be 1
        ($rows | Where-Object { $_.LocalAddress -eq '127.0.0.1' }).Alert | Should -BeNullOrEmpty
    }
}

Describe 'Recycle Bin' {
    BeforeAll {
        if (-not (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue)) {
            function global:Clear-RecycleBin { param([switch]$Force) }
        }
    }
    It 'reports what was really freed when emptying fails' {
        Mock Clear-RecycleBin { }
        Mock Get-RecycleBinSize { 30 }
        $result = Invoke-RecycleBinClear -SizeBefore 100
        $result.Freed | Should -Be 70
        $result.Left | Should -Be 30
    }
}

Describe 'Scheduled task results' {
    It 'flags only the results that are problems' {
        Test-TaskResultProblem -Code 1 | Should -BeTrue
        Test-TaskResultProblem -Code 2 | Should -BeTrue
        Test-TaskResultProblem -Code 2147942402 | Should -BeTrue
        Test-TaskResultProblem -Code 0 | Should -BeFalse
        Test-TaskResultProblem -Code 267009 | Should -BeFalse
        Test-TaskResultProblem -Code 267011 | Should -BeFalse
    }
    It 'describes the results' {
        Format-TaskResult -Code 267011 | Should -Be 'not run yet'
        Format-TaskResult -Code 5 | Should -Be 'ended with code 5'
    }
    It 'does not block the menu when tasks cannot be read' {
        { @(Get-ScheduledBackupProblems) } | Should -Not -Throw
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

# robocopy is replaced by plain copies here, so these safety tests also run outside Windows.
Describe 'Backup safety' {
    BeforeAll {
        # Pester 6 no longer falls through to the real command when a -ParameterFilter does not match.
        $script:RealSha256 = ${function:Get-FileSha256}
        function Copy-StubTree {
            param([string]$From, [string]$To, [switch]$Corrupt)
            foreach ($file in (Get-FileEntries -Root $From).Files) {
                $target = [IO.Path]::Combine($To, $file.Rel)
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.File]::Copy([IO.Path]::Combine($From, $file.Rel), $target, $true)
                if ($Corrupt) {
                    $bytes = [IO.File]::ReadAllBytes($target)
                    $bytes[0] = $bytes[0] -bxor 0xFF
                    [IO.File]::WriteAllBytes($target, $bytes)
                }
            }
        }
        function New-EmptyListing {
            param([string[]]$Errors = @())
            $errorList = New-Object 'System.Collections.Generic.List[string]'
            foreach ($item in $Errors) { $errorList.Add($item) }
            return [pscustomobject]@{
                Files  = New-Object 'System.Collections.Generic.List[object]'
                Dirs   = New-Object 'System.Collections.Generic.List[string]'
                Links  = New-Object 'System.Collections.Generic.List[string]'
                Errors = $errorList
            }
        }
    }

    BeforeEach {
        $script:Source = Join-Path $TestDrive ('src-' + [guid]::NewGuid().ToString('N'))
        $script:Repo = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N'))
        [void](Write-TestFile $script:Source 'a.txt' 'important-a')
        [void](Write-TestFile $script:Source 'b.txt' 'important-b')
        Mock Copy-Tree { Copy-StubTree -From $From -To $To; 0 }
        Mock Copy-FileGroup {
            [void][IO.Directory]::CreateDirectory($ToDir)
            foreach ($name in $Names) { [IO.File]::Copy([IO.Path]::Combine($FromDir, $name), [IO.Path]::Combine($ToDir, $name), $true) }
            0
        }
    }

    Context 'Copy integrity' {
        It 'rejects a copy that differs from the source even when the size matches' {
            Mock Copy-Tree { Copy-StubTree -From $From -To $To -Corrupt; 0 }
            $result = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $result.Status | Should -Be 'Partial'
            $result.Failed | Should -Be 2
            $result.TotalFiles | Should -Be 0
        }
        It 'keeps and reports a copy whose source cannot be reopened' {
            Mock Get-FileSha256 { if ($Path -notlike '*repo-*') { throw 'access denied' }; & $script:RealSha256 -Path $Path }
            $result = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $result.Status | Should -Be 'Complete'
            $result.TotalFiles | Should -Be 2
            $result.Unverified | Should -Be 2
            [IO.File]::ReadAllText([IO.Path]::Combine($result.SetPath, $result.Id, 'errors.txt')) | Should -Match 'UNVERIFIED'
        }
    }

    Context 'Restore' {
        It 'never overwrites a target file from a damaged backup file' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
            [IO.File]::WriteAllText([IO.Path]::Combine($path, 'data', 'a.txt'), 'CORRUPTED!!')
            $target = Join-Path $TestDrive ('target-' + [guid]::NewGuid().ToString('N'))
            [void](Write-TestFile $target 'a.txt' 'good-local-copy')
            $result = Restore-Backup -BackupPath $path -Target $target
            $result.Ok | Should -BeFalse
            $result.Failed | Should -Contain 'a.txt'
            $result.Restored | Should -Be 1
            [IO.File]::ReadAllText((Join-Path $target 'a.txt')) | Should -Be 'good-local-copy'
            [IO.File]::ReadAllText((Join-Path $target 'b.txt')) | Should -Be 'important-b'
        }
        It 'recognizes unsafe manifest entries' -ForEach @(
            @{ Rel = '..\evil.txt' }, @{ Rel = '../evil.txt' }, @{ Rel = 'a\..\..\evil.txt' }, @{ Rel = '.. \evil.txt' }
            @{ Rel = 'C:\evil.txt' }, @{ Rel = 'C:evil.txt' }, @{ Rel = '\evil.txt' }, @{ Rel = '/evil.txt' }, @{ Rel = 'a.txt:stream' }, @{ Rel = '' }
        ) {
            Test-ManifestEntrySafe -Entry ([pscustomobject]@{ Store = '20260101-000000000-full'; Rel = $Rel }) | Should -BeFalse
        }
        It 'accepts normal manifest entries and rejects an unsafe store' {
            Test-ManifestEntrySafe -Entry ([pscustomobject]@{ Store = '20260101-000000000-incr'; Rel = 'sub\my file..txt' }) | Should -BeTrue
            Test-ManifestEntrySafe -Entry ([pscustomobject]@{ Store = '..\..\other'; Rel = 'a.txt' }) | Should -BeFalse
        }
        It 'refuses a manifest that leaves the target and writes nothing' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
            [IO.File]::WriteAllLines([IO.Path]::Combine($path, 'files.tsv'), [string[]]@("1`t0`tAB`t$($backup.Id)`t../evil.txt"))
            $jail = Join-Path $TestDrive ('jail-' + [guid]::NewGuid().ToString('N'))
            { Restore-Backup -BackupPath $path -Target (Join-Path $jail 'target') } | Should -Throw '*Unsafe entry*'
            { Test-Backup -BackupPath $path } | Should -Throw '*Unsafe entry*'
            [IO.Directory]::Exists($jail) | Should -BeFalse
        }
    }

    Context 'Verification' {
        It 'detects a truncated manifest' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
            $manifest = [IO.Path]::Combine($path, 'files.tsv')
            [IO.File]::WriteAllLines($manifest, [string[]]@([IO.File]::ReadAllLines($manifest) | Select-Object -First 1))
            $check = Test-Backup -BackupPath $path
            $check.Ok | Should -BeFalse
            $check.CountOk | Should -BeFalse
            $check.Expected | Should -Be 2
        }
        It 'reports an unreadable stored file instead of aborting' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            Mock Get-FileSha256 { if ($Path -like '*a.txt') { throw 'read error' }; & $script:RealSha256 -Path $Path }
            $check = Test-Backup -BackupPath ([IO.Path]::Combine($backup.SetPath, $backup.Id))
            $check.Ok | Should -BeFalse
            @($check.Corrupt) | Should -Be @('a.txt')
            $check.Checked | Should -Be 2
        }
    }

    Context 'Retention' {
        It 'does not let a backup of an emptied source push out the last good one' {
            $good = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            Remove-Item (Join-Path $script:Source '*') -Force
            $empty = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full -KeepChains 1
            $empty.Shrunk | Should -BeTrue
            [IO.Directory]::Exists([IO.Path]::Combine($good.SetPath, $good.Id)) | Should -BeTrue
            # A later run with no alert still must not count the empty full backup.
            [void](New-Backup -Source $script:Source -Destination $script:Repo -Mode Full -KeepChains 1)
            [IO.Directory]::Exists([IO.Path]::Combine($good.SetPath, $good.Id)) | Should -BeTrue
        }
        It 'does not let a backup of an unreadable source push out the last good one' {
            $good = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            Mock Get-FileEntries { New-EmptyListing -Errors '.' }
            $result = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full -KeepChains 1
            $result.Status | Should -Be 'Partial'
            [IO.Directory]::Exists([IO.Path]::Combine($good.SetPath, $good.Id)) | Should -BeTrue
        }
        It 'skips purging on the run where the source shrinks' {
            for ($i = 0; $i -lt 10; $i++) { [void](Write-TestFile $script:Source "file$i.txt" 'x') }
            $good = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            for ($i = 0; $i -lt 10; $i++) { Remove-Item (Join-Path $script:Source "file$i.txt") }
            $result = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full -KeepChains 1
            $result.Shrunk | Should -BeTrue
            $result.PreviousFiles | Should -Be 12
            [IO.Directory]::Exists([IO.Path]::Combine($good.SetPath, $good.Id)) | Should -BeTrue
        }
        It 'counts only usable full backups, and still purges older ones' {
            $catalog = @(
                [pscustomobject]@{ Id = 'old'; Type = 'Full'; FileCount = 100; Failed = 0; Path = 'old' }
                [pscustomobject]@{ Id = 'old-incr'; Type = 'Incremental'; FileCount = 100; Failed = 0; Path = 'old-incr' }
                [pscustomobject]@{ Id = 'locked-file'; Type = 'Full'; FileCount = 99; Failed = 1; Path = 'locked-file' }
                [pscustomobject]@{ Id = 'mostly-failed'; Type = 'Full'; FileCount = 2; Failed = 98; Path = 'mostly-failed' }
                [pscustomobject]@{ Id = 'empty'; Type = 'Full'; FileCount = 0; Failed = 0; Path = 'empty' }
                [pscustomobject]@{ Id = 'shrunk'; Type = 'Full'; FileCount = 5; Failed = 0; Shrunk = $true; Path = 'shrunk' }
            )
            Mock Get-BackupCatalog { $catalog }
            Mock Remove-Tree { }
            Remove-OldBackupChains -SetPath 'x' -KeepChains 1 | Should -Be @('old', 'old-incr')
        }
        It 'flags a source that lost most of its files' {
            Test-SourceShrunk -Previous 100 -Current 49 | Should -BeTrue
            Test-SourceShrunk -Previous 100 -Current 50 | Should -BeFalse
            Test-SourceShrunk -Previous 2 -Current 0 | Should -BeTrue
            Test-SourceShrunk -Previous 2 -Current 1 | Should -BeFalse
            Test-SourceShrunk -Previous 0 -Current 0 | Should -BeFalse
        }
    }

    Context 'Change detection' {
        It 'reports an unreadable folder even when no file changed' {
            [void](New-Backup -Source $script:Source -Destination $script:Repo -Mode Full)
            $real = Get-FileEntries -Root $script:Source
            $real.Errors.Add('locked')
            Mock Get-FileEntries { $real }
            $result = New-Backup -Source $script:Source -Destination $script:Repo
            $result.Status | Should -Be 'Partial'
            $result.Unreadable | Should -Be 1
        }
        It 'creates a version when only an empty folder was added' {
            $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            [void][IO.Directory]::CreateDirectory((Join-Path $script:Source 'new-empty'))
            $second = New-Backup -Source $script:Source -Destination $script:Repo
            $second.Status | Should -Be 'Complete'
            $second.Id | Should -Not -Be $first.Id
            New-Backup -Source $script:Source -Destination $script:Repo | ForEach-Object { $_.Status | Should -Be 'NoChange' }
        }
    }

    Context 'Robocopy output' {
        BeforeAll {
            if (-not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) {
                function global:robocopy.exe { }
            }
        }
        It 'no longer asks robocopy for a log file of its own' {
            (Get-RobocopyCommonArgs) -join ' ' | Should -Not -Match 'LOG'
        }
        It 'sends robocopy errors to the normal log' {
            $script:LogFile = Join-Path $TestDrive 'tool.log'
            try {
                Mock robocopy.exe { $global:LASTEXITCODE = 9; 'ERROR 5 Access is denied.'; '' }
                Invoke-Robocopy -Arguments @('a', 'b') | Should -Be 9
                [IO.File]::ReadAllText($script:LogFile) | Should -Match 'robocopy returned 9: ERROR 5 Access is denied'
            }
            finally { $script:LogFile = $null }
        }
    }

    Context 'NTFS permissions' {
        BeforeEach {
            Mock Invoke-Icacls { if ($Arguments[1] -eq '/save') { [IO.File]::WriteAllText($Arguments[2], 'acl data') }; 0 }
        }
        It 'saves them with the version' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $backup.AclsSaved | Should -BeTrue
            [IO.File]::Exists([IO.Path]::Combine($backup.SetPath, $backup.Id, 'acls.txt')) | Should -BeTrue
            (Get-BackupCatalog -SetPath $backup.SetPath)[-1].AclsSaved | Should -BeTrue
        }
        It 'does not fail the backup when they cannot be saved' {
            Mock Invoke-Icacls { throw 'icacls not available' }
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $backup.Status | Should -Be 'Complete'
            $backup.AclsSaved | Should -BeFalse
        }
        It 'reapplies them only on request' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $path = [IO.Path]::Combine($backup.SetPath, $backup.Id)
            $plain = Restore-Backup -BackupPath $path -Target (Join-Path $TestDrive ('t-' + [guid]::NewGuid().ToString('N')))
            $plain.AclsRestored | Should -BeNullOrEmpty
            Should -Invoke Invoke-Icacls -Times 0 -ParameterFilter { $Arguments[1] -eq '/restore' }
            $withAcls = Restore-Backup -BackupPath $path -Target (Join-Path $TestDrive ('t-' + [guid]::NewGuid().ToString('N'))) -RestoreAcls
            $withAcls.AclsRestored | Should -BeTrue
            Should -Invoke Invoke-Icacls -Times 1 -ParameterFilter { $Arguments[1] -eq '/restore' }
        }
    }

    Context 'Restore filter' {
        It 'does not report success when the filter matches nothing' {
            $backup = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $target = Join-Path $TestDrive ('t-' + [guid]::NewGuid().ToString('N'))
            $result = Restore-Backup -BackupPath ([IO.Path]::Combine($backup.SetPath, $backup.Id)) -Target $target -Filter 'nope*'
            $result.Ok | Should -BeFalse
            $result.NoMatch | Should -BeTrue
            [IO.Directory]::Exists($target) | Should -BeFalse
        }
    }

    Context 'Damaged versions' {
        It 'skips a damaged meta.json and keeps backing up' {
            $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            [IO.File]::WriteAllText([IO.Path]::Combine($first.SetPath, $first.Id, 'meta.json'), '{ broken')
            @(Get-BackupCatalog -SetPath $first.SetPath -WarningAction SilentlyContinue).Count | Should -Be 0
            $next = New-Backup -Source $script:Source -Destination $script:Repo -WarningAction SilentlyContinue
            $next.Status | Should -Be 'Complete'
            $next.Chain | Should -Be 'Full'
            [IO.Directory]::Exists([IO.Path]::Combine($first.SetPath, $first.Id)) | Should -BeTrue
        }
        It 'starts a new full backup instead of extending a damaged manifest' {
            $first = New-Backup -Source $script:Source -Destination $script:Repo -Mode Full
            $manifest = [IO.Path]::Combine($first.SetPath, $first.Id, 'files.tsv')
            [IO.File]::WriteAllLines($manifest, [string[]]@([IO.File]::ReadAllLines($manifest) | Select-Object -First 1))
            (New-Backup -Source $script:Source -Destination $script:Repo).Chain | Should -Be 'Full'
        }
    }
}

# The Storage cmdlets only exist on Windows, where Mock replaces the real ones: no test touches a disk.
Describe 'Disk safety' {
    BeforeAll {
        if (-not (Get-Command Get-Disk -ErrorAction SilentlyContinue)) {
            function global:Get-Disk { param($Number) }
            function global:Get-Partition { param($DriveLetter) }
            function global:Get-Volume { param($DriveLetter) }
            function global:Initialize-Disk { param($Number, $PartitionStyle) }
            function global:New-Partition { param($DiskNumber, $AssignDriveLetter, $Size, $UseMaximumSize) }
            function global:Format-Volume { param([Parameter(ValueFromPipeline)]$InputObject, $DriveLetter, $FileSystem, $NewFileSystemLabel, [switch]$Confirm) }
            function global:Repair-Volume { param($DriveLetter, [switch]$Scan, [switch]$OfflineScanAndFix) }
        }
    }

    BeforeEach {
        Mock Initialize-Disk { }
        Mock New-Partition { [pscustomobject]@{ DriveLetter = 'E' } }
        Mock Format-Volume { }
        Mock Get-Disk { [pscustomobject]@{ Number = 3; FriendlyName = 'Old drive'; PartitionStyle = 'RAW'; OperationalStatus = 'Online'; IsReadOnly = $false; LargestFreeExtent = 0; Size = 1GB } }
    }

    It 'protects recovery, reserved, system-type and hidden partitions that have a letter' -ForEach @(
        @{ Fields = @{ Type = 'Recovery' } }, @{ Fields = @{ Type = 'Reserved' } }, @{ Fields = @{ Type = 'System' } }
        @{ Fields = @{ IsHidden = $true } }, @{ Fields = @{ MbrType = 39 } }
    ) {
        $partition = [pscustomobject](@{ IsBoot = $false; IsSystem = $false; DriveLetter = 'R' } + $Fields)
        Test-PartitionProtected -Partition $partition -SystemDrive 'C:' | Should -BeTrue
    }
    It 'still allows a basic data partition' {
        Test-PartitionProtected -Partition ([pscustomobject]@{ IsBoot = $false; IsSystem = $false; IsHidden = $false; Type = 'Basic'; MbrType = 7; DriveLetter = 'E' }) -SystemDrive 'C:' | Should -BeFalse
    }
    It 'refuses a recovery partition chosen in the menu' {
        Mock Read-Host { 'R' }
        Mock Get-Partition { [pscustomobject]@{ IsBoot = $false; IsSystem = $false; Type = 'Recovery'; DriveLetter = 'R' } }
        Read-PartitionSafe | Should -BeNullOrEmpty
    }
    It 'detects another Windows installation' {
        $root = Join-Path $TestDrive 'other-os'
        Test-PathHoldsWindows -Root $root | Should -BeFalse
        [void](Write-TestFile $root ([IO.Path]::Combine('Windows', 'System32', 'ntoskrnl.exe')) 'x')
        Test-PathHoldsWindows -Root $root | Should -BeTrue
    }
    It 'detects the drive that hosts the tool' {
        Test-DriveHostsTool -Letter 'D' -AppRoot 'd:\Tools\WinToolBox' | Should -BeTrue
        Test-DriveHostsTool -Letter 'E' -AppRoot 'D:\Tools\WinToolBox' | Should -BeFalse
        Test-DriveHostsTool -Letter 'E' -AppRoot '' | Should -BeFalse
    }
    It 'detects backups at both supported depths, and ignores other folders' {
        $direct = Join-Path $TestDrive 'direct'
        [void](Write-TestFile $direct ([IO.Path]::Combine('set', '20260101-000000000-full', 'meta.json')) '{}')
        Test-PathHoldsBackups -Root $direct | Should -BeTrue
        $nested = Join-Path $TestDrive 'nested'
        [void](Write-TestFile $nested ([IO.Path]::Combine('Backups', 'set', '20260101-000000000-incr', 'meta.json')) '{}')
        Test-PathHoldsBackups -Root $nested | Should -BeTrue
        $plain = Join-Path $TestDrive 'plain'
        [void](Write-TestFile $plain ([IO.Path]::Combine('Photos', '2026', 'holiday', 'meta.json')) '{}')
        Test-PathHoldsBackups -Root $plain | Should -BeFalse
    }
    It 'does not touch a RAW disk without the exact phrase' {
        Mock Read-Host { if ($Prompt -like '*Number*') { '1' } elseif ($Prompt -like '*Type exactly*') { 'y' } else { '' } }
        Invoke-PartitionCreate
        Should -Invoke Initialize-Disk -Times 0
        Should -Invoke New-Partition -Times 0
        Should -Invoke Format-Volume -Times 0
    }
    It 'initializes a RAW disk once the exact phrase is typed' {
        Mock Read-Host { if ($Prompt -like '*Number*') { '1' } elseif ($Prompt -like '*Type exactly*') { 'INITIALIZE 3' } else { '' } }
        Invoke-PartitionCreate
        Should -Invoke Initialize-Disk -Times 1
        Should -Invoke New-Partition -Times 1
    }
    It 'reports a failed scan without stopping the menu' {
        Mock Read-Host { 'C' }
        Mock Repair-Volume { throw 'A snapshot error occurred' }
        { Invoke-VolumeScan } | Should -Not -Throw
    }
    It 'refuses to take the Windows drive offline' {
        Mock Read-Host { 'Y' }
        Mock Repair-Volume { }
        Mock Get-Partition { [pscustomobject]@{ IsBoot = $true; IsSystem = $false; DriveLetter = 'C' } }
        Mock Read-Text { 'C' }
        Invoke-VolumeOfflineRepair
        Should -Invoke Repair-Volume -Times 0
    }
    It 'repairs a data volume offline only after confirmation' -ForEach @(
        @{ Answer = 'N'; Calls = 0 }, @{ Answer = 'Y'; Calls = 1 }
    ) {
        Mock Read-Host { if ($Prompt -like '*Y/N*') { $Answer } else { 'E' } }
        Mock Repair-Volume { 'NoErrorsFound' }
        Mock Write-PartitionSummary { }
        Mock Test-PathHoldsWindows { $false }
        Mock Get-Partition { [pscustomobject]@{ IsBoot = $false; IsSystem = $false; IsHidden = $false; Type = 'Basic'; MbrType = 7; DriveLetter = 'E' } }
        Invoke-VolumeOfflineRepair
        Should -Invoke Repair-Volume -Times $Calls -ParameterFilter { $OfflineScanAndFix -and $DriveLetter -eq 'E' }
    }
    It 'runs chkdsk only after confirmation, attached to the console' -ForEach @(
        @{ Answer = 'N'; Calls = 0 }, @{ Answer = 'Y'; Calls = 1 }
    ) {
        Mock Read-Host { if ($Prompt -like '*Y/N*') { $Answer } else { 'C' } }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Invoke-VolumeChkdsk
        Should -Invoke Start-Process -Times $Calls -ParameterFilter { $FilePath -eq 'chkdsk.exe' -and $NoNewWindow -and ($ArgumentList -join ' ') -eq 'C: /f' }
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

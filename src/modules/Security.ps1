# Read-only security audit and WinToolBox logs.

function New-Finding {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('OK', 'WARN', 'FAIL', 'INFO')][string]$Status,
        [string]$Detail = ''
    )
    return [pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail }
}

function Get-AuditChecks {
    return @(
        @{ Name = 'Firewall'; Test = {
                $disabled = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Name })
                if ($disabled.Count) { 'FAIL', "Disabled on: $($disabled -join ', ')" } else { 'OK', 'Enabled on all profiles' }
            }
        }
        @{ Name = 'Registered antivirus'; Test = {
                $products = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct | ForEach-Object { $_.displayName })
                if ($products.Count) { 'OK', ($products -join ', ') } else { 'FAIL', 'No antivirus registered' }
            }
        }
        @{ Name = 'Microsoft Defender'; Test = {
                $defender = Get-MpComputerStatus
                if (-not $defender.RealTimeProtectionEnabled) { 'WARN', 'Real-time protection disabled' }
                elseif ($defender.AntivirusSignatureAge -gt 7) { 'WARN', "Signatures are $($defender.AntivirusSignatureAge) days old" }
                else { 'OK', "Enabled, signatures $($defender.AntivirusSignatureAge) day(s) old" }
            }
        }
        @{ Name = 'User Account Control (UAC)'; Test = {
                $enabled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA
                if ($enabled -eq 1) { 'OK', 'Enabled' } else { 'FAIL', 'Disabled' }
            }
        }
        @{ Name = 'SMBv1'; Test = {
                if ((Get-SmbServerConfiguration).EnableSMB1Protocol) { 'FAIL', 'Obsolete protocol enabled' } else { 'OK', 'Disabled' }
            }
        }
        @{ Name = 'Remote Desktop'; Test = {
                $denied = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
                if ($denied -eq 1) { 'OK', 'Disabled' } else { 'WARN', 'Enabled: check that this is intended' }
            }
        }
        @{ Name = 'BitLocker (system drive)'; Test = {
                $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive
                if ("$($volume.ProtectionStatus)" -eq 'On') { 'OK', 'Drive encrypted' } else { 'WARN', 'Drive not protected' }
            }
        }
        @{ Name = 'Secure Boot'; Test = {
                if (Confirm-SecureBootUEFI) { 'OK', 'Enabled' } else { 'WARN', 'Disabled' }
            }
        }
        @{ Name = 'Guest account'; Test = {
                $guest = Get-LocalUser | Where-Object { "$($_.SID)" -like '*-501' }
                if ($guest -and $guest.Enabled) { 'FAIL', 'Enabled' } else { 'OK', 'Disabled' }
            }
        }
        @{ Name = 'Accounts with no required password'; Test = {
                $accounts = @(Get-LocalUser | Where-Object { $_.Enabled -and -not $_.PasswordRequired } | ForEach-Object { $_.Name })
                if ($accounts.Count) { 'WARN', ($accounts -join ', ') } else { 'OK', 'None' }
            }
        }
        @{ Name = 'Local administrators'; Test = {
                $members = @(Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $_.Name })
                'INFO', ($members -join ', ')
            }
        }
        @{ Name = 'Latest Windows update'; Test = {
                $latest = Get-HotFix | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
                if (-not $latest) { 'WARN', 'Unknown date' }
                else {
                    $age = ((Get-Date) - $latest.InstalledOn).Days
                    $level = if ($age -gt 45) { 'WARN' } else { 'OK' }
                    $level, "$($latest.HotFixID), $age days ago"
                }
            }
        }
        @{ Name = 'Failed logons (24 h)'; Admin = $true; Test = {
                $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddDays(-1) } -ErrorAction SilentlyContinue)
                if ($events.Count -gt 10) { 'WARN', "$($events.Count) failures" } else { 'OK', "$($events.Count) failures" }
            }
        }
    )
}

# A check that cannot run is reported as such: it never passes for a success.
function Invoke-SecurityAudit {
    param([object[]]$Checks = (Get-AuditChecks))
    $isAdmin = Test-IsAdmin
    foreach ($check in $Checks) {
        if ($check.Admin -and -not $isAdmin) {
            New-Finding -Check $check.Name -Status INFO -Detail 'Not checked: administrator rights required'
            continue
        }
        try {
            $status, $detail = & $check.Test
            New-Finding -Check $check.Name -Status $status -Detail $detail
        }
        catch {
            New-Finding -Check $check.Name -Status INFO -Detail "Not checked: $($_.Exception.Message)"
        }
    }
}

function Show-SecurityAudit {
    $findings = @(Invoke-SecurityAudit)
    # Most urgent first, so that problems are not lost among the checks that passed.
    $groups = @(
        @{ Status = 'FAIL'; Title = 'To fix' }
        @{ Status = 'WARN'; Title = 'To review' }
        @{ Status = 'OK'; Title = 'Passed' }
        @{ Status = 'INFO'; Title = 'For information' }
    )
    $width = ($findings | ForEach-Object { $_.Check.Length } | Measure-Object -Maximum).Maximum
    foreach ($group in $groups) {
        $members = @($findings | Where-Object { $_.Status -eq $group.Status })
        if ($members.Count -eq 0) { continue }
        Write-Section ('{0} ({1})' -f $group.Title, $members.Count)
        foreach ($finding in $members) { Write-Status $finding.Status ('{0}  {1}' -f $finding.Check.PadRight($width), $finding.Detail) }
    }
    $problems = @($findings | Where-Object { $_.Status -in 'WARN', 'FAIL' }).Count

    Write-Section 'Result'
    if ($problems) { Write-Status WARN "$problems items to review." }
    else { Write-Status OK 'No problems found on the items checked.' }

    $report = New-ReportPath -Prefix 'audit'
    $sorted = foreach ($group in $groups) { $findings | Where-Object { $_.Status -eq $group.Status } }
    Format-TextTable -Rows @($sorted) -Width 160 | Out-File -LiteralPath $report -Encoding utf8
    Write-Log -Message "Security audit: $problems items to review."
    Write-Status INFO "Report: $report"
}

function Show-AppLog {
    if (-not [IO.File]::Exists($script:LogFile)) {
        Write-Status INFO 'The log is empty.'
        return
    }
    # The log is UTF-8 without a BOM, which Windows PowerShell would otherwise read as ANSI.
    Get-Content -LiteralPath $script:LogFile -Tail 50 -Encoding UTF8 | Out-Host
}

function Invoke-AppLogClear {
    if (-not [IO.File]::Exists($script:LogFile)) {
        Write-Status INFO 'The log is already empty.'
        return
    }
    if (Confirm-Action 'Clear the WinToolBox log? Windows logs are not affected.') {
        Remove-Item -LiteralPath $script:LogFile
        Write-Status OK 'Log cleared.'
    }
}

function Show-SecurityMenu {
    Show-Menu -Title 'Security and logs' -Items @(
        @{ Section = 'SECURITY'; Key = '1'; Label = 'Security audit'; Hint = 'read-only, saves a report'; Action = { Show-SecurityAudit } }
        @{ Section = 'LOGS'; Key = '2'; Label = 'View the WinToolBox log'; Hint = 'last 50 lines'; Action = { Show-AppLog } }
        @{ Section = 'LOGS'; Key = '3'; Label = 'Clear the WinToolBox log'; Danger = $true; Action = { Invoke-AppLogClear } }
    )
}

# Audit de securite en lecture seule et journaux de WinToolBox.

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
        @{ Name = 'Pare-feu'; Test = {
                $disabled = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Name })
                if ($disabled.Count) { 'FAIL', "Desactive sur : $($disabled -join ', ')" } else { 'OK', 'Actif sur tous les profils' }
            }
        }
        @{ Name = 'Antivirus enregistre'; Test = {
                $products = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct | ForEach-Object { $_.displayName })
                if ($products.Count) { 'OK', ($products -join ', ') } else { 'FAIL', 'Aucun antivirus enregistre' }
            }
        }
        @{ Name = 'Microsoft Defender'; Test = {
                $defender = Get-MpComputerStatus
                if (-not $defender.RealTimeProtectionEnabled) { 'WARN', 'Protection temps reel inactive' }
                elseif ($defender.AntivirusSignatureAge -gt 7) { 'WARN', "Signatures vieilles de $($defender.AntivirusSignatureAge) jours" }
                else { 'OK', "Actif, signatures de $($defender.AntivirusSignatureAge) jour(s)" }
            }
        }
        @{ Name = 'Controle de compte (UAC)'; Test = {
                $enabled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA
                if ($enabled -eq 1) { 'OK', 'Actif' } else { 'FAIL', 'Desactive' }
            }
        }
        @{ Name = 'SMBv1'; Test = {
                if ((Get-SmbServerConfiguration).EnableSMB1Protocol) { 'FAIL', 'Protocole obsolete actif' } else { 'OK', 'Desactive' }
            }
        }
        @{ Name = 'Bureau a distance'; Test = {
                $denied = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
                if ($denied -eq 1) { 'OK', 'Desactive' } else { 'WARN', 'Active : verifiez que c''est voulu' }
            }
        }
        @{ Name = 'BitLocker (disque systeme)'; Test = {
                $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive
                if ("$($volume.ProtectionStatus)" -eq 'On') { 'OK', 'Disque chiffre' } else { 'WARN', 'Disque non protege' }
            }
        }
        @{ Name = 'Secure Boot'; Test = {
                if (Confirm-SecureBootUEFI) { 'OK', 'Actif' } else { 'WARN', 'Inactif' }
            }
        }
        @{ Name = 'Compte Invite'; Test = {
                $guest = Get-LocalUser | Where-Object { "$($_.SID)" -like '*-501' }
                if ($guest -and $guest.Enabled) { 'FAIL', 'Active' } else { 'OK', 'Desactive' }
            }
        }
        @{ Name = 'Comptes sans mot de passe obligatoire'; Test = {
                $accounts = @(Get-LocalUser | Where-Object { $_.Enabled -and -not $_.PasswordRequired } | ForEach-Object { $_.Name })
                if ($accounts.Count) { 'WARN', ($accounts -join ', ') } else { 'OK', 'Aucun' }
            }
        }
        @{ Name = 'Administrateurs locaux'; Test = {
                $members = @(Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $_.Name })
                'INFO', ($members -join ', ')
            }
        }
        @{ Name = 'Dernier correctif Windows'; Test = {
                $latest = Get-HotFix | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
                if (-not $latest) { 'WARN', 'Date inconnue' }
                else {
                    $age = ((Get-Date) - $latest.InstalledOn).Days
                    $level = if ($age -gt 45) { 'WARN' } else { 'OK' }
                    $level, "$($latest.HotFixID), il y a $age jours"
                }
            }
        }
        @{ Name = 'Echecs de connexion (24 h)'; Admin = $true; Test = {
                $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddDays(-1) } -ErrorAction SilentlyContinue)
                if ($events.Count -gt 10) { 'WARN', "$($events.Count) echecs" } else { 'OK', "$($events.Count) echecs" }
            }
        }
    )
}

# Une verification impossible est signalee comme telle : elle ne passe jamais pour un succes.
function Invoke-SecurityAudit {
    param([object[]]$Checks = (Get-AuditChecks))
    $isAdmin = Test-IsAdmin
    foreach ($check in $Checks) {
        if ($check.Admin -and -not $isAdmin) {
            New-Finding -Check $check.Name -Status INFO -Detail 'Non verifie : droits administrateur requis'
            continue
        }
        try {
            $status, $detail = & $check.Test
            New-Finding -Check $check.Name -Status $status -Detail $detail
        }
        catch {
            New-Finding -Check $check.Name -Status INFO -Detail "Non verifie : $($_.Exception.Message)"
        }
    }
}

function Show-SecurityAudit {
    $findings = @(Invoke-SecurityAudit)
    foreach ($finding in $findings) { Write-Status $finding.Status ('{0,-38} {1}' -f $finding.Check, $finding.Detail) }
    $problems = @($findings | Where-Object { $_.Status -in 'WARN', 'FAIL' }).Count
    Write-Host ''
    if ($problems) { Write-Status WARN "$problems points a examiner." }
    else { Write-Status OK 'Aucun probleme detecte sur les points controles.' }

    $report = New-ReportPath -Prefix 'audit'
    $findings | Format-Table -AutoSize -Wrap | Out-File -LiteralPath $report -Encoding utf8 -Width 160
    Write-Log -Message "Audit de securite : $problems points a examiner."
    Write-Status INFO "Rapport : $report"
}

function Show-AppLog {
    if (-not [IO.File]::Exists($script:LogFile)) {
        Write-Status INFO 'Le journal est vide.'
        return
    }
    Get-Content -LiteralPath $script:LogFile -Tail 50 | Out-Host
}

function Invoke-AppLogClear {
    if (-not [IO.File]::Exists($script:LogFile)) {
        Write-Status INFO 'Le journal est deja vide.'
        return
    }
    if (Confirm-Action 'Effacer le journal de WinToolBox ? Les journaux Windows ne sont pas concernes.') {
        Remove-Item -LiteralPath $script:LogFile
        Write-Status OK 'Journal efface.'
    }
}

function Show-SecurityMenu {
    Show-Menu -Title 'Securite et journaux' -Items @(
        @{ Section = 'SECURITE'; Key = '1'; Label = 'Audit de securite'; Action = { Show-SecurityAudit } }
        @{ Section = 'JOURNAUX'; Key = '2'; Label = 'Voir le journal de WinToolBox'; Action = { Show-AppLog } }
        @{ Section = 'JOURNAUX'; Key = '3'; Label = 'Effacer le journal de WinToolBox'; Action = { Invoke-AppLogClear } }
    )
}

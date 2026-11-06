# Comptes et groupes locaux. Les groupes integres sont vises par SID, car leur nom change avec la
# langue : S-1-5-32-544 pour Administrateurs, S-1-5-32-545 pour Utilisateurs.

function Test-LocalUserName {
    param([string]$Name)
    return ($Name -and $Name.Length -le 20 -and $Name -notmatch '["/\\\[\]:;|=,+*?<>@]' -and -not $Name.EndsWith('.'))
}

function Test-SecureStringEqual {
    param([Parameter(Mandatory)][securestring]$First, [Parameter(Mandatory)][securestring]$Second)
    $firstPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($First)
    $secondPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Second)
    try {
        return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($firstPtr) -ceq [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secondPtr))
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($firstPtr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secondPtr)
    }
}

function Select-LocalUser {
    return (Select-FromList -Items @(Get-LocalUser | Sort-Object Name) -Format { param($u) '{0}{1}' -f $u.Name, $(if ($u.Enabled) { '' } else { ' (desactive)' }) })
}

function Show-LocalUsers {
    $admins = @{}
    try {
        Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $admins["$($_.SID)"] = $true }
    }
    catch { Write-Status WARN 'Liste des administrateurs indisponible.' }
    Get-LocalUser | Sort-Object Name | Select-Object Name, Enabled, PasswordRequired, LastLogon,
    @{ n = 'Admin'; e = { $admins.ContainsKey("$($_.SID)") } } | Format-Table -AutoSize | Out-Host
}

function Invoke-UserCreate {
    $name = Read-Text 'Nom du compte'
    if (-not (Test-LocalUserName $name)) {
        Write-Status WARN 'Nom invalide : 20 caracteres au plus, sans caracteres speciaux.'
        return
    }
    $password = Read-Host '  Mot de passe' -AsSecureString
    $again = Read-Host '  Confirmez le mot de passe' -AsSecureString
    if ($password.Length -eq 0) {
        Write-Status WARN 'Un mot de passe est obligatoire.'
        return
    }
    if (-not (Test-SecureStringEqual -First $password -Second $again)) {
        Write-Status WARN 'Les mots de passe sont differents.'
        return
    }
    [void](New-LocalUser -Name $name -Password $password)
    Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $name
    Write-Log -Message "Compte cree : $name."
    Write-Status OK "Compte $name cree, membre du groupe Utilisateurs."
}

function Invoke-UserDelete {
    $user = Select-LocalUser
    if (-not $user) { return }
    if ($user.Name -ieq $env:USERNAME) {
        Write-Status FAIL 'Impossible de supprimer le compte en cours d''utilisation.'
        return
    }
    if (-not (Confirm-Phrase -Message "Le compte $($user.Name) sera supprime. Son dossier de profil reste sur le disque." -Phrase "SUPPRIMER $($user.Name)")) {
        Write-Status INFO 'Suppression annulee.'
        return
    }
    Remove-LocalUser -InputObject $user
    Write-Log -Level WARN -Message "Compte supprime : $($user.Name)."
    Write-Status OK 'Compte supprime.'
}

function Invoke-UserToggle {
    $user = Select-LocalUser
    if (-not $user) { return }
    if ($user.Name -ieq $env:USERNAME) {
        Write-Status FAIL 'Impossible de desactiver le compte en cours d''utilisation.'
        return
    }
    if ($user.Enabled) {
        if (-not (Confirm-Action "Desactiver $($user.Name) ?")) { return }
        Disable-LocalUser -InputObject $user
    }
    else {
        if (-not (Confirm-Action "Activer $($user.Name) ?")) { return }
        Enable-LocalUser -InputObject $user
    }
    Write-Log -Message "Etat du compte modifie : $($user.Name)."
    Write-Status OK 'Etat du compte modifie.'
}

function Show-LocalGroups {
    foreach ($group in Get-LocalGroup | Sort-Object Name) {
        $members = @(Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        if ($members.Count) { Write-Host ('   {0} : {1}' -f $group.Name, ($members -join ', ')) }
    }
}

function Invoke-GroupMembership {
    $user = Select-LocalUser
    if (-not $user) { return }
    $group = Select-FromList -Items @(Get-LocalGroup | Sort-Object Name) -Format { param($g) $g.Name }
    if (-not $group) { return }
    if ((Read-Text '[A]jouter au groupe ou [R]etirer du groupe') -ieq 'R') {
        if (Confirm-Action "Retirer $($user.Name) de $($group.Name) ?") {
            Remove-LocalGroupMember -Group $group -Member $user
            Write-Log -Message "$($user.Name) retire de $($group.Name)."
            Write-Status OK 'Membre retire.'
        }
    }
    elseif (Confirm-Action "Ajouter $($user.Name) a $($group.Name) ?") {
        Add-LocalGroupMember -Group $group -Member $user
        Write-Log -Message "$($user.Name) ajoute a $($group.Name)."
        Write-Status OK 'Membre ajoute.'
    }
}

function Show-UsersMenu {
    Show-Menu -Title 'Utilisateurs et groupes' -Items @(
        @{ Section = 'COMPTES'; Key = '1'; Label = 'Lister les comptes'; Action = { Show-LocalUsers } }
        @{ Section = 'COMPTES'; Key = '2'; Label = 'Creer un compte'; Admin = $true; Action = { Invoke-UserCreate } }
        @{ Section = 'COMPTES'; Key = '3'; Label = 'Activer ou desactiver un compte'; Admin = $true; Action = { Invoke-UserToggle } }
        @{ Section = 'COMPTES'; Key = '4'; Label = 'Supprimer un compte'; Admin = $true; Action = { Invoke-UserDelete } }
        @{ Section = 'GROUPES'; Key = '5'; Label = 'Lister les groupes'; Action = { Show-LocalGroups } }
        @{ Section = 'GROUPES'; Key = '6'; Label = 'Modifier les membres d''un groupe'; Admin = $true; Action = { Invoke-GroupMembership } }
    )
}

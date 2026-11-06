# Local accounts and groups. Built-in groups are targeted by SID, because their name changes with
# the language: S-1-5-32-544 for Administrators, S-1-5-32-545 for Users.

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
    return (Select-FromList -Items @(Get-LocalUser | Sort-Object Name) -Format { param($u) '{0}{1}' -f $u.Name, $(if ($u.Enabled) { '' } else { ' (disabled)' }) })
}

function Show-LocalUsers {
    $admins = @{}
    try {
        Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $admins["$($_.SID)"] = $true }
    }
    catch { Write-Status WARN 'Administrator list unavailable.' }
    Write-Table -Rows @(Get-LocalUser | Sort-Object Name | Select-Object Name, Enabled, @{ n = 'Password required'; e = { $_.PasswordRequired } }, @{ n = 'Last logon'; e = { $_.LastLogon } },
        @{ n = 'Admin'; e = { $admins.ContainsKey("$($_.SID)") } })
}

function Invoke-UserCreate {
    $name = Read-Text 'Account name'
    if (-not (Test-LocalUserName $name)) {
        Write-Status WARN 'Invalid name: 20 characters at most, no special characters.'
        return
    }
    $password = Read-Host '  Password' -AsSecureString
    $again = Read-Host '  Confirm the password' -AsSecureString
    if ($password.Length -eq 0) {
        Write-Status WARN 'A password is required.'
        return
    }
    if (-not (Test-SecureStringEqual -First $password -Second $again)) {
        Write-Status WARN 'The passwords do not match.'
        return
    }
    [void](New-LocalUser -Name $name -Password $password)
    Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $name
    Write-Log -Message "Account created: $name."
    Write-Status OK "Account $name created, member of the Users group."
}

function Invoke-UserDelete {
    $user = Select-LocalUser
    if (-not $user) { return }
    if ($user.Name -ieq $env:USERNAME) {
        Write-Status FAIL 'Cannot delete the account currently in use.'
        return
    }
    if (-not (Confirm-Phrase -Message "Account $($user.Name) will be deleted. Its profile folder stays on the disk." -Phrase "DELETE $($user.Name)")) {
        Write-Status INFO 'Deletion cancelled.'
        return
    }
    Remove-LocalUser -InputObject $user
    Write-Log -Level WARN -Message "Account deleted: $($user.Name)."
    Write-Status OK 'Account deleted.'
}

function Invoke-UserToggle {
    $user = Select-LocalUser
    if (-not $user) { return }
    if ($user.Name -ieq $env:USERNAME) {
        Write-Status FAIL 'Cannot disable the account currently in use.'
        return
    }
    if ($user.Enabled) {
        if (-not (Confirm-Action "Disable $($user.Name)?")) { return }
        Disable-LocalUser -InputObject $user
    }
    else {
        if (-not (Confirm-Action "Enable $($user.Name)?")) { return }
        Enable-LocalUser -InputObject $user
    }
    Write-Log -Message "Account state changed: $($user.Name)."
    Write-Status OK 'Account state changed.'
}

function Show-LocalGroups {
    Write-Table -Empty 'No group has members.' -Rows @(foreach ($group in Get-LocalGroup | Sort-Object Name) {
            $members = @(Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            if ($members.Count) { [pscustomobject]@{ Group = $group.Name; Members = $members -join ', ' } }
        })
}

function Invoke-GroupMembership {
    $user = Select-LocalUser
    if (-not $user) { return }
    $group = Select-FromList -Items @(Get-LocalGroup | Sort-Object Name) -Format { param($g) $g.Name }
    if (-not $group) { return }
    if ((Read-Text '[A]dd to group or [R]emove from group') -ieq 'R') {
        if (Confirm-Action "Remove $($user.Name) from $($group.Name)?") {
            Remove-LocalGroupMember -Group $group -Member $user
            Write-Log -Message "$($user.Name) removed from $($group.Name)."
            Write-Status OK 'Member removed.'
        }
    }
    elseif (Confirm-Action "Add $($user.Name) to $($group.Name)?") {
        Add-LocalGroupMember -Group $group -Member $user
        Write-Log -Message "$($user.Name) added to $($group.Name)."
        Write-Status OK 'Member added.'
    }
}

function Show-UsersMenu {
    Show-Menu -Title 'Users and groups' -Items @(
        @{ Section = 'ACCOUNTS'; Key = '1'; Label = 'List accounts'; Action = { Show-LocalUsers } }
        @{ Section = 'ACCOUNTS'; Key = '2'; Label = 'Create an account'; Admin = $true; Action = { Invoke-UserCreate } }
        @{ Section = 'ACCOUNTS'; Key = '3'; Label = 'Enable or disable an account'; Admin = $true; Action = { Invoke-UserToggle } }
        @{ Section = 'ACCOUNTS'; Key = '4'; Label = 'Delete an account'; Danger = $true; Admin = $true; Action = { Invoke-UserDelete } }
        @{ Section = 'GROUPS'; Key = '5'; Label = 'List groups'; Action = { Show-LocalGroups } }
        @{ Section = 'GROUPS'; Key = '6'; Label = 'Change group members'; Admin = $true; Action = { Invoke-GroupMembership } }
    )
}

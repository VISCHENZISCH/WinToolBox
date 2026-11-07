@echo off
rem Launcher: all application code lives in src\WinToolBox.ps1
setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
    echo [!] Windows PowerShell was not found.
    pause
    exit /b 1
)
rem -Command is needed to set the execution policy first. Arguments travel through the
rem environment, so that src\Launcher.ps1 can read them without PowerShell interpreting them.
set "WTB_LAUNCHER=%~dp0src\Launcher.ps1"
rem Not quoted: a quoted argument containing & would otherwise end up outside the quotes.
set WTB_ARGS=%*
set "PS_BOOT=$ErrorActionPreference='Stop';"
set "PS_BOOT=%PS_BOOT% if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') { Write-Host 'PowerShell runs in Constrained Language Mode here (AppLocker, WDAC or a policy). WinToolBox needs Full Language Mode: ask your administrator to allow its scripts.' -ForegroundColor Red; exit 1 };"
set "PS_BOOT=%PS_BOOT% $gpo = Get-ExecutionPolicy -List | Where-Object { $_.Scope -match 'Policy$' -and $_.ExecutionPolicy -ne 'Undefined' } | Select-Object -First 1;"
set "PS_BOOT=%PS_BOOT% if ($gpo.ExecutionPolicy -in 'Restricted','AllSigned') { Write-Host ('A Group Policy ({0}) enforces the {1} execution policy, which blocks WinToolBox and cannot be overridden from here. Ask your administrator to change it or to sign the scripts.' -f $gpo.Scope,$gpo.ExecutionPolicy) -ForegroundColor Red; exit 1 };"
set "PS_BOOT=%PS_BOOT% if (-not $gpo) { try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { Write-Host ('Execution policy not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow } };"
set "PS_BOOT=%PS_BOOT% try { & $env:WTB_LAUNCHER; exit $LASTEXITCODE } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"
"%PS_EXE%" -NoLogo -NoProfile -Command "%PS_BOOT%"
set "RC=%ERRORLEVEL%"
rem Only the interactive menu pauses: with arguments, a calling script must not hang.
if not "%RC%"=="0" if "%~1"=="" pause
exit /b %RC%

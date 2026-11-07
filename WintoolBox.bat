@echo off
rem Launcher: all application code lives in src\WinToolBox.ps1
setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
    echo [!] Windows PowerShell was not found.
    pause
    exit /b 1
)
rem Unlike -File, -Command neither keeps arguments apart nor forwards the exit code. Arguments
rem travel through the environment and are parsed as PowerShell, with $ and ` kept literal.
set "WTB_SCRIPT=%~dp0src\WinToolBox.ps1"
rem Not quoted: a quoted argument containing & would otherwise end up outside the quotes.
set WTB_ARGS=%*
set "PS_BOOT=$ErrorActionPreference='Stop';"
set "PS_BOOT=%PS_BOOT% try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { };"
set "PS_BOOT=%PS_BOOT% try { & ([scriptblock]::Create('& $env:WTB_SCRIPT ' + ($env:WTB_ARGS -replace '[`$]','`$0'))); exit $LASTEXITCODE }"
set "PS_BOOT=%PS_BOOT% catch { [Console]::Error.WriteLine($_); exit 1 }"
"%PS_EXE%" -NoLogo -NoProfile -Command "%PS_BOOT%"
set "RC=%ERRORLEVEL%"
rem Only the interactive menu pauses: with arguments, a calling script must not hang.
if not "%RC%"=="0" if "%~1"=="" pause
exit /b %RC%

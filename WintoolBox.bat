@echo off
rem Lanceur : tout le code applicatif se trouve dans src\WinToolBox.ps1
setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
    echo [!] Windows PowerShell est introuvable.
    pause
    exit /b 1
)
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\WinToolBox.ps1" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%

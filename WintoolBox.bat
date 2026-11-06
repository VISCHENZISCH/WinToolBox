@echo off
rem Launcher: all application code lives in src\WinToolBox.ps1
setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
    echo [!] Windows PowerShell was not found.
    pause
    exit /b 1
)
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\WinToolBox.ps1" %*
set "RC=%ERRORLEVEL%"
rem Only the interactive menu pauses: with arguments, a calling script must not hang.
if not "%RC%"=="0" if "%~1"=="" pause
exit /b %RC%

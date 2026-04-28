@echo off
setlocal enabledelayedexpansion
set "CORE=..\lib\core.bat"
call "%CORE%"

call "%CORE%" :display_header "Nettoyage Systeme" "CLN"
call "%CORE%" :loading "Analyse espace" 2

echo  - [1/3] Nettoyage Temp...
del /q /f /s "%temp%\*" >nul 2>&1
del /q /f /s "%windir%\temp\*" >nul 2>&1

echo  - [2/3] Vidage Corbeille...
rd /s /q %systemdrive%\$Recycle.Bin >nul 2>&1

echo  - [3/3] Nettoyage Logs...
wevtutil cl System >nul 2>&1
wevtutil cl Application >nul 2>&1

echo.
echo  [ ok ] Nettoyage termine.
pause
exit /b 0
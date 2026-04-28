@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
call "%CORE%"

:menu
call "%CORE%" :display_header "Reseau" "NET"
echo  [1] Info  [2] Monitoring (Live)  [Q] Retour
echo.
set /p "opt=Choix: "

if /i "%opt%"=="Q" exit /b 0
if "%opt%"=="1" call :info
if "%opt%"=="2" call :mon
goto :menu

:info
echo.
echo  * Statut Interfaces :
netsh interface show interface | findstr "Connected"
echo.
echo  * Test Connectivite :
ping -n 1 8.8.8.8 >nul && (echo  [ok] Internet) || (echo  [!] Pas d'Internet)
echo.
echo  * Ports sensibles :
netstat -ano | findstr "LISTENING" | findstr ":21 :23 :445 :3389" || echo  Aucun port sensible detecte.
pause
goto :eof

:mon
echo  [ MONITORING ACTIF ] (Ctrl+C pour arreter)
echo.
:loop
netstat -an | findstr "ESTABLISHED LISTENING" | findstr ":80 :443 :3389 :22 :445"
timeout /t 2 >nul
goto :loop
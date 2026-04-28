@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
call "%CORE%"

:menu
call "%CORE%" :display_header "Securite Globale" "SEC"
echo  [1] Statut  [2] Journaux  [Q] Retour
echo.
set /p "opt=Choix: "

if /i "%opt%"=="Q" exit /b 0
if "%opt%"=="1" call :status
if "%opt%"=="2" call :logs
goto :menu

:status
echo.
echo  * Statut du systeme :
netsh advfirewall show allprofiles state | findstr "State"
wmic /namespace:\\root\securitycenter2 path antivirusproduct get displayname,productstate | findstr /V "displayName"
tasklist /FI "STATUS eq running" | findstr /I "lsass.exe services.exe wininit.exe"
pause
goto :eof

:logs
echo.
echo  * Gestion des journaux :
echo  [V] Voir  [C] Nettoyer  [A] Archiver
set /p "lopt=Action: "
if /i "%lopt%"=="V" (if exist "logs\*.log" (type "logs\*.log" | more) else (echo Aucun log.))
if /i "%lopt%"=="C" (del /q logs\*.log & echo [ok])
if /i "%lopt%"=="A" (mkdir logs\archive >nul 2>&1 & move logs\*.log logs\archive\ >nul 2>&1 & echo [ok])
pause
goto :eof
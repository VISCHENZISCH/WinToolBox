@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title WinToolBox v3.0

set "CORE=lib\core.bat"
if not exist "%CORE%" (echo Erreur Core Lib & pause & exit /b 1)
call "%CORE%"

if not defined BOOT_DONE (
    call :boot_sequence
    set "BOOT_DONE=1"
)

:menu
call "%CORE%" :display_header "WinToolBox" "MAIN"
echo.
echo  [1] SYSTEM   [2] CLEANUP  [3] NETWORK  [4] USERS    [5] SECURITY [6] BACKUP
echo.
echo  [X] QUITTER
echo  ---------------------------------------------------------------------------
echo.
set /p "choice=Choice: "

if /i "%choice%"=="X" goto :quit
set "mod="
for %%i in (1-sysinfo 2-cleanup 3-network 4-users 5-security 6-backup) do (
    for /f "tokens=1,2 delims=-" %%a in ("%%i") do if "%choice%"=="%%a" set "mod=modules\%%b.bat"
)

if defined mod (
    if exist "%mod%" (
        call "%mod%"
    ) else (
        echo [!] Module introuvable: %mod%
        pause
    )
    goto :menu
)

if not "%choice%"=="" (
    echo [!] Option "%choice%" invalide
    timeout /t 2 >nul
)
goto :menu

:boot_sequence
cls
echo.
echo            Initialisation WinToolBox...
echo  ****************************************************
echo  [ .. ] Chargement Noyau...
timeout /t 1 >nul
echo  [ ok ] Noyau pret.
echo  [ .. ] Services Securite...
timeout /t 1 >nul
echo  [ ok ] Services prets.
timeout /t 1 >nul
goto :eof

:quit
call "%CORE%" :display_header "Fermeture" "BYE"
call "%CORE%" :loading "Nettoyage" 3
endlocal
exit /b 0

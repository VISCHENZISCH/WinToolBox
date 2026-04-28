@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
call "%CORE%"

:menu
call "%CORE%" :display_header "Sauvegarde" "BAK"
echo  [1] Sauvegarder  [2] Restaurer  [Q] Retour
echo.
set /p "opt=Choix: "

if /i "%opt%"=="Q" exit /b 0
if "%opt%"=="1" call :bak
if "%opt%"=="2" call :res
goto :menu

:bak
set /p "s=Source: "
set /p "d=Destination: "
if not exist "%s%" (echo [!] Source absente & pause & goto :eof)
robocopy "%s%" "%d%" /E /R:3 /W:10 /MT:8 /TEE /LOG+:logs\backup.log
echo [ok] Termine
pause
goto :eof

:res
set /p "s=Sauvegarde: "
set /p "d=Restauration: "
if not exist "%s%" (echo [!] Sauvegarde absente & pause & goto :eof)
robocopy "%s%" "%d%" /E /R:3 /W:10 /MT:8 /TEE /LOG+:logs\backup.log
echo [ok] Termine
pause
goto :eof
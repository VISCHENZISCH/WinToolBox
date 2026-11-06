@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
if not exist "%CORE%" (echo  [!] Core introuvable & pause & exit /b 1)
call "%CORE%"

call "%CORE%" :display_header "Nettoyage Systeme" "CLN"
echo  Cette action va supprimer :
echo   - les fichiers temporaires de l'utilisateur et de Windows
echo   - le contenu de la corbeille de tous les utilisateurs
echo.
call "%CORE%" :confirm "Continuer ?"
if errorlevel 1 (
    pause
    exit /b 0
)

call "%CORE%" :loading "Analyse espace" 2

echo  - [1/2] Nettoyage Temp...
del /q /f /s "%temp%\*" >nul 2>&1
del /q /f /s "%windir%\temp\*" >nul 2>&1

echo  - [2/2] Vidage Corbeille...
rd /s /q "%systemdrive%\$Recycle.Bin" >nul 2>&1

echo.
echo  [ ok ] Nettoyage termine.
pause
exit /b 0

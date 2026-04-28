@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
call "%CORE%"

:menu
call "%CORE%" :display_header "Gestion Utilisateurs" "USR"
echo  [1] Lister  [2] Ajouter  [3] Supprimer  [4] Groupes  [Q] Retour
echo.
set /p "opt=Choix: "

if /i "%opt%"=="Q" exit /b 0
if "%opt%"=="1" call :list
if "%opt%"=="2" call :add
if "%opt%"=="3" call :del
if "%opt%"=="4" call :groups
goto :menu

:list
echo.
echo  * Utilisateurs :
net user
pause
goto :eof

:add
set /p "u=Nom: "
if "%u%"=="" goto :eof
net user "%u%" /add && (echo   [ok] Cree) || (echo   [!] Echec)
pause
goto :eof

:del
set /p "u=Nom: "
if "%u%"=="" goto :eof
net user "%u%" /delete && (echo   [ok] Supprime) || (echo   [!] Echec)
pause
goto :eof

:groups
echo.
echo  * Groupes :
net localgroup
pause
goto :eof
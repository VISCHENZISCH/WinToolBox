@echo off
setlocal enabledelayedexpansion
set "CORE=%~dp0..\lib\core.bat"
if not exist "%CORE%" set "CORE=lib\core.bat"
call "%CORE%"

call "%CORE%" :display_header "Informations Systeme" "SYS"
call "%CORE%" :loading "Collecte donnees" 3

echo  [OS] Systeme :
wmic os get Caption,Version,OSArchitecture /value | findstr "="
echo.
echo  [HW] Materiel :
wmic cpu get Name /value | findstr "="
wmic memorychip get Capacity /value | findstr "="
echo.
echo  [NET] Reseau :
ipconfig | findstr "IPv4"
echo.
echo  [DSK] Stockage :
wmic logicaldisk where "DeviceID='%systemdrive%'" get Size,FreeSpace /value | findstr "="

pause
exit /b 0
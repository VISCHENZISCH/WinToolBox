@echo off
title WinToolBox - Admin Suite
color 0F
:: =======================================
:: WinToolBox v1.0 Script principal
:: Auteur : [ VISCHENZISCH ]
:: Date : %date%
:: =======================================

:menu
cls
echo =====================================
echo.
echo     WinToolBox - Admin Suite v1.0
echo     auteur : [ VISCHENZISCH ]
echo.
echo =====================================
echo [1] Informations systeme
echo.
echo [2] Nettoyage - Optimisation
echo.
echo [3] Surveillance reseau
echo.
echo [4] Gestion des utilisateurs
echo.
echo [5] Securite - Pare-feu
echo.
echo [6] Sauvegarde - Restauration
echo.
echo [7] Quitter
echo =====================================
echo
set /p choice="Entrer votre choix : "

if "%choice%"=="1" call modules\sysinfo.bat
if "%choice%"=="2" call modules\cleanup.bat
if "%choice%"=="3" call modules\network.bat
if "%choice%"=="4" call modules\users.bat
if "%choice%"=="5" call modules\security.bat
if "%choice%"=="6" call modules\backup.bat
if "%choice%"=="7" exit

pause 
goto menu

:: Fin du script

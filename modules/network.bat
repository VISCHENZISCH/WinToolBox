@echo off
setlocal enabledelayedexpansion
for /f %%a in ('copy /z "%~f0" nul') do set "CR=%%a"
:: --- ANSI Color Definitions ---
set "ESC= "
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "RED=%ESC%[38;2;158;34;34m"
set "TEAL=%ESC%[38;2;2;223;164m"
set "WHITE=%ESC%[97m"
set "RESET=%ESC%[0m"

:: =======================================
:: Module 3 : Surveillance Réseau v1.2
:: Améliorations : Tests complets, diagnostics, sécurité
:: =======================================

cls
echo %WHITE%
set logfile=logs\network_report.txt

:: Fonction de logging
call :log_message "=== Module Réseau démarré ==="

call :display_module_header "Surveillance Réseau" "[NET]"
echo.
call :loading_animation "Analyse des interfaces réseau"
echo.
echo [*] Tests de connectivité et diagnostics réseau...
echo.

:: Tests de connectivité
echo [1/6] Test de connectivité Internet...
call :test_internet_connectivity

:: Test DNS
echo [2/6] Test de résolution DNS...
call :test_dns_resolution

:: Analyse des connexions réseau
echo [3/6] Analyse des connexions réseau...
call :analyze_network_connections

:: Test de vitesse
echo [4/6] Test de vitesse de connexion...
call :test_connection_speed

:: Vérification des ports ouverts
echo [5/6] Vérification des ports ouverts...
call :check_open_ports

:: Diagnostic réseau complet
echo [6/6] Diagnostic réseau complet...
call :network_diagnostics

echo.
echo =====================================
echo           RÉSULTATS RÉSEAU
echo =====================================
echo Rapport détaillé : %logfile%
echo =====================================

call :log_message "Module Réseau terminé"
pause
goto :eof

:: =======================================
:: Fonctions du module réseau
:: =======================================

:test_internet_connectivity
call :log_message "Test de connectivité Internet"
echo Test de connectivité vers Google...
ping -n 4 google.com >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCÈS] Connectivité Internet OK
    call :log_message "SUCCÈS: Connectivité Internet OK"
) else (
    echo [ERREUR] Problème de connectivité Internet
    call :log_message "ERREUR: Problème de connectivité Internet"
)

echo Test de connectivité vers DNS Google...
ping -n 4 8.8.8.8 >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCÈS] DNS Google accessible
    call :log_message "SUCCÈS: DNS Google accessible"
) else (
    echo [ERREUR] DNS Google inaccessible
    call :log_message "ERREUR: DNS Google inaccessible"
)
goto :eof

:test_dns_resolution
call :log_message "Test de résolution DNS"
echo Test de résolution DNS...
nslookup google.com >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCÈS] Résolution DNS fonctionnelle
    call :log_message "SUCCÈS: Résolution DNS fonctionnelle"
) else (
    echo [ERREUR] Problème de résolution DNS
    call :log_message "ERREUR: Problème de résolution DNS"
)
goto :eof

:analyze_network_connections
call :log_message "Analyse des connexions réseau"
echo Analyse des connexions actives...
netstat -an >> %logfile%
echo [INFO] Connexions réseau enregistrées dans le rapport
goto :eof

:test_connection_speed
call :log_message "Test de vitesse de connexion"
echo Test de vitesse (ping vers Google)...
ping -n 10 google.com | find "Average" >> %logfile%
echo [INFO] Test de vitesse enregistré dans le rapport
goto :eof

:check_open_ports
call :log_message "Vérification des ports ouverts"
echo Vérification des ports ouverts...
netstat -an | find "LISTENING" >> %logfile%
echo [INFO] Ports ouverts enregistrés dans le rapport
goto :eof

:network_diagnostics
call :log_message "Diagnostic réseau complet"
echo Diagnostic réseau complet...

:: Configuration IP
echo Configuration IP actuelle:
ipconfig /all >> %logfile%

:: Tables de routage
echo Tables de routage:
route print >> %logfile%

:: Informations sur les interfaces
echo Interfaces réseau:
netsh interface show interface >> %logfile%

call :log_message "Diagnostic réseau complet terminé"
goto :eof

:log_message
echo [%date% %time%] %~1 >> %logfile%
goto :eof

:display_module_header
set "module_name=%~1"
set "icon=%~2"
cls
echo %TEAL%
echo.
echo  ...........................................................................
echo  :                                                                         :
echo  :  [%icon%] %module_name% [%icon%]                                        :
echo  :                                                                         :
echo  :.........................................................................:
echo %WHITE%
goto :eof

:display_step_header
set "step=%~1"
set "title=%~2"
set "icon=%~3"
echo.
echo  ...........................................................................
echo  :  %icon% ÉTAPE %step%: %title%
echo  :.........................................................................:
echo.
goto :eof

:loading_animation
set "text=%~1"
set "frames=0"
echo.
:loading_loop_net2
set /a "percent=frames*5"
set "bar="
set /a "bar_len=percent/5"
for /l %%i in (1,1,!bar_len!) do set "bar=!bar!█"
for /l %%i in (!bar_len!,1,19) do set "bar=!bar! "
<nul set /p "=!CR!  %text%... [!bar!] !percent!%%"
if %frames% equ 20 (
    echo.
    echo  [OK] COMPLETE
    timeout /t 1 >nul
    goto :eof
)
timeout /t 1 >nul
set /a frames+=1
goto loading_loop_net2

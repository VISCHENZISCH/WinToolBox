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
:: Module 5 : Sécurité et Pare-feu v1.2
:: Améliorations : Analyses complètes, détection de menaces
:: =======================================

cls
echo %WHITE%
set logfile=logs\security_report.txt

:: Fonction de logging
call :log_message "=== Module Sécurité démarré ==="

call :display_module_header "Sécurité et Pare-feu" "[SEC]"
echo.
call :loading_animation "Analyse de sécurité"
echo.

:: Analyse du pare-feu
echo [1/7] Analyse de la configuration du pare-feu...
call :analyze_firewall

:: Vérification des processus suspects
echo [2/7] Vérification des processus suspects...
call :check_suspicious_processes

:: Analyse des services système
echo [3/7] Analyse des services système...
call :analyze_system_services

:: Vérification des ports ouverts
echo [4/7] Vérification des ports ouverts...
call :check_security_ports

:: Analyse des permissions
echo [5/7] Analyse des permissions système...
call :analyze_permissions

:: Vérification des mises à jour
echo [6/7] Vérification des mises à jour de sécurité...
call :check_security_updates

:: Rapport de sécurité complet
echo [7/7] Génération du rapport de sécurité...
call :generate_security_report

echo.
echo =====================================
echo           RÉSULTATS SÉCURITÉ
echo =====================================
echo Rapport détaillé : %logfile%
echo =====================================

call :log_message "Module Sécurité terminé"
pause
goto :eof

:: =======================================
:: Fonctions du module sécurité
:: =======================================

:analyze_firewall
call :log_message "Analyse de la configuration du pare-feu"
echo Configuration actuelle du pare-feu :
netsh advfirewall show allprofiles >> %logfile%
echo [INFO] Configuration pare-feu enregistrée dans le rapport
goto :eof

:check_suspicious_processes
call :log_message "Vérification des processus suspects"
echo Analyse des processus actifs...
tasklist /v >> %logfile%

:: Recherche de processus suspects
echo Recherche de processus suspects...
for /f "tokens=1" %%i in ('tasklist /fo csv ^| findstr /i "svchost.exe"') do (
    echo Processus suspect détecté : %%i
    call :log_message "ALERTE: Processus suspect détecté - %%i"
)
goto :eof

:analyze_system_services
call :log_message "Analyse des services système"
echo Analyse des services système...
sc query state= all >> %logfile%
echo [INFO] Services système enregistrés dans le rapport
goto :eof

:check_security_ports
call :log_message "Vérification des ports de sécurité"
echo Vérification des ports ouverts...
netstat -an | find "LISTENING" >> %logfile%

:: Vérification des ports critiques
echo Vérification des ports critiques...
netstat -an | find ":80 " >> %logfile%
netstat -an | find ":443 " >> %logfile%
netstat -an | find ":3389 " >> %logfile%
echo [INFO] Ports critiques vérifiés
goto :eof

:analyze_permissions
call :log_message "Analyse des permissions système"
echo Analyse des permissions utilisateur...
whoami /all >> %logfile%
echo [INFO] Permissions utilisateur enregistrées dans le rapport
goto :eof

:check_security_updates
call :log_message "Vérification des mises à jour de sécurité"
echo Vérification des mises à jour...
wmic qfe list >> %logfile%
echo [INFO] Mises à jour système enregistrées dans le rapport
goto :eof

:generate_security_report
call :log_message "Génération du rapport de sécurité"
echo Génération du rapport de sécurité complet...

:: Informations système de sécurité
echo Informations système de sécurité:
systeminfo | findstr /i "security" >> %logfile%

:: Vérification de l'antivirus
echo Vérification de l'antivirus...
wmic /namespace:\\root\securitycenter2 path antivirusproduct get displayname,productstate >> %logfile%

call :log_message "Rapport de sécurité généré"
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
echo  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████
echo  ██░░░                                                                  ░░██
echo  ██░░░  %WHITE%◈ [%icon%] %module_name% ◈ %TEAL%
echo  ██░░░                                                                  ░░██
echo  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████
echo %WHITE%
goto :eof

:display_step_header
set "step=%~1"
set "title=%~2"
set "icon=%~3"
echo.
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %TEAL%  ⡇ %WHITE% ◉ ÉTAPE %step%: %title%
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %WHITE%
goto :eof

:loading_animation
set "text=%~1"
set "frames=0"
echo.
:loading_loop_sec
set /a "percent=frames*5"
set "bar="
set /a "bar_len=percent/5"
for /l %%i in (1,1,!bar_len!) do set "bar=!bar!█"
for /l %%i in (!bar_len!,1,19) do set "bar=!bar! "
<nul set /p "=!ESC![1G%WHITE%  %text%... %TEAL%[!bar!]%WHITE% !percent!%%!ESC![K"
if %frames% equ 20 (
    echo.
    echo  [OK] COMPLETE
    timeout /t 1 >nul
    goto :eof
)
timeout /t 1 >nul
set /a frames+=1
goto loading_loop_sec
@echo off
setlocal enabledelayedexpansion
:: =======================================
:: Module 5 : Sécurité et Pare-feu v1.2
:: Améliorations : Analyses complètes, détection de menaces
:: =======================================

cls
color 0E
set logfile=logs\security_report.txt

:: Fonction de logging
call :log_message "=== Module Sécurité démarré ==="

echo =====================================
echo    Module : Sécurité et Pare-feu
echo =====================================
echo.
echo [*] Analyse de sécurité système...
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
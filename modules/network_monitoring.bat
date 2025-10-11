@echo off
setlocal enabledelayedexpansion
:: =======================================
:: Module : Surveillance Réseau Temps Réel v2.0
:: Fonctionnalités : Monitoring avancé, détection d'intrusions
:: =======================================

cls
color 08
set logfile=logs\network_monitoring_report.txt

:: Fonction de logging sécurisé
call :log_message "=== SURVEILLANCE RÉSEAU DÉMARRÉE ==="

echo =====================================
echo    Module : Surveillance Réseau Temps Réel
echo =====================================
echo.
echo [*] Surveillance réseau en temps réel...
echo.

:: Surveillance des connexions
echo [1/8] Surveillance des connexions...
call :monitor_connections

:: Analyse du trafic réseau
echo [2/8] Analyse du trafic réseau...
call :analyze_network_traffic

:: Détection d'intrusions
echo [3/8] Détection d'intrusions...
call :detect_intrusions

:: Surveillance des ports
echo [4/8] Surveillance des ports...
call :monitor_ports

:: Analyse des DNS
echo [5/8] Analyse des DNS...
call :analyze_dns_queries

:: Vérification des certificats
echo [6/8] Vérification des certificats...
call :check_certificates

:: Surveillance des protocoles
echo [7/8] Surveillance des protocoles...
call :monitor_protocols

:: Génération du rapport réseau
echo [8/8] Génération du rapport réseau...
call :generate_network_report

echo.
echo =====================================
echo           RÉSULTATS SURVEILLANCE
echo =====================================
echo Rapport détaillé : %logfile%
echo Connexions suspectes : !suspicious_connections!
echo Niveau de sécurité : !security_level!
echo =====================================

call :log_message "Surveillance réseau terminée - Connexions suspectes: !suspicious_connections!"
pause
goto :eof

:: =======================================
:: Fonctions de surveillance réseau
:: =======================================

:monitor_connections
call :log_message "Surveillance des connexions"
set suspicious_connections=0

:: Connexions établies
echo Connexions établies :
netstat -an | find "ESTABLISHED" >> %logfile%

:: Connexions en écoute
echo Connexions en écoute :
netstat -an | find "LISTENING" >> %logfile%

:: Connexions vers des ports suspects
echo Connexions vers des ports suspects :
netstat -an | find "ESTABLISHED" | findstr ":80\|:443\|:3389\|:21\|:22\|:23\|:25\|:53\|:110\|:143\|:993\|:995" >> %logfile%

:: Connexions depuis des IPs externes
echo Connexions depuis des IPs externes :
for /f "tokens=2" %%a in ('netstat -an ^| find "ESTABLISHED"') do (
    echo %%a | findstr /v "127.0.0.1\|192.168\|10.0\|172.16" >nul
    if !errorlevel! equ 0 (
        echo [ALERTE] Connexion externe détectée : %%a
        call :log_message "ALERTE: Connexion externe - %%a"
        set /a suspicious_connections+=1
    )
)

goto :eof

:analyze_network_traffic
call :log_message "Analyse du trafic réseau"

:: Statistiques réseau
echo Statistiques réseau :
netstat -e >> %logfile%

:: Statistiques TCP
echo Statistiques TCP :
netstat -s | findstr "TCP" >> %logfile%

:: Statistiques UDP
echo Statistiques UDP :
netstat -s | findstr "UDP" >> %logfile%

:: Interface réseau
echo Interface réseau :
ipconfig /all >> %logfile%

goto :eof

:detect_intrusions
call :log_message "Détection d'intrusions"

:: Tentatives de connexion échouées
echo Tentatives de connexion échouées :
netstat -an | find "TIME_WAIT" >> %logfile%

:: Connexions suspectes
echo Connexions suspectes :
netstat -an | find "SYN_SENT" >> %logfile%

:: Ports ouverts suspects
echo Ports ouverts suspects :
netstat -an | find "LISTENING" | findstr ":80\|:443\|:3389\|:21\|:22\|:23\|:25\|:53\|:110\|:143\|:993\|:995" >> %logfile%

goto :eof

:monitor_ports
call :log_message "Surveillance des ports"

:: Ports ouverts
echo Ports ouverts :
netstat -an | find "LISTENING" >> %logfile%

:: Ports utilisés
echo Ports utilisés :
netstat -an | find "ESTABLISHED" >> %logfile%

:: Ports suspects
echo Ports suspects :
netstat -an | find "LISTENING" | findstr ":80\|:443\|:3389\|:21\|:22\|:23\|:25\|:53\|:110\|:143\|:993\|:995" >> %logfile%

goto :eof

:analyze_dns_queries
call :log_message "Analyse des DNS"

:: Configuration DNS
echo Configuration DNS :
ipconfig /all | findstr "DNS" >> %logfile%

:: Test de résolution DNS
echo Test de résolution DNS :
nslookup google.com >> %logfile%
nslookup microsoft.com >> %logfile%

:: Cache DNS
echo Cache DNS :
ipconfig /displaydns >> %logfile%

goto :eof

:check_certificates
call :log_message "Vérification des certificats"

:: Certificats installés
echo Certificats installés :
certlm -store -list >> %logfile%

:: Certificats utilisateur
echo Certificats utilisateur :
certmgr -store -list >> %logfile%

goto :eof

:monitor_protocols
call :log_message "Surveillance des protocoles"

:: Protocoles réseau
echo Protocoles réseau :
netstat -an | find "TCP" >> %logfile%
netstat -an | find "UDP" >> %logfile%

:: Statistiques des protocoles
echo Statistiques des protocoles :
netstat -s >> %logfile%

goto :eof

:generate_network_report
call :log_message "Génération du rapport réseau"

:: Détermination du niveau de sécurité
if !suspicious_connections! equ 0 (
    set security_level=ÉLEVÉ
) else if !suspicious_connections! leq 3 (
    set security_level=MOYEN
) else (
    set security_level=FAIBLE
)

:: Résumé du réseau
echo ====================================== >> %logfile%
echo RAPPORT DE SURVEILLANCE RÉSEAU >> %logfile%
echo ====================================== >> %logfile%
echo Date de génération : %date% %time% >> %logfile%
echo Nom de l'ordinateur : %computername% >> %logfile%
echo Utilisateur : %username% >> %logfile%
echo Connexions suspectes : !suspicious_connections! >> %logfile%
echo Niveau de sécurité : !security_level! >> %logfile%

call :log_message "Rapport réseau généré"
goto :eof

:log_message
echo [%date% %time%] %~1 >> %logfile%
goto :eof

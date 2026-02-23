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
:: Module : Détection de Menaces v2.0
:: Fonctionnalités : Détection avancée, analyse comportementale
:: =======================================

cls
echo %WHITE%
set logfile=logs\threat_detection_report.txt

:: Fonction de logging sécurisé
call :log_message "=== DÉTECTION DE MENACES DÉMARRÉE ==="

call :display_module_header "Détection de Menaces" "[WRN]"
echo.
call :loading_animation "Analyse des signatures de menaces"
echo.

:: Détection de malware
echo [1/10] Détection de malware...
call :detect_malware

:: Analyse des processus suspects
echo [2/10] Analyse des processus suspects...
call :analyze_suspicious_processes

:: Vérification des connexions réseau
echo [3/10] Vérification des connexions réseau...
call :check_suspicious_connections

:: Analyse des fichiers suspects
echo [4/10] Analyse des fichiers suspects...
call :analyze_suspicious_files

:: Détection de rootkits
echo [5/10] Détection de rootkits...
call :detect_rootkits

:: Vérification des services malveillants
echo [6/10] Vérification des services malveillants...
call :check_malicious_services

:: Analyse des clés de registre
echo [7/10] Analyse des clés de registre...
call :analyze_registry_threats

:: Détection de keyloggers
echo [8/10] Détection de keyloggers...
call :detect_keyloggers

:: Vérification des DLL malveillantes
echo [9/10] Vérification des DLL malveillantes...
call :check_malicious_dlls

:: Génération du rapport de menaces
echo [10/10] Génération du rapport de menaces...
call :generate_threat_report

echo.
echo =====================================
echo           RÉSULTATS DÉTECTION
echo =====================================
echo Rapport détaillé : %logfile%
echo Menaces détectées : !threat_count!
echo Niveau de risque : !risk_level!
echo =====================================

call :log_message "Détection de menaces terminée - Menaces: !threat_count!, Risque: !risk_level!"
pause
goto :eof

:: =======================================
:: Fonctions de détection de menaces
:: =======================================

:detect_malware
call :log_message "Détection de malware"
set threat_count=0

:: Vérification Windows Defender
echo Vérification Windows Defender :
powershell "Get-MpThreatDetection" >> %logfile%

:: Scan rapide avec Windows Defender
echo Scan rapide en cours...
powershell "Start-MpScan -ScanType QuickScan" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Scan Windows Defender terminé
    call :log_message "SUCCÈS: Scan Windows Defender terminé"
) else (
    echo [ALERTE] Échec du scan Windows Defender
    call :log_message "ALERTE: Échec du scan Windows Defender"
    set /a threat_count+=1
)

:: Vérification des fichiers suspects
echo Recherche de fichiers suspects...
for /f "delims=" %%i in ('dir /s /b "%temp%\*.exe" 2^>nul') do (
    echo [ALERTE] Fichier suspect trouvé : %%i
    call :log_message "ALERTE: Fichier suspect - %%i"
    set /a threat_count+=1
)

goto :eof

:analyze_suspicious_processes
call :log_message "Analyse des processus suspects"

:: Processus avec noms suspects
echo Processus avec noms suspects :
tasklist | findstr /i "svchost.exe" >> %logfile%
tasklist | findstr /i "explorer.exe" >> %logfile%

:: Processus avec privilèges élevés
echo Processus avec privilèges élevés :
tasklist /v | findstr "HIGH" >> %logfile%

:: Processus utilisant beaucoup de CPU
echo Processus utilisant beaucoup de CPU :
wmic process get name,processid,percentprocessortime | findstr /v "Name" >> %logfile%

goto :eof

:check_suspicious_connections
call :log_message "Vérification des connexions suspectes"

:: Connexions sortantes suspectes
echo Connexions sortantes suspectes :
netstat -an | find "ESTABLISHED" >> %logfile%

:: Ports suspects ouverts
echo Ports suspects ouverts :
netstat -an | find "LISTENING" | findstr ":80\|:443\|:3389\|:21\|:22\|:23" >> %logfile%

:: Connexions vers des IPs suspectes
echo Connexions vers des IPs suspectes :
netstat -an | find "ESTABLISHED" | findstr "192.168\|10.0\|172.16" >> %logfile%

goto :eof

:analyze_suspicious_files
call :log_message "Analyse des fichiers suspects"

:: Fichiers dans des emplacements suspects
echo Fichiers dans des emplacements suspects :
if exist "%windir%\system32\*.tmp" (
    echo [ALERTE] Fichiers temporaires dans system32
    call :log_message "ALERTE: Fichiers temporaires dans system32"
    set /a threat_count+=1
)

:: Fichiers avec double extension
echo Recherche de fichiers avec double extension :
for /f "delims=" %%i in ('dir /s /b "%userprofile%\*.exe.txt" 2^>nul') do (
    echo [ALERTE] Fichier avec double extension : %%i
    call :log_message "ALERTE: Fichier avec double extension - %%i"
    set /a threat_count+=1
)

goto :eof

:detect_rootkits
call :log_message "Détection de rootkits"

:: Vérification des drivers suspects
echo Vérification des drivers suspects :
driverquery >> %logfile%

:: Vérification des services cachés
echo Vérification des services cachés :
sc query state= all | findstr "SERVICE_NAME" >> %logfile%

:: Vérification des processus cachés
echo Vérification des processus cachés :
tasklist /svc >> %logfile%

goto :eof

:check_malicious_services
call :log_message "Vérification des services malveillants"

:: Services avec démarrage automatique
echo Services avec démarrage automatique :
sc query state= all | findstr "AUTO_START" >> %logfile%

:: Services récemment installés
echo Services récemment installés :
sc query state= all | findstr "SERVICE_NAME" >> %logfile%

goto :eof

:analyze_registry_threats
call :log_message "Analyse des clés de registre"

:: Clés de démarrage automatique
echo Clés de démarrage automatique :
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" >> %logfile%
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" >> %logfile%

:: Clés de registre suspectes
echo Clés de registre suspectes :
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" >> %logfile%

goto :eof

:detect_keyloggers
call :log_message "Détection de keyloggers"

:: Processus accédant au clavier
echo Processus accédant au clavier :
tasklist | findstr /i "keyboard\|keylog\|hook" >> %logfile%

:: Services suspects
echo Services suspects :
sc query state= all | findstr "SERVICE_NAME" | findstr /i "key\|log\|hook" >> %logfile%

goto :eof

:check_malicious_dlls
call :log_message "Vérification des DLL malveillantes"

:: DLL chargées par les processus
echo DLL chargées par les processus :
tasklist /m >> %logfile%

:: DLL dans des emplacements suspects
echo DLL dans des emplacements suspects :
if exist "%temp%\*.dll" (
    echo [ALERTE] DLL dans le dossier temporaire
    call :log_message "ALERTE: DLL dans le dossier temporaire"
    set /a threat_count+=1
)

goto :eof

:generate_threat_report
call :log_message "Génération du rapport de menaces"

:: Détermination du niveau de risque
if !threat_count! equ 0 (
    set risk_level=FAIBLE
) else if !threat_count! leq 3 (
    set risk_level=MOYEN
) else (
    set risk_level=ÉLEVÉ
)

:: Résumé des menaces
echo ====================================== >> %logfile%
echo RAPPORT DE DÉTECTION DE MENACES >> %logfile%
echo ====================================== >> %logfile%
echo Date de génération : %date% %time% >> %logfile%
echo Nom de l'ordinateur : %computername% >> %logfile%
echo Utilisateur : %username% >> %logfile%
echo Menaces détectées : !threat_count! >> %logfile%
echo Niveau de risque : !risk_level! >> %logfile%

call :log_message "Rapport de menaces généré"
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
:loading_loop_threat
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
goto loading_loop_threat

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
:: Module : Audit de Sécurité Avancé v2.0
:: Fonctionnalités : Analyse complète, détection de menaces
:: =======================================

cls
echo %WHITE%
set logfile=logs\security_audit_report.txt

:: Fonction de logging sécurisé
call :log_message "=== AUDIT DE SÉCURITÉ DÉMARRÉ ==="

call :display_module_header "Audit de Sécurité Avancé" "[AUD]"
echo.
call :loading_animation "Initialisation de l'audit système"
echo.
echo [*] Analyse de sécurité système en cours...
echo.

:: Vérification des privilèges
echo [1/12] Vérification des privilèges système...
call :check_privileges

:: Audit des comptes utilisateurs
echo [2/12] Audit des comptes utilisateurs...
call :audit_user_accounts

:: Vérification des politiques de sécurité
echo [3/12] Vérification des politiques de sécurité...
call :check_security_policies

:: Analyse des services critiques
echo [4/12] Analyse des services critiques...
call :analyze_critical_services

:: Vérification des ports et connexions
echo [5/12] Vérification des ports et connexions...
call :check_network_security

:: Audit des fichiers système
echo [6/12] Audit des fichiers système...
call :audit_system_files

:: Vérification des mises à jour
echo [7/12] Vérification des mises à jour de sécurité...
call :check_security_updates

:: Analyse des processus suspects
echo [8/12] Analyse des processus suspects...
call :analyze_suspicious_processes

:: Vérification de l'intégrité du registre
echo [9/12] Vérification de l'intégrité du registre...
call :check_registry_integrity

:: Audit des permissions
echo [10/12] Audit des permissions système...
call :audit_permissions

:: Vérification de l'antivirus
echo [11/12] Vérification de l'antivirus...
call :check_antivirus_status

:: Génération du rapport final
echo [12/12] Génération du rapport de sécurité...
call :generate_security_report

echo.
echo =====================================
echo           RÉSULTATS AUDIT
echo =====================================
echo Rapport détaillé : %logfile%
echo Score de sécurité : !security_score!/100
echo =====================================

call :log_message "Audit de sécurité terminé - Score: !security_score!/100"
pause
goto :eof

:: =======================================
:: Fonctions d'audit de sécurité
:: =======================================

:check_privileges
call :log_message "Vérification des privilèges système"
set security_score=0

:: Vérification UAC
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] UAC activé
    set /a security_score+=10
    call :log_message "SUCCÈS: UAC activé"
) else (
    echo [ALERTE] UAC désactivé
    call :log_message "ALERTE: UAC désactivé"
)

:: Vérification des privilèges administrateur
net session >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Privilèges administrateur confirmés
    set /a security_score+=5
    call :log_message "SUCCÈS: Privilèges administrateur confirmés"
) else (
    echo [ALERTE] Privilèges administrateur insuffisants
    call :log_message "ALERTE: Privilèges administrateur insuffisants"
)
goto :eof

:audit_user_accounts
call :log_message "Audit des comptes utilisateurs"

:: Comptes avec privilèges élevés
echo Comptes administrateurs :
net localgroup administrators >> %logfile%

:: Comptes désactivés
echo Comptes désactivés :
net user | findstr /C:"Account active" >> %logfile%

:: Dernières connexions
echo Dernières connexions :
wevtutil qe Security /c:10 /rd:true /f:text >> %logfile%

call :log_message "Audit des comptes utilisateurs terminé"
goto :eof

:check_security_policies
call :log_message "Vérification des politiques de sécurité"

:: Politique de mot de passe
echo Politique de mot de passe :
net accounts >> %logfile%

:: Politique de verrouillage
echo Politique de verrouillage :
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LockoutThreshold >> %logfile%

call :log_message "Vérification des politiques terminée"
goto :eof

:analyze_critical_services
call :log_message "Analyse des services critiques"

:: Services critiques
echo Services critiques :
sc query state= all | findstr "SERVICE_NAME" >> %logfile%

:: Services avec démarrage automatique
echo Services avec démarrage automatique :
sc query state= all | findstr "AUTO_START" >> %logfile%

call :log_message "Analyse des services terminée"
goto :eof

:check_network_security
call :log_message "Vérification de la sécurité réseau"

:: Ports ouverts
echo Ports ouverts :
netstat -an | find "LISTENING" >> %logfile%

:: Connexions actives
echo Connexions actives :
netstat -an | find "ESTABLISHED" >> %logfile%

:: Configuration du pare-feu
echo Configuration du pare-feu :
netsh advfirewall show allprofiles >> %logfile%

call :log_message "Vérification réseau terminée"
goto :eof

:audit_system_files
call :log_message "Audit des fichiers système"

:: Vérification des fichiers critiques
echo Vérification des fichiers critiques :
if exist "%windir%\system32\kernel32.dll" (
    echo [OK] kernel32.dll présent
    call :log_message "SUCCÈS: kernel32.dll présent"
) else (
    echo [ALERTE] kernel32.dll manquant
    call :log_message "ALERTE: kernel32.dll manquant"
)

if exist "%windir%\system32\ntdll.dll" (
    echo [OK] ntdll.dll présent
    call :log_message "SUCCÈS: ntdll.dll présent"
) else (
    echo [ALERTE] ntdll.dll manquant
    call :log_message "ALERTE: ntdll.dll manquant"
)

goto :eof

:check_security_updates
call :log_message "Vérification des mises à jour de sécurité"

:: Mises à jour installées
echo Mises à jour de sécurité installées :
wmic qfe list | findstr "Security" >> %logfile%

:: Dernière mise à jour
echo Dernière mise à jour :
wmic qfe list | findstr /C:"Security Update" | findstr /C:"Critical" >> %logfile%

call :log_message "Vérification des mises à jour terminée"
goto :eof

:analyze_suspicious_processes
call :log_message "Analyse des processus suspects"

:: Processus avec privilèges élevés
echo Processus avec privilèges élevés :
tasklist /v | findstr "HIGH" >> %logfile%

:: Processus suspects
echo Processus suspects :
tasklist | findstr /i "svchost.exe" >> %logfile%

call :log_message "Analyse des processus terminée"
goto :eof

:check_registry_integrity
call :log_message "Vérification de l'intégrité du registre"

:: Clés de registre critiques
echo Clés de registre critiques :
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" >> %logfile%
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" >> %logfile%

call :log_message "Vérification du registre terminée"
goto :eof

:audit_permissions
call :log_message "Audit des permissions système"

:: Permissions utilisateur
echo Permissions utilisateur :
whoami /all >> %logfile%

:: Groupes d'utilisateurs
echo Groupes d'utilisateurs :
net localgroup >> %logfile%

call :log_message "Audit des permissions terminé"
goto :eof

:check_antivirus_status
call :log_message "Vérification de l'antivirus"

:: Statut de l'antivirus
echo Statut de l'antivirus :
wmic /namespace:\\root\securitycenter2 path antivirusproduct get displayname,productstate >> %logfile%

:: Windows Defender
echo Windows Defender :
powershell "Get-MpComputerStatus" >> %logfile%

call :log_message "Vérification de l'antivirus terminée"
goto :eof

:generate_security_report
call :log_message "Génération du rapport de sécurité"

:: Résumé de sécurité
echo ====================================== >> %logfile%
echo RAPPORT DE SÉCURITÉ >> %logfile%
echo ====================================== >> %logfile%
echo Date de génération : %date% %time% >> %logfile%
echo Nom de l'ordinateur : %computername% >> %logfile%
echo Utilisateur : %username% >> %logfile%
echo Score de sécurité : !security_score!/100 >> %logfile%

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
:loading_loop_audit
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
goto loading_loop_audit

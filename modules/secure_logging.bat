@echo off
setlocal enabledelayedexpansion
:: =======================================
:: Module : Journalisation Sécurisée v2.0
:: Fonctionnalités : Logging avancé, rotation, chiffrement
:: =======================================

cls
color 0A
set logfile=logs\secure_logging_report.txt

:: Fonction de logging sécurisé
call :log_message "=== JOURNALISATION SÉCURISÉE DÉMARRÉE ==="

echo =====================================
echo    Module : Journalisation Sécurisée
echo =====================================
echo.
echo [1] Configurer la journalisation
echo [2] Visualiser les logs
echo [3] Rotation des logs
echo [4] Chiffrer les logs
echo [5] Analyser les logs
echo [6] Nettoyer les logs
echo [7] Surveiller les logs en temps réel
echo [8] Retour au menu principal
echo =====================================
echo.
set /p option="Entrez votre choix (1-8) : "

:: Validation de l'option
if "%option%"=="" goto invalid_option
if "%option%" lss "1" goto invalid_option
if "%option%" gtr "8" goto invalid_option

if "%option%"=="1" (
    call :configure_logging
) else if "%option%"=="2" (
    call :view_logs
) else if "%option%"=="3" (
    call :rotate_logs
) else if "%option%"=="4" (
    call :encrypt_logs
) else if "%option%"=="5" (
    call :analyze_logs
) else if "%option%"=="6" (
    call :clean_logs
) else if "%option%"=="7" (
    call :monitor_logs
) else if "%option%"=="8" (
    goto :eof
)

pause
goto :eof

:invalid_option
call :log_message "ERREUR: Option invalide sélectionnée: %option%"
echo [ERREUR] Option invalide. Veuillez choisir entre 1 et 8.
pause
exit /b 1

:: =======================================
:: Fonctions de journalisation sécurisée
:: =======================================

:configure_logging
echo.
echo === CONFIGURATION DE LA JOURNALISATION ===
echo [1] Activer la journalisation avancée
echo [2] Configurer les niveaux de log
echo [3] Définir les répertoires de logs
echo [4] Configurer la rotation automatique
echo [5] Retour
echo.
set /p config_option="Choisissez une option (1-5) : "

if "%config_option%"=="1" (
    call :enable_advanced_logging
) else if "%config_option%"=="2" (
    call :configure_log_levels
) else if "%config_option%"=="3" (
    call :configure_log_directories
) else if "%config_option%"=="4" (
    call :configure_log_rotation
) else if "%config_option%"=="5" (
    goto :eof
)
goto :eof

:enable_advanced_logging
echo.
echo === ACTIVATION DE LA JOURNALISATION AVANCÉE ===
echo Activation de la journalisation avancée...

:: Création du dossier de logs sécurisé
if not exist "logs\secure" mkdir "logs\secure" >nul 2>&1

:: Configuration des permissions
icacls "logs\secure" /grant:r "%username%:(OI)(CI)F" >nul 2>&1

:: Activation du logging système
wevtutil sl Security /e:true >nul 2>&1
wevtutil sl System /e:true >nul 2>&1
wevtutil sl Application /e:true >nul 2>&1

call :log_message "SUCCÈS: Journalisation avancée activée"
echo [SUCCÈS] Journalisation avancée activée !
goto :eof

:configure_log_levels
echo.
echo === CONFIGURATION DES NIVEAUX DE LOG ===
echo Niveaux disponibles :
echo [1] DEBUG - Tous les messages
echo [2] INFO - Messages informatifs
echo [3] WARNING - Avertissements
echo [4] ERROR - Erreurs uniquement
echo [5] CRITICAL - Messages critiques uniquement
echo.
set /p log_level="Choisissez un niveau (1-5) : "

if "%log_level%"=="1" (
    set log_level_name=DEBUG
) else if "%log_level%"=="2" (
    set log_level_name=INFO
) else if "%log_level%"=="3" (
    set log_level_name=WARNING
) else if "%log_level%"=="4" (
    set log_level_name=ERROR
) else if "%log_level%"=="5" (
    set log_level_name=CRITICAL
) else (
    echo [ERREUR] Niveau invalide !
    goto :eof
)

echo Niveau de log configuré : %log_level_name%
call :log_message "SUCCÈS: Niveau de log configuré - %log_level_name%"
goto :eof

:configure_log_directories
echo.
echo === CONFIGURATION DES RÉPERTOIRES DE LOGS ===
set /p log_dir="Entrez le répertoire de logs (par défaut: logs\secure) : "
if "%log_dir%"=="" set log_dir=logs\secure

if not exist "%log_dir%" (
    mkdir "%log_dir%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERREUR] Impossible de créer le répertoire !
        goto :eof
    )
)

:: Configuration des permissions
icacls "%log_dir%" /grant:r "%username%:(OI)(CI)F" >nul 2>&1

echo Répertoire de logs configuré : %log_dir%
call :log_message "SUCCÈS: Répertoire de logs configuré - %log_dir%"
goto :eof

:configure_log_rotation
echo.
echo === CONFIGURATION DE LA ROTATION ===
set /p max_size="Taille maximale des logs en MB (par défaut: 100) : "
if "%max_size%"=="" set max_size=100

set /p max_files="Nombre maximum de fichiers (par défaut: 10) : "
if "%max_files%"=="" set max_files=10

echo Rotation configurée :
echo - Taille maximale : %max_size% MB
echo - Nombre maximum de fichiers : %max_files%
call :log_message "SUCCÈS: Rotation configurée - Taille: %max_size%MB, Fichiers: %max_files%"
goto :eof

:view_logs
echo.
echo === VISUALISATION DES LOGS ===
echo [1] Logs système
echo [2] Logs de sécurité
echo [3] Logs d'application
echo [4] Logs WinToolBox
echo [5] Rechercher dans les logs
echo [6] Retour
echo.
set /p view_option="Choisissez une option (1-6) : "

if "%view_option%"=="1" (
    call :view_system_logs
) else if "%view_option%"=="2" (
    call :view_security_logs
) else if "%view_option%"=="3" (
    call :view_application_logs
) else if "%view_option%"=="4" (
    call :view_wintoolbox_logs
) else if "%view_option%"=="5" (
    call :search_logs
) else if "%view_option%"=="6" (
    goto :eof
)
goto :eof

:view_system_logs
echo.
echo === LOGS SYSTÈME ===
echo Derniers événements système :
wevtutil qe System /c:10 /rd:true /f:text
goto :eof

:view_security_logs
echo.
echo === LOGS DE SÉCURITÉ ===
echo Derniers événements de sécurité :
wevtutil qe Security /c:10 /rd:true /f:text
goto :eof

:view_application_logs
echo.
echo === LOGS D'APPLICATION ===
echo Derniers événements d'application :
wevtutil qe Application /c:10 /rd:true /f:text
goto :eof

:view_wintoolbox_logs
echo.
echo === LOGS WINTOOLBOX ===
echo Logs WinToolBox :
if exist "logs\*.txt" (
    for %%f in (logs\*.txt) do (
        echo.
        echo === %%~nf ===
        type "%%f" | more
    )
) else (
    echo Aucun log WinToolBox trouvé.
)
goto :eof

:search_logs
echo.
echo === RECHERCHE DANS LES LOGS ===
set /p search_term="Entrez le terme de recherche : "
if "%search_term%"=="" (
    echo [ERREUR] Terme de recherche vide !
    goto :eof
)

echo Recherche de "%search_term%" dans les logs...
findstr /i "%search_term%" logs\*.txt
goto :eof

:rotate_logs
echo.
echo === ROTATION DES LOGS ===
echo Rotation des logs en cours...

:: Rotation des logs WinToolBox
for %%f in (logs\*.txt) do (
    set "filename=%%~nf"
    set "extension=%%~xf"
    set "timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "timestamp=!timestamp: =0!"
    
    if exist "logs\!filename!!extension!" (
        move "logs\!filename!!extension!" "logs\!filename!_!timestamp!!extension!" >nul 2>&1
        echo Log archivé : !filename!!extension!
    )
)

call :log_message "SUCCÈS: Rotation des logs terminée"
echo [SUCCÈS] Rotation des logs terminée !
goto :eof

:encrypt_logs
echo.
echo === CHIFFREMENT DES LOGS ===
set /p log_file="Entrez le chemin du fichier de log à chiffrer : "
if not exist "%log_file%" (
    echo [ERREUR] Le fichier de log n'existe pas !
    goto :eof
)

set /p encrypted_file="Entrez le chemin du fichier chiffré : "

echo Chiffrement du log en cours...
powershell "Get-Content '%log_file%' | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File '%encrypted_file%'"
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Log chiffré - %log_file%"
    echo [SUCCÈS] Log chiffré avec succès !
) else (
    call :log_message "ERREUR: Échec du chiffrement - %log_file%"
    echo [ERREUR] Échec du chiffrement !
)
goto :eof

:analyze_logs
echo.
echo === ANALYSE DES LOGS ===
echo [1] Analyser les erreurs
echo [2] Analyser les avertissements
echo [3] Analyser les événements de sécurité
echo [4] Générer un rapport d'analyse
echo [5] Retour
echo.
set /p analyze_option="Choisissez une option (1-5) : "

if "%analyze_option%"=="1" (
    call :analyze_errors
) else if "%analyze_option%"=="2" (
    call :analyze_warnings
) else if "%analyze_option%"=="3" (
    call :analyze_security_events
) else if "%analyze_option%"=="4" (
    call :generate_analysis_report
) else if "%analyze_option%"=="5" (
    goto :eof
)
goto :eof

:analyze_errors
echo.
echo === ANALYSE DES ERREURS ===
echo Recherche des erreurs dans les logs...
findstr /i "error\|erreur\|failed\|échec" logs\*.txt
goto :eof

:analyze_warnings
echo.
echo === ANALYSE DES AVERTISSEMENTS ===
echo Recherche des avertissements dans les logs...
findstr /i "warning\|avertissement\|warn" logs\*.txt
goto :eof

:analyze_security_events
echo.
echo === ANALYSE DES ÉVÉNEMENTS DE SÉCURITÉ ===
echo Recherche des événements de sécurité dans les logs...
findstr /i "security\|sécurité\|login\|logout\|access\|accès" logs\*.txt
goto :eof

:generate_analysis_report
echo.
echo === GÉNÉRATION DU RAPPORT D'ANALYSE ===
set analysis_report=logs\log_analysis_report.txt

echo Génération du rapport d'analyse...
echo ====================================== > %analysis_report%
echo RAPPORT D'ANALYSE DES LOGS >> %analysis_report%
echo ====================================== >> %analysis_report%
echo Date de génération : %date% %time% >> %analysis_report%
echo Nom de l'ordinateur : %computername% >> %analysis_report%
echo Utilisateur : %username% >> %analysis_report%
echo. >> %analysis_report%

echo === ERREURS === >> %analysis_report%
findstr /i "error\|erreur\|failed\|échec" logs\*.txt >> %analysis_report%
echo. >> %analysis_report%

echo === AVERTISSEMENTS === >> %analysis_report%
findstr /i "warning\|avertissement\|warn" logs\*.txt >> %analysis_report%
echo. >> %analysis_report%

echo === ÉVÉNEMENTS DE SÉCURITÉ === >> %analysis_report%
findstr /i "security\|sécurité\|login\|logout\|access\|accès" logs\*.txt >> %analysis_report%

call :log_message "SUCCÈS: Rapport d'analyse généré - %analysis_report%"
echo [SUCCÈS] Rapport d'analyse généré : %analysis_report%
goto :eof

:clean_logs
echo.
echo === NETTOYAGE DES LOGS ===
echo [1] Nettoyer les logs anciens
echo [2] Supprimer les logs vides
echo [3] Compresser les logs
echo [4] Retour
echo.
set /p clean_option="Choisissez une option (1-4) : "

if "%clean_option%"=="1" (
    call :clean_old_logs
) else if "%clean_option%"=="2" (
    call :clean_empty_logs
) else if "%clean_option%"=="3" (
    call :compress_logs
) else if "%clean_option%"=="4" (
    goto :eof
)
goto :eof

:clean_old_logs
echo.
echo === NETTOYAGE DES LOGS ANCIENS ===
set /p days="Entrez le nombre de jours (par défaut: 30) : "
if "%days%"=="" set days=30

echo Suppression des logs de plus de %days% jours...
forfiles /p logs /s /m *.txt /d -%days% /c "cmd /c del @path" >nul 2>&1

call :log_message "SUCCÈS: Logs anciens nettoyés - %days% jours"
echo [SUCCÈS] Logs anciens nettoyés !
goto :eof

:clean_empty_logs
echo.
echo === NETTOYAGE DES LOGS VIDES ===
echo Suppression des logs vides...
for %%f in (logs\*.txt) do (
    if %%~zf equ 0 (
        del "%%f" >nul 2>&1
        echo Log vide supprimé : %%f
    )
)

call :log_message "SUCCÈS: Logs vides nettoyés"
echo [SUCCÈS] Logs vides nettoyés !
goto :eof

:compress_logs
echo.
echo === COMPRESSION DES LOGS ===
echo Compression des logs en cours...
for %%f in (logs\*.txt) do (
    if not "%%~nf"=="log_analysis_report" (
        powershell "Compress-Archive -Path '%%f' -DestinationPath 'logs\%%~nf.zip' -Force"
        if !errorlevel! equ 0 (
            del "%%f" >nul 2>&1
            echo Log compressé : %%f
        )
    )
)

call :log_message "SUCCÈS: Logs compressés"
echo [SUCCÈS] Logs compressés !
goto :eof

:monitor_logs
echo.
echo === SURVEILLANCE DES LOGS EN TEMPS RÉEL ===
echo Surveillance des logs en temps réel...
echo Appuyez sur Ctrl+C pour arrêter.
echo.

:: Surveillance des logs WinToolBox
echo [INFO] Démarrage de la surveillance...
echo [INFO] Surveillance active pendant 30 secondes...
echo.

:: Surveillance limitée dans le temps
for /l %%i in (1,1,6) do (
    echo [%time%] Cycle de surveillance %%i/6
    if exist "logs\*.txt" (
        for %%f in (logs\*.txt) do (
            echo   - Log détecté : %%f
        )
    ) else (
        echo   - Aucun log trouvé
    )
    timeout /t 5 >nul
)

echo.
echo [INFO] Surveillance terminée.
call :log_message "SUCCÈS: Surveillance des logs terminée"
goto :eof

:log_message
echo [%date% %time%] %~1 >> %logfile%
goto :eof

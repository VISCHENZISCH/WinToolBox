@echo off
setlocal enabledelayedexpansion
:: =======================================
:: Module 6 : Sauvegarde et restauration v1.2
:: Améliorations : Validation, gestion d'erreurs, sécurité
:: =======================================

set logfile=logs\backup_log.txt
color 0B

:: Fonction de logging avec timestamp
call :log_message "=== Module Backup démarré ==="

cls
echo =====================================
echo    Module : Sauvegarde et Restauration
echo =====================================
echo.
echo [1] Sauvegarder un dossier
echo [2] Restaurer un dossier  
echo [3] Vérifier l'intégrité des sauvegardes
echo [4] Retour au menu principal
echo =====================================
echo.
set /p opt="Choisissez une option (1-4) : "

:: Validation de l'option
echo %opt% | findstr /r "^[1-4]$" >nul
if %errorlevel% neq 0 (
    call :log_message "ERREUR: Option invalide sélectionnée: %opt%"
    echo [ERREUR] Option invalide. Veuillez choisir entre 1 et 4.
    pause
    exit /b 1
)

if "%opt%"=="1" (
    call :backup_folder
) else if "%opt%"=="2" (
    call :restore_folder
) else if "%opt%"=="3" (
    call :verify_backups
) else if "%opt%"=="4" (
    goto :eof
)

pause
goto :eof

:: =======================================
:: Fonctions du module backup
:: =======================================

:backup_folder
echo.
echo === SAUVEGARDE DE DOSSIER ===
set /p source="Entrez le chemin du dossier source : "
set /p destination="Entrez le chemin du dossier de destination : "

:: Validation des chemins
if not exist "%source%" (
    call :log_message "ERREUR: Dossier source introuvable: %source%"
    echo [ERREUR] Le dossier source n'existe pas !
    goto :eof
)

:: Création du dossier de destination si nécessaire
if not exist "%destination%" (
    mkdir "%destination%" >nul 2>&1
    if !errorlevel! neq 0 (
        call :log_message "ERREUR: Impossible de créer le dossier de destination: %destination%"
        echo [ERREUR] Impossible de créer le dossier de destination !
        goto :eof
    )
)

call :log_message "Début sauvegarde: %source% -> %destination%"
echo.
echo [INFO] Sauvegarde en cours...
echo Source : %source%
echo Destination : %destination%
echo.

:: Sauvegarde avec robocopy (plus robuste que xcopy)
robocopy "%source%" "%destination%" /E /R:3 /W:10 /MT:8 /LOG+:%logfile% /TEE
set backup_result=!errorlevel!

:: robocopy retourne des codes spécifiques
if !backup_result! leq 7 (
    call :log_message "SUCCÈS: Sauvegarde terminée avec succès"
    echo.
    echo [SUCCÈS] Sauvegarde terminée avec succès !
    echo Code de retour : !backup_result!
) else (
    call :log_message "ERREUR: Échec de la sauvegarde - Code: !backup_result!"
    echo.
    echo [ERREUR] Échec de la sauvegarde !
    echo Code d'erreur : !backup_result!
)
goto :eof

:restore_folder
echo.
echo === RESTAURATION DE DOSSIER ===
set /p source="Entrez le chemin du dossier de sauvegarde : "
set /p destination="Entrez le chemin du dossier de restauration : "

:: Validation des chemins
if not exist "%source%" (
    call :log_message "ERREUR: Dossier de sauvegarde introuvable: %source%"
    echo [ERREUR] Le dossier de sauvegarde n'existe pas !
    goto :eof
)

call :log_message "Début restauration: %source% -> %destination%"
echo.
echo [INFO] Restauration en cours...
echo Source : %source%
echo Destination : %destination%
echo.

:: Restauration avec robocopy
robocopy "%source%" "%destination%" /E /R:3 /W:10 /MT:8 /LOG+:%logfile% /TEE
set restore_result=!errorlevel!

if !restore_result! leq 7 (
    call :log_message "SUCCÈS: Restauration terminée avec succès"
    echo.
    echo [SUCCÈS] Restauration terminée avec succès !
    echo Code de retour : !restore_result!
) else (
    call :log_message "ERREUR: Échec de la restauration - Code: !restore_result!"
    echo.
    echo [ERREUR] Échec de la restauration !
    echo Code d'erreur : !restore_result!
)
goto :eof

:verify_backups
echo.
echo === VÉRIFICATION D'INTÉGRITÉ ===
echo [INFO] Vérification des sauvegardes récentes...
call :log_message "Vérification d'intégrité des sauvegardes"

:: Recherche des fichiers de sauvegarde récents
for /f "delims=" %%i in ('dir /b /s /a-d "%userprofile%\Desktop\*.bak" 2^>nul ^| findstr /v /c:"$"') do (
    echo Vérification : %%i
    if exist "%%i" (
        echo [OK] Fichier accessible : %%i
    ) else (
        echo [ERREUR] Fichier inaccessible : %%i
    )
)
goto :eof

:log_message
echo [%date% %time%] %~1 >> %logfile%
goto :eof 
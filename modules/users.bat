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
:: Module 4 : Gestion des Utilisateurs v1.2
:: Améliorations : Validation, sécurité, gestion d'erreurs
:: =======================================

cls
echo %WHITE%
set "logfile=logs\users_report.txt"

:: Fonction de logging
call :log_message "=== Module Utilisateurs démarré ==="

cls
call :display_module_header "Gestion des Utilisateurs" "[USR]"
echo.
call :loading_animation "Analyse des profils utilisateurs"
echo.
echo [1] Lister les utilisateurs
echo [2] Ajouter un utilisateur
echo [3] Supprimer un utilisateur
echo [4] Modifier un utilisateur
echo [5] Vérifier les groupes d'utilisateurs
echo [6] Retour au menu principal
echo =====================================
echo.
set /p option="Entrez votre choix (1-6) : "

:: Validation de l'option
echo %option% | findstr /r "^[1-6]$" >nul
if %errorlevel% neq 0 (
    call :log_message "ERREUR: Option invalide sélectionnée: %option%"
    echo [ERREUR] Option invalide. Veuillez choisir entre 1 et 6.
    pause
    exit /b 1
)

if "%option%"=="1" (
    call :list_users
) else if "%option%"=="2" (
 cd /Users   call :add_user
) else if "%option%"=="3" (
    call :delete_user
) else if "%option%"=="4" (
    call :modify_user
) else if "%option%"=="5" (
    call :check_user_groups
) else if "%option%"=="6" (
    goto :eof
)

pause
goto :eof

:: =======================================
:: Fonctions du module utilisateurs
:: =======================================

:list_users
echo.
echo === LISTE DES UTILISATEURS ===
call :log_message "Liste des utilisateurs demandée"
echo Rapport généré le %date% à %time% > %logfile%
echo =================================== >> %logfile%
net user >> %logfile%
echo [INFO] Liste des utilisateurs sauvegardée dans %logfile%
goto :eof

:add_user
echo.
echo === AJOUT D'UN UTILISATEUR ===
set /p username="Entrez le nom du nouvel utilisateur : "

:: Validation du nom d'utilisateur
if "%username%"=="" (
    call :log_message "ERREUR: Nom d'utilisateur vide"
    echo [ERREUR] Le nom d'utilisateur ne peut pas être vide !
    goto :eof
)

:: Vérification si l'utilisateur existe déjà
net user "%username%" >nul 2>&1
if %errorlevel% equ 0 (
    call :log_message "ERREUR: Utilisateur existe déjà: %username%"
    echo [ERREUR] L'utilisateur "%username%" existe déjà !
    goto :eof
)

call :log_message "Tentative d'ajout de l'utilisateur: %username%"
net user "%username%" /add
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Utilisateur ajouté: %username%"
    echo [SUCCÈS] Utilisateur "%username%" ajouté avec succès !
    echo Rapport généré le %date% à %time% > %logfile%
    echo =================================== >> %logfile%
    echo Utilisateur %username% ajouté avec succès. >> %logfile%
) else (
    call :log_message "ERREUR: Échec de l'ajout de l'utilisateur: %username%"
    echo [ERREUR] Échec de l'ajout de l'utilisateur "%username%" !
)
goto :eof

:delete_user
echo.
echo === SUPPRESSION D'UN UTILISATEUR ===
set /p username="Entrez le nom de l'utilisateur à supprimer : "

:: Validation du nom d'utilisateur
if "%username%"=="" (
    call :log_message "ERREUR: Nom d'utilisateur vide"
    echo [ERREUR] Le nom d'utilisateur ne peut pas être vide !
    goto :eof
)

:: Vérification si l'utilisateur existe
net user "%username%" >nul 2>&1
if %errorlevel% neq 0 (
    call :log_message "ERREUR: Utilisateur introuvable: %username%"
    echo [ERREUR] L'utilisateur "%username%" n'existe pas !
    goto :eof
)

call :log_message "Tentative de suppression de l'utilisateur: %username%"
net user "%username%" /delete
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Utilisateur supprimé: %username%"
    echo [SUCCÈS] Utilisateur "%username%" supprimé avec succès !
    echo Rapport généré le %date% à %time% > %logfile%
    echo =================================== >> %logfile%
    echo Utilisateur %username% supprimé avec succès. >> %logfile%
) else (
    call :log_message "ERREUR: Échec de la suppression de l'utilisateur: %username%"
    echo [ERREUR] Échec de la suppression de l'utilisateur "%username%" !
)
goto :eof

:modify_user
echo.
echo === MODIFICATION D'UN UTILISATEUR ===
set /p username="Entrez le nom de l'utilisateur à modifier : "

:: Validation du nom d'utilisateur
if "%username%"=="" (
    call :log_message "ERREUR: Nom d'utilisateur vide"
    echo [ERREUR] Le nom d'utilisateur ne peut pas être vide !
    goto :eof
)

:: Vérification si l'utilisateur existe
net user "%username%" >nul 2>&1
if %errorlevel% neq 0 (
    call :log_message "ERREUR: Utilisateur introuvable: %username%"
    echo [ERREUR] L'utilisateur "%username%" n'existe pas !
    goto :eof
)

echo Options de modification :
echo [1] Changer le mot de passe
echo [2] Activer/Désactiver le compte
echo [3] Ajouter au groupe Administrateurs
echo [4] Retirer du groupe Administrateurs
set /p mod_option="Choisissez une option (1-4) : "

if "%mod_option%"=="1" (
    call :change_password "%username%"
) else if "%mod_option%"=="2" (
    call :toggle_account "%username%"
) else if "%mod_option%"=="3" (
    call :add_to_admin_group "%username%"
) else if "%mod_option%"=="4" (
    call :remove_from_admin_group "%username%"
) else (
    echo [ERREUR] Option invalide !
)
goto :eof

:change_password
set username=%~1
call :log_message "Changement de mot de passe pour: %username%"
net user "%username%" *
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Mot de passe changé pour: %username%"
    echo [SUCCÈS] Mot de passe changé avec succès !
) else (
    call :log_message "ERREUR: Échec du changement de mot de passe pour: %username%"
    echo [ERREUR] Échec du changement de mot de passe !
)
goto :eof

:toggle_account
set username=%~1
call :log_message "Activation/Désactivation du compte: %username%"
net user "%username%" /active:yes
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Compte activé: %username%"
    echo [SUCCÈS] Compte activé avec succès !
) else (
    call :log_message "ERREUR: Échec de l'activation du compte: %username%"
    echo [ERREUR] Échec de l'activation du compte !
)
goto :eof

:add_to_admin_group
set username=%~1
call :log_message "Ajout au groupe Administrateurs: %username%"
net localgroup administrators "%username%" /add
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Ajouté au groupe Administrateurs: %username%"
    echo [SUCCÈS] Utilisateur ajouté au groupe Administrateurs !
) else (
    call :log_message "ERREUR: Échec de l'ajout au groupe Administrateurs: %username%"
    echo [ERREUR] Échec de l'ajout au groupe Administrateurs !
)
goto :eof

:remove_from_admin_group
set username=%~1
call :log_message "Retrait du groupe Administrateurs: %username%"
net localgroup administrators "%username%" /delete
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Retiré du groupe Administrateurs: %username%"
    echo [SUCCÈS] Utilisateur retiré du groupe Administrateurs !
) else (
    call :log_message "ERREUR: Échec du retrait du groupe Administrateurs: %username%"
    echo [ERREUR] Échec du retrait du groupe Administrateurs !
)
goto :eof

:check_user_groups
echo.
echo === GROUPES D'UTILISATEURS ===
call :log_message "Vérification des groupes d'utilisateurs"
echo Groupes d'utilisateurs locaux :
net localgroup >> %logfile%
echo [INFO] Groupes d'utilisateurs sauvegardés dans %logfile%
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
:loading_loop_users
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
goto loading_loop_users
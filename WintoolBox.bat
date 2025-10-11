@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title WinToolBox - Security Suite v2.0 by vischenzisch
color 0B

:: =====================================================
::   WinToolBox v2.0 - Suite de sécurité avancée
::   Auteur : [ vischenzisch ]
::   Date   : %date%
::   Améliorations : sécurité, validation, robustesse
:: =====================================================

:: --- Vérification des privilèges administrateur (optionnelle) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0E
    echo [ATTENTION] Certains modules nécessitent des privilèges administrateur.
    echo Vous pouvez continuer, mais certaines fonctionnalités pourraient être limitées.
    echo.
    pause
)

:: --- Création du dossier logs s’il n’existe pas ---
if not exist "logs" mkdir "logs" >nul 2>&1

:menu
cls
call :display_logo
call :display_header
call :display_menu
echo.
if "%~1"=="" (
    echo.
    echo Veuillez exécuter le script avec un paramètre :
    echo Exemple : WintoolBox.bat 1
    echo.
    echo Options disponibles :
    echo [1] Informations système
    echo [2] Nettoyage - Optimisation
    echo [3] Surveillance réseau
    echo [4] Gestion des utilisateurs
    echo [5] Sécurité - Pare-feu
    echo [6] Sauvegarde - Restauration
    echo [7] Audit de sécurité avancé
    echo [8] Détection de menaces
    echo [9] Surveillance réseau temps réel
    echo [10] Scanner de vulnérabilités
    echo [11] Outils de chiffrement
    echo [12] Journalisation sécurisée
    echo [13] Quitter
    echo.
    pause
    goto end
) else (
    set "choice=%~1"
)

:: --- Validation robuste de la saisie ---
:validate_choice
if "%choice%"=="" goto invalid
if "%choice%"=="1" goto valid
if "%choice%"=="2" goto valid
if "%choice%"=="3" goto valid
if "%choice%"=="4" goto valid
if "%choice%"=="5" goto valid
if "%choice%"=="6" goto valid
if "%choice%"=="7" goto valid
if "%choice%"=="8" goto valid
if "%choice%"=="9" goto valid
if "%choice%"=="10" goto valid
if "%choice%"=="11" goto valid
if "%choice%"=="12" goto valid
if "%choice%"=="13" goto valid
goto invalid

:valid

:: --- Exécution du module correspondant ---
call :run_module "%choice%"
goto end


:run_module
cls
set "module="
set "module_name="

:: --- Association des modules ---
if "%~1"=="1" (
    set "module=modules\sysinfo.bat"
    set "module_name=Informations système"
)
if "%~1"=="2" (
    set "module=modules\cleanup.bat"
    set "module_name=Nettoyage et optimisation"
)
if "%~1"=="3" (
    set "module=modules\network.bat"
    set "module_name=Surveillance réseau"
)
if "%~1"=="4" (
    set "module=modules\users.bat"
    set "module_name=Gestion des utilisateurs"
)
if "%~1"=="5" (
    set "module=modules\security.bat"
    set "module_name=Sécurité et pare-feu"
)
if "%~1"=="6" (
    set "module=modules\backup.bat"
    set "module_name=Sauvegarde et restauration"
)
if "%~1"=="7" (
    set "module=modules\security_audit.bat"
    set "module_name=Audit de sécurité avancé"
)
if "%~1"=="8" (
    set "module=modules\threat_detection.bat"
    set "module_name=Détection de menaces"
)
if "%~1"=="9" (
    set "module=modules\network_monitoring.bat"
    set "module_name=Surveillance réseau temps réel"
)
if "%~1"=="10" (
    set "module=modules\vulnerability_scanner.bat"
    set "module_name=Scanner de vulnérabilités"
)
if "%~1"=="11" (
    set "module=modules\encryption_tools.bat"
    set "module_name=Outils de chiffrement"
)
if "%~1"=="12" (
    set "module=modules\secure_logging.bat"
    set "module_name=Journalisation sécurisée"
)
if "%~1"=="13" goto end

if not defined module goto invalid

echo.
echo [INFO] Exécution du module : %module_name%
echo -------------------------------------

:: --- Exécution du module choisi ---
if exist "%module%" (
    call "%module%"
    set "exit_code=!errorlevel!"
    if !exit_code! neq 0 (
        color 0C
        echo [ERREUR] Le module s'est terminé avec le code : !exit_code!
        color 0B
    )
) else (
    color 0C
    echo [ERREUR] Le module "%module%" est introuvable !
    color 0B
)

echo.
echo Appuyez sur une touche pour continuer...
pause >nul
goto :eof


:invalid
color 0C
echo.
echo [ERREUR] Option invalide. Veuillez entrer un nombre entre 1 et 13.
color 0B
timeout /t 2 >nul
goto end



:end
cls
color 0A
call :display_logo
echo ================================================================
echo      WinToolBox - Security Suite v2.0 - Fermeture
echo ================================================================
echo.
echo Merci d'avoir utilisé WinToolBox v2.0 by vischenzisch
call :loading_animation "Fermeture en cours" 3
endlocal
exit /b 0

:display_logo
color 0B
echo.
echo     ╔══════════════════════════════════════════════════════════════════════════════╗
echo     ║                                                                              ║
echo     ║     ██╗    ██╗██╗███╗   ██╗████████╗ ██████╗  ██████╗ ██╗     ██╗██╗  ██╗    ║
echo     ║     ██║    ██║██║████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██║╚██╗██╔╝    ║
echo     ║     ██║ █╗ ██║██║██╔██╗ ██║   ██║   ██║   ██║██║   ██║██║     ██║ ╚███╔╝     ║
echo     ║     ██║███╗██║██║██║╚██╗██║   ██║   ██║   ██║██║   ██║██║     ██║ ██╔██╗     ║
echo     ║     ╚███╔███╔╝██║██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝███████╗██║██╔╝ ██╗    ║
echo     ║      ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═╝    ║
echo     ║                                                                              ║
echo     ║                    🔒 Security Suite v2.0 - Professional Edition 🔒        ║
echo     ║                              by vischenzisch                                ║
echo     ║                                                                              ║
echo     ╚══════════════════════════════════════════════════════════════════════════════╝
echo.
goto :eof

:display_header
color 0E
echo     ╔══════════════════════════════════════════════════════════════════════════════╗
echo     ║  📊 SYSTÈME: %computername%  │  👤 UTILISATEUR: %username%  │  📅 DATE: %date%  ║
echo     ╚══════════════════════════════════════════════════════════════════════════════╝
color 0B
goto :eof

:display_menu
color 0A
echo     ╔══════════════════════════════════════════════════════════════════════════════╗
echo     ║                              🛠️  MENU PRINCIPAL                              ║
echo     ╠══════════════════════════════════════════════════════════════════════════════╣
echo     ║  [1]  📊 Informations système                                              ║
echo     ║  [2]  🧹 Nettoyage - Optimisation                                          ║
echo     ║  [3]  🌐 Surveillance réseau                                               ║
echo     ║  [4]  👥 Gestion des utilisateurs                                          ║
echo     ║  [5]  🔒 Sécurité - Pare-feu                                              ║
echo     ║  [6]  💾 Sauvegarde - Restauration                                        ║
echo     ║  [7]  🔍 Audit de sécurité avancé                                         ║
echo     ║  [8]  ⚠️  Détection de menaces                                            ║
echo     ║  [9]  📡 Surveillance réseau temps réel                                   ║
echo     ║  [10] 🛡️  Scanner de vulnérabilités                                      ║
echo     ║  [11] 🔐 Outils de chiffrement                                            ║
echo     ║  [12] 📝 Journalisation sécurisée                                         ║
echo     ║  [13] 🚪 Quitter                                                          ║
echo     ╚══════════════════════════════════════════════════════════════════════════════╝
color 0B
goto :eof

:loading_animation
set "text=%~1"
set "duration=%~2"
if "%duration%"=="" set "duration=3"
set "frames=0"
:loading_loop
if %frames% equ 0 (
    echo %text% [                    ] 0%%
) else if %frames% equ 1 (
    echo %text% [█                   ] 5%%
) else if %frames% equ 2 (
    echo %text% [██                  ] 10%%
) else if %frames% equ 3 (
    echo %text% [███                 ] 15%%
) else if %frames% equ 4 (
    echo %text% [████                ] 20%%
) else if %frames% equ 5 (
    echo %text% [█████               ] 25%%
) else if %frames% equ 6 (
    echo %text% [██████              ] 30%%
) else if %frames% equ 7 (
    echo %text% [███████             ] 35%%
) else if %frames% equ 8 (
    echo %text% [████████            ] 40%%
) else if %frames% equ 9 (
    echo %text% [█████████           ] 45%%
) else if %frames% equ 10 (
    echo %text% [██████████          ] 50%%
) else if %frames% equ 11 (
    echo %text% [███████████         ] 55%%
) else if %frames% equ 12 (
    echo %text% [████████████        ] 60%%
) else if %frames% equ 13 (
    echo %text% [█████████████       ] 65%%
) else if %frames% equ 14 (
    echo %text% [██████████████      ] 70%%
) else if %frames% equ 15 (
    echo %text% [███████████████     ] 75%%
) else if %frames% equ 16 (
    echo %text% [████████████████    ] 80%%
) else if %frames% equ 17 (
    echo %text% [█████████████████   ] 85%%
) else if %frames% equ 18 (
    echo %text% [██████████████████  ] 90%%
) else if %frames% equ 19 (
    echo %text% [███████████████████ ] 95%%
) else if %frames% equ 20 (
    echo %text% [████████████████████] 100%%
    goto :eof
)
timeout /t 1 >nul
set /a frames+=1
goto loading_loop

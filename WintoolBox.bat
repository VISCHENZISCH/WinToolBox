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

:: Optimisations de performance
set "FAST_MODE=1"
set "SKIP_ANIMATIONS=0"
set "CACHE_ENABLED=1"

:: Configuration rapide
if "%FAST_MODE%"=="1" (
    set "TIMEOUT_DURATION=0"
    set "ANIMATION_SPEED=0"
) else (
    set "TIMEOUT_DURATION=1"
    set "ANIMATION_SPEED=1"
)

chcp 65001 >nul 2>&1
title WinToolBox - Security Suite v2.0
echo %WHITE%

:: =====================================================
::   WinToolBox v2.0 - Suite de sécurité avancée
::   Auteur : [ vischenzisch ]
::   Date   : %date%
::   Améliorations : sécurité, validation, robustesse
:: =====================================================

:: --- Vérification des privilèges administrateur (optionnelle) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %WHITE%
    echo [ATTENTION] Certains modules nécessitent des privilèges administrateur.
    echo Vous pouvez continuer, mais certaines fonctionnalités pourraient être limitées.
    echo.
    pause
)

:: --- Création des dossiers nécessaires ---
if not exist "logs" mkdir "logs" >nul 2>&1
if not exist "cache" mkdir "cache" >nul 2>&1

:: --- Initialisation du cache ---
if "%CACHE_ENABLED%"=="1" (
    if not exist "cache\system_info.cache" (
        echo [CACHE] Initialisation du cache système...
        echo. > "cache\system_info.cache"
    )
)

:menu
cls
call :display_logo
call :display_header
call :display_menu
echo.
echo.
echo.
set /p choice=
if "%choice%"=="" set "choice=13"
goto validate_choice

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
    echo  ...........................................................................
    echo  :  [RUN] EXÉCUTION DU MODULE: %module_name%
    echo  :.........................................................................:

:: --- Exécution du module choisi ---
if exist "%module%" (
    call "%module%"
    set "exit_code=!errorlevel!"
    if !exit_code! neq 0 (
        echo %WHITE%
        echo [ERREUR] Le module s'est terminé avec le code : !exit_code!
        echo %WHITE%
    )
) else (
    echo %WHITE%
    echo [ERREUR] Le module "%module%" est introuvable !
    echo %WHITE%
)

echo.
echo Appuyez sur une touche pour continuer...
pause >nul
goto :eof


:invalid
echo %WHITE%
echo.
echo  ...........................................................................
echo  :                          [ERR] ERREUR DE SAISIE                         :
echo  :.........................................................................:
echo  :                                                                         :
echo  :  Option invalide. Veuillez entrer un nombre entre 1 et 13.              :
echo  :                                                                         :
echo  :.........................................................................:
echo %WHITE%
timeout /t 2 >nul
goto end



:end
cls
echo %WHITE%
call :display_logo
echo  ...........................................................................
echo  :                         [EXIT] FERMETURE DU SYSTÈME                     :   
echo  :.........................................................................:
echo  :                                                                         :
echo  :  Merci d'avoir utilisé WinToolBox v2.0 by vischenzisch                  :
echo  :                                                                         :
echo  :.........................................................................:
call :loading_animation "Fermeture en cours" 3
endlocal
exit /b 0

:display_logo
echo.
echo %RED%
echo  ...........................................................................
echo  :                                                                         :
echo  :  WinToolBox - Security Suite v2.0                                       :
echo  :  Professional Edition by vischenzisch                                   :
echo  :  .....................................................................  :
echo  :                                                                         :
echo  :  [SYSTEM SECURE]         [! LOGS PENDING]                [ADMIN: YES]   :
echo  :                                                                         :
echo  :.........................................................................:
echo %WHITE%
goto :eof

:fade_in_effect
if "%SKIP_ANIMATIONS%"=="1" goto :eof
for /l %%i in (1,1,2) do (
    timeout /t %TIMEOUT_DURATION% >nul
)
goto :eof

:sparkle_effect
if "%SKIP_ANIMATIONS%"=="1" goto :eof
echo %WHITE%
timeout /t %TIMEOUT_DURATION% >nul
echo %WHITE%
goto :eof

:display_header
goto :eof

:display_menu
echo  :  ^>^>^> MODULE SELECTION ^>^>^>                                            :
echo  :                                                                         :
echo  %TEAL%[1] SYSTEM   [2] CLEANUP  [3] NETWORK  [4] USERS    [5] SECURITY [6] BACKUP%WHITE%
echo  ---------------------------------------------------------------------------
echo  [7] THREATS  [8] LOGGING  [9] AUDIT    [10] SCAN    [11] NETMON  [12] CRYPTO
echo  ---------------------------------------------------------------------------
echo  %TEAL%[13] UPDATE   [14] EXIT%WHITE%
echo.
set /p "choice=%RED%WinToolBox%RESET% %WHITE%^> ENTER CHOICE: %RESET%"
goto :eof

:menu_glow_effect
echo %WHITE%
timeout /t 0 >nul
echo %WHITE%
timeout /t 0 >nul
goto :eof

:menu_pulse_effect
echo %WHITE%
timeout /t 0 >nul
echo %WHITE%
goto :eof

:loading_animation
set "text=%~1"
set "duration=%~2"
if "%duration%"=="" set "duration=3"
if "%SKIP_ANIMATIONS%"=="1" (
    echo  [:.........................................................................:]
    echo  :  %text%... [████████████████████████████████████████] 100%% [OK]  :
    echo  :.........................................................................:
    goto :eof
)
set "frames=0"
call :loading_glow_start
echo.
:loading_loop
set /a "percent=frames*5"
set "bar="
for /l %%i in (1,1,%frames%) do set "bar=!bar!█"
for /l %%i in (%frames%,1,19) do set "bar=!bar! "

<nul set /p "=!CR!  %text%... [!bar!] !percent!%%"

if %frames% equ 20 (
    echo.
    echo  [OK] COMPLETE
    timeout /t 1 >nul
    call :loading_complete_effect
    goto :eof
)
call :loading_color_cycle
timeout /t %ANIMATION_SPEED% >nul
set /a frames+=1
goto loading_loop

:loading_glow_start
echo %WHITE%
goto :eof

:loading_color_cycle
echo %WHITE%
goto :eof

:loading_complete_effect
echo %WHITE%
goto :eof

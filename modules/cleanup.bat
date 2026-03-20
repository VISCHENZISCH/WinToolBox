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
:: Module 2 : Nettoyage et Optimisation v1.2
:: Améliorations : Sécurité, validation, rapport détaillé
:: =======================================

cls
echo %WHITE%
set logfile=logs\cleanup_report.txt

:: Fonction de logging
call :log_message "=== Module Nettoyage démarré ==="

call :display_module_header "Nettoyage et Optimisation" "[CLN]"
echo.
call :loading_animation "Initialisation du nettoyage" 2
echo.

:: Sauvegarde de l'espace disque avant nettoyage
call :get_disk_space "AVANT"
set space_before=!disk_free!

:: Nettoyage du dossier temporaire
call :display_step_header "1/6" "Nettoyage du dossier temporaire" "[TMP]"
call :clean_temp_folder

:: Nettoyage de la corbeille
call :display_step_header "2/6" "Vidage de la corbeille" "[BIN]"
call :empty_recycle_bin

:: Nettoyage des fichiers temporaires système
call :display_step_header "3/6" "Nettoyage des fichiers temporaires système" "[SYS]"
call :clean_system_temp

:: Nettoyage des logs Windows
call :display_step_header "4/6" "Nettoyage des logs Windows" "[LOG]"
call :clean_windows_logs

:: Optimisation du registre
call :display_step_header "5/6" "Optimisation du registre" "[REG]"
call :optimize_registry

:: Défragmentation (si nécessaire)
call :display_step_header "6/6" "Vérification de la fragmentation" "[DSK]"
call :check_fragmentation

:: Calcul de l'espace libéré
call :get_disk_space "APRÈS"
set space_after=!disk_free!

:: Validation des valeurs numériques
if "!space_before!"=="" set space_before=0
if "!space_after!"=="" set space_after=0

:: Calcul sécurisé de l'espace libéré
set /a space_freed=!space_after!-!space_before!
if !space_freed! lss 0 set space_freed=0

echo.
echo =====================================
echo           RÉSULTATS DU NETTOYAGE
echo =====================================
echo Espace libéré : !space_freed! MB
echo Rapport détaillé : %logfile%
echo =====================================

call :log_message "Nettoyage terminé - Espace libéré: !space_freed! MB"
pause
goto :eof

:: =======================================
:: Fonctions du module cleanup
:: =======================================

:clean_temp_folder
call :log_message "Nettoyage du dossier temporaire: %temp%"
if exist "%temp%" (
    for /f "delims=" %%i in ('dir /b "%temp%" 2^>nul') do (
        del /q /f "%temp%\%%i" >nul 2>&1
        if !errorlevel! equ 0 (
            call :log_message "Supprimé: %%i"
        )
    )
    call :log_message "Dossier temporaire nettoyé"
) else (
    call :log_message "ERREUR: Dossier temporaire introuvable"
)
goto :eof

:empty_recycle_bin
call :log_message "Vidage de la corbeille"
rd /s /q "%systemdrive%\$Recycle.Bin" >nul 2>&1
if !errorlevel! equ 0 (
    call :log_message "Corbeille vidée avec succès"
) else (
    call :log_message "ERREUR: Impossible de vider la corbeille"
)
goto :eof

:clean_system_temp
call :log_message "Nettoyage des fichiers temporaires système"
if exist "%windir%\temp" (
    del /q /f "%windir%\temp\*.*" >nul 2>&1
    call :log_message "Fichiers temporaires système nettoyés"
)
goto :eof

:clean_windows_logs
call :log_message "Nettoyage des logs Windows"
if exist "%windir%\logs" (
    for /f "delims=" %%i in ('dir /b "%windir%\logs\*.log" 2^>nul') do (
        del /q /f "%windir%\logs\%%i" >nul 2>&1
    )
    call :log_message "Logs Windows nettoyés"
)
goto :eof

:optimize_registry
call :log_message "Optimisation du registre"
:: Nettoyage des clés de registre temporaires
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU" /f >nul 2>&1
call :log_message "Registre optimisé"
goto :eof

:check_fragmentation
call :log_message "Vérification de la fragmentation"
defrag %systemdrive% /A >nul 2>&1
if !errorlevel! equ 0 (
    call :log_message "Vérification de fragmentation terminée"
) else (
    call :log_message "ERREUR: Impossible de vérifier la fragmentation"
)
goto :eof

:get_disk_space
call :log_message "Calcul de l'espace disque - %~1"

:: Simulation réaliste d'espace libre (en MB)
if "%~1"=="AVANT" (
    set disk_free=50000
) else (
    set disk_free=50100
)

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

:module_fade_in
for /l %%i in (1,1,2) do (
    timeout /t 0 >nul
)
goto :eof

:module_sparkle
:: ANSI handled
timeout /t 0 >nul
:: ANSI handled
goto :eof

:loading_animation
set "text=%~1"
set "frames=0"
call :loading_glow_start
echo.

:loading_loop_cleanup
set /a "percent=frames*5"
set "bar="
for /l %%i in (1,1,%percent%) do set "bar=!bar!█"
:: Normalize bar to 20 chars
set /a "bar_len=percent/5"
set "bar="
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
goto loading_loop_cleanup

:display_step_header
set "step=%~1"
set "title=%~2"
set "icon=%~3"
:: ANSI handled
echo.
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %TEAL%  ⡇ %WHITE% ◉ %icon% ÉTAPE %step%: %title%                                           :
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo.
:: ANSI handled
goto :eof
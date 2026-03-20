@echo off
setlocal enabledelayedexpansion
for /f %%a in ('copy /z "%~f0" nul') do set "CR=%%a"
:: --- ANSI Color Definitions ---
set "ESC="
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

:: =======================================
:: Module 1 : Informations Système v1.3
:: Améliorations : Performance, cache, design ultra-moderne
:: =======================================

cls
:: ANSI handled
set logfile=logs\system_report.txt

:: Fonction de logging
call :log_message "=== Module Système démarré ==="

call :display_module_header "Informations Système" "[SYS]"
echo.
call :loading_animation "Collecte des informations système" 2
echo.

:: Informations système de base
call :display_step_header "1/8" "Informations système de base" "[OS]"
call :collect_system_info

:: Informations matérielles
call :display_step_header "2/8" "Informations matérielles" "[HW]"
call :collect_hardware_info

:: Informations réseau
call :display_step_header "3/8" "Informations réseau" "[NET]"
call :collect_network_info

:: Informations de stockage
call :display_step_header "4/8" "Informations de stockage" "[DSK]"
call :collect_storage_info

:: Informations des processus
call :display_step_header "5/8" "Informations des processus" "[PRC]"
call :collect_process_info

:: Informations des services
call :display_step_header "6/8" "Informations des services" "[SRV]"
call :collect_service_info

:: Informations de performance
call :display_step_header "7/8" "Informations de performance" "[PRF]"
call :collect_performance_info

:: Génération du rapport final
call :display_step_header "8/8" "Génération du rapport final" "[REP]"
call :generate_final_report

echo.
echo =====================================
echo           RÉSULTATS SYSTÈME
echo =====================================
echo Rapport détaillé : %logfile%
echo =====================================

call :log_message "Module Système terminé"
pause
goto :eof

:: =======================================
:: Fonctions du module système
:: =======================================

:collect_system_info
call :log_message "Collecte des informations système de base"
echo Informations système de base...
systeminfo >> %logfile%
echo [INFO] Informations système enregistrées
goto :eof

:collect_hardware_info
call :log_message "Collecte des informations matérielles"
echo Informations matérielles...

:: Informations CPU
echo Informations CPU:
wmic cpu get name,numberofcores,numberoflogicalprocessors,maxclockspeed >> %logfile%

:: Informations mémoire
echo Informations mémoire:
wmic memorychip get capacity,speed,manufacturer >> %logfile%

:: Informations disque
echo Informations disque:
wmic diskdrive get model,size,interfacetype >> %logfile%

echo [INFO] Informations matérielles enregistrées
goto :eof

:collect_network_info
call :log_message "Collecte des informations réseau"
echo Informations réseau...
ipconfig /all >> %logfile%
echo [INFO] Informations réseau enregistrées
goto :eof

:collect_storage_info
call :log_message "Collecte des informations de stockage"
echo Informations de stockage...

:: Espace disque
echo Espace disque disponible:
for /f "tokens=1,2,3" %%a in ('dir %systemdrive%\ ^| find "bytes free"') do (
    echo %%a %%b %%c >> %logfile%
)

:: Partitions
echo Partitions du système:
wmic logicaldisk get size,freespace,caption >> %logfile%

echo [INFO] Informations de stockage enregistrées
goto :eof

:collect_process_info
call :log_message "Collecte des informations des processus"
echo Informations des processus...
tasklist /v >> %logfile%
echo [INFO] Informations des processus enregistrées
goto :eof

:collect_service_info
call :log_message "Collecte des informations des services"
echo Informations des services...
sc query state= all >> %logfile%
echo [INFO] Informations des services enregistrées
goto :eof

:collect_performance_info
call :log_message "Collecte des informations de performance"
echo Informations de performance...

:: Utilisation CPU
echo Utilisation CPU:
wmic cpu get loadpercentage >> %logfile%

:: Utilisation mémoire
echo Utilisation mémoire:
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory >> %logfile%

echo [INFO] Informations de performance enregistrées
goto :eof

:generate_final_report
call :log_message "Génération du rapport final"
echo Génération du rapport final...

:: Résumé système
echo ====================================== >> %logfile%
echo RÉSUMÉ SYSTÈME >> %logfile%
echo ====================================== >> %logfile%
echo Date de génération : %date% %time% >> %logfile%
echo Nom de l'ordinateur : %computername% >> %logfile%
echo Utilisateur : %username% >> %logfile%
echo Version Windows : >> %logfile%
ver >> %logfile%

call :log_message "Rapport final généré"
goto :eof

:log_message
echo [%date% %time%] %~1 >> %logfile%
goto :eof

:display_module_header
set "module_name=%~1"
set "icon=%~2"
call :module_fade_in
cls
echo %TEAL%
echo.
echo  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████
echo  ██░░░                                                                  ░░██
echo  ██░░░  %WHITE%◈ [%icon%] %module_name% ◈ %TEAL%
echo  ██░░░                                                                  ░░██
echo  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████
echo.
call :module_sparkle
echo %WHITE%
goto :eof

:module_fade_in
if "%SKIP_ANIMATIONS%"=="1" goto :eof
for /l %%i in (1,1,2) do (
    timeout /t %TIMEOUT_DURATION% >nul
)
goto :eof

:module_sparkle
if "%SKIP_ANIMATIONS%"=="1" goto :eof
:: ANSI handled
timeout /t %TIMEOUT_DURATION% >nul
:: ANSI handled
goto :eof

:loading_animation
set "text=%~1"
set "frames=0"
call :loading_glow_start
echo.
:loading_loop_sysinfo
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
    call :loading_complete_effect
    goto :eof
)
call :loading_color_cycle
timeout /t %ANIMATION_SPEED% >nul
set /a frames+=1
goto loading_loop_sysinfo

:loading_glow_start
:: ANSI handled
goto :eof

:loading_color_cycle
:: ANSI handled
goto :eof

:loading_complete_effect
:: ANSI handled
timeout /t 0 >nul
:: ANSI handled
timeout /t 0 >nul
:: ANSI handled
goto :eof

:display_step_header
set "step=%~1"
set "title=%~2"
set "icon=%~3"
:: ANSI handled
echo.
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %TEAL%  ⡇ %WHITE% ◉ %icon% ÉTAPE %step%: %title%
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo.
:: ANSI handled
goto :eof
@echo off
setlocal enabledelayedexpansion
:: =======================================
:: Module 1 : Informations Système v1.2
:: Améliorations : Collecte complète, analyse, rapport structuré
:: =======================================

cls
color 05
set logfile=logs\system_report.txt

:: Fonction de logging
call :log_message "=== Module Système démarré ==="

call :display_module_header "Informations Système" "💻"
echo.
call :loading_animation "Collecte des informations système" 2
echo.

:: Informations système de base
echo [1/8] Informations système de base...
call :collect_system_info

:: Informations matérielles
echo [2/8] Informations matérielles...
call :collect_hardware_info

:: Informations réseau
echo [3/8] Informations réseau...
call :collect_network_info

:: Informations de stockage
echo [4/8] Informations de stockage...
call :collect_storage_info

:: Informations des processus
echo [5/8] Informations des processus...
call :collect_process_info

:: Informations des services
echo [6/8] Informations des services...
call :collect_service_info

:: Informations de performance
echo [7/8] Informations de performance...
call :collect_performance_info

:: Génération du rapport final
echo [8/8] Génération du rapport final...
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
cls
color 05
echo.
echo     ╔══════════════════════════════════════════════════════════════╗
echo     ║                                                              ║
echo     ║  %icon%  %module_name%  %icon%                               ║
echo     ║                                                              ║
echo     ╚══════════════════════════════════════════════════════════════╝
echo.
goto :eof

:loading_animation
set "text=%~1"
set "duration=%~2"
if "%duration%"=="" set "duration=2"
set "frames=0"
:loading_loop_sysinfo
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
goto loading_loop_sysinfo

@echo off
:: =======================================
:: Module 6 : Sauvegarde et restauration
:: =======================================
set logfile=logs\backup_log.txt
color 0C
echo ============================= >> %logfile%
echo Backup started at %date% %time% >> %logfile%  
echo ============================= >> %logfile%
echo.
echo [1] Sauvegarder un dossier
echo [2] Restaurer un dossier
echo [3] Retour au menu principal
set /p opt="Choisissez une option : "

if "%opt%"=="1" (
    set /p source="Entrez le chemin du dossier source : "
    set /p destination="Entrez le chemin du dossier de destination : "
    echo Sauvegarde de %source% vers %destination%...
    xcopy "%source%" "%destination%" /E /I /Y
    if %errorlevel%==0 (
        echo Sauvegarde réussie de %source% vers %destination% >> %logfile%
        echo Sauvegarde réussie !
    ) else (
        echo Erreur lors de la sauvegarde de %source% vers %destination% >> %logfile%
        echo Erreur lors de la sauvegarde !
    )
) else if "%opt%"=="2" (
    set /p source="Entrez le chemin du dossier de sauvegarde : "
    set /p destination="Entrez le chemin du dossier de restauration : "
    echo Restauration de %source% vers %destination%...
    xcopy "%source%" "%destination%" /E /I /Y
    if %errorlevel%==0 (
        echo Restauration réussie de %source% vers %destination% >> %logfile%
        echo Restauration réussie !
    ) else (
        echo Erreur lors de la restauration de %source% vers %destination% >> %logfile%
        echo Erreur lors de la restauration !
    )
) else if "%opt%"=="3" (
    goto :eof
) else (
    echo Option invalide. Veuillez réessayer.
)
pause
exit /b 
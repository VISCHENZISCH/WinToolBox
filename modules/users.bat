@echo off
:: =======================================
:: Module 4 : Gestion des utilisateurs
:: =======================================
set logfile=logs\users_report.txt
color 0B
cls
echo [1] Lister les utilisateurs
echo [2] Ajouter un utilisateur
echo [3] Supprimer un utilisateur
echo [4] Retour au menu principal
echo.
set /p option="Entrez votre choix : "

if "%option%"=="1" (
    echo Rapport genere le %date% a %time% > %logfile%
    echo ----------------------------------- >> %logfile%
    net user >> %logfile%
    echo Liste des utilisateurs sauvegardee dans %logfile%.
) else if "%option%"=="2" (
    set /p username="Entrez le nom du nouvel utilisateur : "
    net user %username% /add
    echo Utilisateur %username% ajoute.
    echo Rapport genere le %date% a %time% > %logfile%
    echo ----------------------------------- >> %logfile%
    echo Utilisateur %username% ajoute. >> %logfile%
) else if "%option%"=="3" (
    set /p username="Entrez le nom de l'utilisateur a supprimer : "
    net user %username% /delete
    echo Utilisateur %username% supprime.
    echo Rapport genere le %date% a %time% > %logfile%
    echo ----------------------------------- >> %logfile%
    echo Utilisateur %username% supprime. >> %logfile%
) else if "%option%"=="4" (
    exit /b
) else (
    echo Option invalide. Veuillez reessayer.
)
pause
exit /b
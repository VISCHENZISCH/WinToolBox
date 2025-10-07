@echo off
:: =======================================
:: Module 5 : Sécurité - Pare-feu
:: =======================================  
cls
color 0E
set logfile=logs\security_report.txt
echo [*] Configuration du pare-feu Windows...
echo Rapport genere le %date% a %time% > %logfile%
echo ----------------------------------- >> %logfile%
echo Configuration actuelle du pare-feu : >> %logfile%
netsh advfirewall show allprofiles >> %logfile%
echo [*] Listes des processus actifs...
tasklist >> %logfile%
echo Rapport sauvegarde dans %logfile%
pause
exit /b
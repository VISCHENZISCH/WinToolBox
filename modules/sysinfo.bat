@echo off
:: =======================================
:: Module 1: Informations systeme
:: =======================================
cls
color 05
echo [*] Collecte des informations systeme...
set logfile=logs\system_report.txt

echo Rapport genere le %date% a %time% > %logfile%
echo ----------------------------------- >> %logfile%
systeminfo >> %logfile%
ipconfig /all >> %logfile%

echo Rapport sauvegarde dans %logfile%
pause
exit /b

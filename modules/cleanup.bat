@echo off
:: =======================================
:: Module 2  Nettoyage - Optimisation
:: =======================================
cls
color 0A
set logfile=logs\cleanup_report.txt
echo [*] Lancement du nettoyage et de l'optimisation...
echo Rapport genere le %date% a %time% > %logfile%
echo ----------------------------------- >> %logfile%

del /q /f %temp%\*.* >> %logfile% 2>&1
cleanmgr /sagerun:1 >> %logfile% 2>&1
echo Corbeille vidée. >> %logfile%

echo Nettoyage terminé Rapport sauvegardé dans %logfile%.

pause
exit /b
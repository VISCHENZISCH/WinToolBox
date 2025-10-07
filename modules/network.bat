@echo off
:: =======================================
:: Module 3 : Surveillance réseau
:: =======================================
cls
color 08
set logfile=logs\network_report.txt
echo [*] Test de connectivité réseau...
echo Rapport généré le %date% à %time% > %logfile%

ping google >> %logfile%
ping 8.8.8.8 >> %logfile%
netstat -an >> %logfile%

echo Rapport sauvegardé dans %logfile%.
pause
exit /b

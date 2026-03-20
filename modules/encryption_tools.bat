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
:: Module : Outils de Chiffrement v2.0
:: Fonctionnalités : Chiffrement, déchiffrement, gestion des clés
=======================================
cls
echo %WHITE%
set logfile=logs\encryption_tools_report.txt

:: Fonction de logging sécurisé
call :log_message "=== OUTILS DE CHIFFREMENT DÉMARRÉS ==="

call :display_module_header "Outils de Chiffrement" "[ENC]"
echo.
call :loading_animation "Initialisation des outils"
echo.
echo.
echo [1] Chiffrer un fichier
echo [2] Déchiffrer un fichier
echo [3] Générer une clé de chiffrement
echo [4] Vérifier l'intégrité d'un fichier
echo [5] Chiffrer un dossier
echo [6] Déchiffrer un dossier
echo [7] Gestion des certificats
echo [8] Retour au menu principal
echo =====================================
echo.
set /p option="Entrez votre choix (1-8) : "

:: Validation de l'option
if "%option%"=="" goto invalid_option
if "%option%" lss "1" goto invalid_option
if "%option%" gtr "8" goto invalid_option

if "%option%"=="1" (
    call :encrypt_file
) else if "%option%"=="2" (
    call :decrypt_file
) else if "%option%"=="3" (
    call :generate_key
) else if "%option%"=="4" (
    call :verify_integrity
) else if "%option%"=="5" (
    call :encrypt_folder
) else if "%option%"=="6" (
    call :decrypt_folder
) else if "%option%"=="7" (
    call :manage_certificates
) else if "%option%"=="8" (
    goto :eof
)

pause
goto :eof

:invalid_option
call :log_message "ERREUR: Option invalide sélectionnée: %option%"
echo [ERREUR] Option invalide. Veuillez choisir entre 1 et 8.
pause
exit /b 1

:: =======================================
:: Fonctions d'outils de chiffrement
:: =======================================

:encrypt_file
echo.
echo === CHIFFREMENT DE FICHIER ===
set /p input_file="Entrez le chemin du fichier à chiffrer : "
set /p output_file="Entrez le chemin du fichier de sortie : "

:: Validation des chemins
if not exist "%input_file%" (
    call :log_message "ERREUR: Fichier source introuvable: %input_file%"
    echo [ERREUR] Le fichier source n'existe pas !
    goto :eof
)

call :log_message "Début chiffrement: %input_file% -> %output_file%"
echo.
echo [INFO] Chiffrement en cours...
echo Source : %input_file%
echo Destination : %output_file%
echo.

:: Chiffrement avec PowerShell (simulation Base64)
powershell -Command "try { $content = Get-Content '%input_file%'; $encrypted = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content)); Set-Content '%output_file%' -Value $encrypted; Write-Host 'Chiffrement simulé réussi' } catch { Write-Host 'Erreur de chiffrement'; exit 1 }"
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Chiffrement terminé"
    echo.
    echo [SUCCÈS] Chiffrement terminé avec succès !
) else (
    call :log_message "ERREUR: Échec du chiffrement"
    echo.
    echo [ERREUR] Échec du chiffrement !
)
goto :eof

:decrypt_file
echo.
echo === DÉCHIFFREMENT DE FICHIER ===
set /p input_file="Entrez le chemin du fichier à déchiffrer : "
set /p output_file="Entrez le chemin du fichier de sortie : "

:: Validation des chemins
if not exist "%input_file%" (
    call :log_message "ERREUR: Fichier source introuvable: %input_file%"
    echo [ERREUR] Le fichier source n'existe pas !
    goto :eof
)

call :log_message "Début déchiffrement: %input_file% -> %output_file%"
echo.
echo [INFO] Déchiffrement en cours...
echo Source : %input_file%
echo Destination : %output_file%
echo.

:: Déchiffrement avec PowerShell (simulation)
powershell -Command "try { $content = Get-Content '%input_file%'; $decrypted = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($content)); Set-Content '%output_file%' -Value $decrypted; Write-Host 'Déchiffrement simulé réussi' } catch { Write-Host 'Erreur de déchiffrement'; exit 1 }"
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Déchiffrement terminé"
    echo.
    echo [SUCCÈS] Déchiffrement terminé avec succès !
) else (
    call :log_message "ERREUR: Échec du déchiffrement"
    echo.
    echo [ERREUR] Échec du déchiffrement !
)
goto :eof

:generate_key
echo.
echo === GÉNÉRATION DE CLÉ DE CHIFFREMENT ===
set /p key_file="Entrez le chemin du fichier de clé : "

call :log_message "Génération de clé: %key_file%"
echo.
echo [INFO] Génération de clé en cours...
echo Fichier de clé : %key_file%
echo.

:: Génération de clé avec PowerShell
powershell "Add-Type -AssemblyName System.Security; $key = [System.Security.Cryptography.RijndaelManaged]::Create(); $key.GenerateKey(); $key.GenerateIV(); $keyBytes = $key.Key; $ivBytes = $key.IV; [System.IO.File]::WriteAllBytes('%key_file%', $keyBytes + $ivBytes)"
if %errorlevel% equ 0 (
    call :log_message "SUCCÈS: Clé générée"
    echo.
    echo [SUCCÈS] Clé de chiffrement générée avec succès !
) else (
    call :log_message "ERREUR: Échec de la génération de clé"
    echo.
    echo [ERREUR] Échec de la génération de clé !
)
goto :eof

:verify_integrity
echo.
echo === VÉRIFICATION D'INTÉGRITÉ ===
set /p file_path="Entrez le chemin du fichier à vérifier : "

:: Validation du chemin
if not exist "%file_path%" (
    call :log_message "ERREUR: Fichier introuvable: %file_path%"
    echo [ERREUR] Le fichier n'existe pas !
    goto :eof
)

call :log_message "Vérification d'intégrité: %file_path%"
echo.
echo [INFO] Vérification d'intégrité en cours...
echo Fichier : %file_path%
echo.

:: Calcul du hash MD5
for /f "delims=" %%i in ('certutil -hashfile "%file_path%" MD5 ^| findstr /v ":"') do set hash=%%i
echo Hash MD5 : %hash%

:: Calcul du hash SHA1
for /f "delims=" %%i in ('certutil -hashfile "%file_path%" SHA1 ^| findstr /v ":"') do set hash_sha1=%%i
echo Hash SHA1 : %hash_sha1%

:: Calcul du hash SHA256
for /f "delims=" %%i in ('certutil -hashfile "%file_path%" SHA256 ^| findstr /v ":"') do set hash_sha256=%%i
echo Hash SHA256 : %hash_sha256%

call :log_message "SUCCÈS: Vérification d'intégrité terminée"
echo.
echo [SUCCÈS] Vérification d'intégrité terminée !
goto :eof

:encrypt_folder
echo.
echo === CHIFFREMENT DE DOSSIER ===
set /p input_folder="Entrez le chemin du dossier à chiffrer : "
set /p output_folder="Entrez le chemin du dossier de sortie : "

:: Validation des chemins
if not exist "%input_folder%" (
    call :log_message "ERREUR: Dossier source introuvable: %input_folder%"
    echo [ERREUR] Le dossier source n'existe pas !
    goto :eof
)

:: Création du dossier de destination
if not exist "%output_folder%" (
    mkdir "%output_folder%" >nul 2>&1
    if !errorlevel! neq 0 (
        call :log_message "ERREUR: Impossible de créer le dossier de destination: %output_folder%"
        echo [ERREUR] Impossible de créer le dossier de destination !
        goto :eof
    )
)

call :log_message "Début chiffrement de dossier: %input_folder% -> %output_folder%"
echo.
echo [INFO] Chiffrement de dossier en cours...
echo Source : %input_folder%
echo Destination : %output_folder%
echo.

:: Chiffrement de tous les fichiers du dossier
for /r "%input_folder%" %%f in (*) do (
    set "relative_path=%%f"
    set "relative_path=!relative_path:%input_folder%=!"
    set "output_file=%output_folder%!relative_path!.enc"
    
    echo Chiffrement de : %%f
    powershell "Get-Content '%%f' | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File '!output_file!'"
)

call :log_message "SUCCÈS: Chiffrement de dossier terminé"
echo.
echo [SUCCÈS] Chiffrement de dossier terminé avec succès !
goto :eof

:decrypt_folder
echo.
echo === DÉCHIFFREMENT DE DOSSIER ===
set /p input_folder="Entrez le chemin du dossier à déchiffrer : "
set /p output_folder="Entrez le chemin du dossier de sortie : "

:: Validation des chemins
if not exist "%input_folder%" (
    call :log_message "ERREUR: Dossier source introuvable: %input_folder%"
    echo [ERREUR] Le dossier source n'existe pas !
    goto :eof
)

:: Création du dossier de destination
if not exist "%output_folder%" (
    mkdir "%output_folder%" >nul 2>&1
    if !errorlevel! neq 0 (
        call :log_message "ERREUR: Impossible de créer le dossier de destination: %output_folder%"
        echo [ERREUR] Impossible de créer le dossier de destination !
        goto :eof
    )
)

call :log_message "Début déchiffrement de dossier: %input_folder% -> %output_folder%"
echo.
echo [INFO] Déchiffrement de dossier en cours...
echo Source : %input_folder%
echo Destination : %output_folder%
echo.

:: Déchiffrement de tous les fichiers du dossier
for /r "%input_folder%" %%f in (*.enc) do (
    set "relative_path=%%f"
    set "relative_path=!relative_path:%input_folder%=!"
    set "relative_path=!relative_path:.enc=!"
    set "output_file=%output_folder%!relative_path!"
    
    echo Déchiffrement de : %%f
    powershell "Get-Content '%%f' | ConvertTo-SecureString | ConvertFrom-SecureString -AsPlainText | Out-File '!output_file!'"
)

call :log_message "SUCCÈS: Déchiffrement de dossier terminé"
echo.
echo [SUCCÈS] Déchiffrement de dossier terminé avec succès !
goto :eof

:manage_certificates
echo.
echo === GESTION DES CERTIFICATS ===
echo [1] Lister les certificats
echo [2] Installer un certificat
echo [3] Exporter un certificat
echo [4] Supprimer un certificat
echo [5] Vérifier un certificat
echo [6] Retour
echo.
set /p cert_option="Choisissez une option (1-6) : "

if "%cert_option%"=="1" (
    call :list_certificates
) else if "%cert_option%"=="2" (
    call :install_certificate
) else if "%cert_option%"=="3" (
    call :export_certificate
) else if "%cert_option%"=="4" (
    call :delete_certificate
) else if "%cert_option%"=="5" (
    call :verify_certificate
) else if "%cert_option%"=="6" (
    goto :eof
)
goto :eof

:list_certificates
echo.
echo === LISTE DES CERTIFICATS ===
echo Certificats système :
certlm -store -list >> %logfile%
echo Certificats utilisateur :
certmgr -store -list >> %logfile%
echo [INFO] Liste des certificats sauvegardée dans %logfile%
goto :eof

:install_certificate
echo.
echo === INSTALLATION DE CERTIFICAT ===
set /p cert_file="Entrez le chemin du fichier de certificat : "
if not exist "%cert_file%" (
    echo [ERREUR] Le fichier de certificat n'existe pas !
    goto :eof
)
echo Installation du certificat...
certlm -add "%cert_file%"
if %errorlevel% equ 0 (
    echo [SUCCÈS] Certificat installé avec succès !
) else (
    echo [ERREUR] Échec de l'installation du certificat !
)
goto :eof

:export_certificate
echo.
echo === EXPORT DE CERTIFICAT ===
set /p cert_name="Entrez le nom du certificat à exporter : "
set /p export_file="Entrez le chemin du fichier d'export : "
echo Export du certificat...
certlm -export "%cert_name%" "%export_file%"
if %errorlevel% equ 0 (
    echo [SUCCÈS] Certificat exporté avec succès !
) else (
    echo [ERREUR] Échec de l'export du certificat !
)
goto :eof

:delete_certificate
echo.
echo === SUPPRESSION DE CERTIFICAT ===
set /p cert_name="Entrez le nom du certificat à supprimer : "
echo Suppression du certificat...
certlm -delete "%cert_name%"
if %errorlevel% equ 0 (
    echo [SUCCÈS] Certificat supprimé avec succès !
) else (
    echo [ERREUR] Échec de la suppression du certificat !
)
goto :eof

:verify_certificate
echo.
echo === VÉRIFICATION DE CERTIFICAT ===
set /p cert_name="Entrez le nom du certificat à vérifier : "
echo Vérification du certificat...
certlm -verify "%cert_name%"
if %errorlevel% equ 0 (
    echo [SUCCÈS] Certificat valide !
) else (
    echo [ERREUR] Certificat invalide ou expiré !
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

:display_step_header
set "step=%~1"
set "title=%~2"
set "icon=%~3"
echo.
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %TEAL%  ⡇ %WHITE% ◉ ÉTAPE %step%: %title%
echo %TEAL%  ───────────────────────────────────────────────────────────────────────────
echo %WHITE%
goto :eof

:loading_animation
set "text=%~1"
set "frames=0"
echo.
:loading_loop_enc
set /a "percent=frames*5"
set "bar="
set /a "bar_len=percent/5"
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
goto loading_loop_enc
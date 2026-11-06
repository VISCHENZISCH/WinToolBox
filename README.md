# WinToolBox

Boite a outils Windows en ligne de commande : sauvegarde versionnee, disques et partitions,
nettoyage, reparation, reseau, comptes locaux et audit de securite.

Elle n'utilise que des composants fournis avec Windows et ne demande aucune installation.

## Prerequis

- Windows 10 ou 11, avec Windows PowerShell 5.1 (inclus dans Windows)
- Droits administrateur pour les disques, les images systeme et les taches planifiees

## Lancement

Double-cliquez sur `WintoolBox.bat`. Sans droits administrateur, l'outil propose de se relancer
avec ces droits. Les actions qui les exigent sont signalees dans les menus.

## Menu

| Section | Choix | Fonctions |
|---|---|---|
| Donnees | 1. Sauvegarde et restauration | Sauvegardes completes et incrementales, verification, restauration, taches planifiees, image systeme, point de restauration |
| Donnees | 2. Disques et partitions | Vue d'ensemble, sante, analyse, optimisation, creation, redimensionnement, lettre, formatage, suppression |
| Entretien | 3. Nettoyage et reparation | Nettoyage apres analyse, DISM, SFC |
| Administration | 4. Informations systeme | Materiel, processus, demarrage, services en echec |
| Administration | 5. Reseau | Interfaces, test de connexion, ports en ecoute, connexions en direct, cache DNS |
| Administration | 6. Utilisateurs et groupes | Comptes et membres des groupes locaux |
| Protection | 7. Securite et journaux | Audit en lecture seule, journal de l'outil |

## Sauvegardes

Chaque source a son propre dossier dans la destination :

```text
<destination>\<nom>-<empreinte>\
    20260115-200000123-full\   version complete
        data\                  fichiers copies
        files.tsv              etat de la source, empreintes SHA-256
        dirs.txt               dossiers, y compris vides
        errors.txt             fichiers et dossiers non sauvegardes
        meta.json              resume de la version
    20260116-200000456-incr\   ne contient que les fichiers modifies
```

- **Restauration :** chaque version peut etre restauree directement, en entier ou avec un filtre.
- **Integrite :** les copies sont controlees par empreinte SHA-256, puis les fichiers restaures aussi.
- **Interruption :** une version inachevee n'est jamais prise en compte et son dossier temporaire est supprime au lancement suivant.
- **Dependances :** une version incrementale a besoin des versions de sa chaine. Supprimez les anciennes versions avec le menu, jamais a la main.
- **Fichiers ouverts :** l'option VSS les copie, avec les droits administrateur.
- **Liens :** les jonctions et les liens symboliques sont ignores et comptes dans le resultat.

### Taches planifiees

Une tache s'execute avec les droits limites du compte courant, y compris s'il n'a pas ouvert de
session. Elle lui donne acces a ses fichiers et aux disques locaux ou externes, mais pas aux
partages reseau ni aux fichiers ouverts (VSS). Par defaut, elle fait une sauvegarde complete toutes
les 7 executions et conserve 4 chaines.

La sauvegarde peut aussi etre lancee en ligne de commande :

```bat
WintoolBox.bat -Task Backup -Source "D:\Documents" -Destination "E:\Sauvegardes" -Mode Incremental -FullEvery 7 -KeepChains 4
```

Codes de sortie : `0` succes, `1` echec, `2` sauvegarde partielle.

## Securite d'utilisation

- Le formatage et la suppression exigent de retaper une phrase exacte. Ils sont refuses sur les partitions systeme et de demarrage.
- Le nettoyage indique d'abord ce qu'il peut supprimer et ne touche jamais aux journaux Windows.
- Le lanceur utilise `-ExecutionPolicy Bypass` pour ce seul processus, sans modifier la configuration de la machine.
- Les journaux (`logs\`) et les rapports (`reports\`) decrivent la machine. Ne les publiez pas.

## Limites

WinToolBox n'est pas un equivalent complet d'AOMEI Backupper ou d'EaseUS Todo Backup. Il ne propose pas :

- le clonage de disque secteur par secteur ;
- de media de demarrage pour restaurer un systeme qui ne demarre plus ;
- la recuperation de partitions ou de fichiers supprimes ;
- la conversion MBR/GPT, ni le deplacement de partitions ;
- la compression ou le chiffrement des sauvegardes de fichiers.

L'image systeme repose sur `wbadmin` et se restaure depuis l'environnement de recuperation de Windows.

## Tests

Sous Windows, dans PowerShell :

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester .\tests
```

## Structure

```text
WintoolBox.bat          lanceur
src\WinToolBox.ps1      point d'entree et menu principal
src\lib\Common.ps1      journal, affichage, saisies, parcours de fichiers
src\modules\*.ps1       un fichier par domaine
tests\                  tests Pester
```

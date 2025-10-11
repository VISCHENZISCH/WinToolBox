# 🧰 WinToolBox - Security Suite v2.0

```
    ██╗    ██╗██╗███╗   ██╗████████╗ ██████╗  ██████╗ ██╗     ██╗██╗  ██╗
    ██║    ██║██║████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██║╚██╗██╔╝
    ██║ █╗ ██║██║██╔██╗ ██║   ██║   ██║   ██║██║   ██║██║     ██║ ╚███╔╝ 
    ██║███╗██║██║██║╚██╗██║   ██║   ██║   ██║██║   ██║██║     ██║ ██╔██╗ 
    ╚███╔███╔╝██║██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝███████╗██║██╔╝ ██╗
     ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═╝
```

## 🔒 Security Suite v2.0 - Professional Edition by vischenzisch

### 🎯 Description
WinToolBox est une suite d'outils d'administration Windows développée entièrement en **Batch (Shell Windows)**.  
Elle permet de réaliser des opérations de maintenance, de sécurité et de gestion système depuis une interface CLI interactive avec des animations de chargement et des diagrammes ASCII.

### 🏗️ Architecture du système

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WinToolBox - Security Suite v2.0                       │
│                   Professional Edition by vischenzisch                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
            ┌───────▼───────┐ ┌─────▼─────┐ ┌─────▼─────┐
            │   Main Menu   │ │  Modules  │ │   Logs    │
            │   Interface   │ │  System   │ │  Reports  │
            └───────────────┘ └───────────┘ └───────────┘
                    │               │               │
            ┌───────▼───────┐ ┌─────▼─────┐ ┌─────▼─────┐
            │ ASCII Logo    │ │ 13 Modules │ │ Detailed │
            │ Loading Anim  │ │ Security   │ │ Reports  │
            │ Progress Bar  │ │ Features   │ │ Logging  │
            └───────────────┘ └───────────┘ └───────────┘
```

### ⚙️ Modules inclus

| # | Module | Icône | Description |
|---|--------|-------|-------------|
| 1 | Informations système | 💻 | Collecte complète des informations système |
| 2 | Nettoyage & optimisation | 🧹 | Nettoyage et optimisation du système |
| 3 | Surveillance réseau | 🌐 | Monitoring et diagnostic réseau |
| 4 | Gestion des utilisateurs | 👥 | Administration des comptes utilisateurs |
| 5 | Sécurité & pare-feu | 🔒 | Configuration et analyse de sécurité |
| 6 | Sauvegarde & restauration | 💾 | Sauvegarde et restauration de données |
| 7 | Audit de sécurité avancé | 🔍 | Audit complet de sécurité |
| 8 | Détection de menaces | 🛡️ | Détection de menaces avancées |
| 9 | Surveillance réseau temps réel | 📡 | Monitoring réseau en temps réel |
| 10 | Scanner de vulnérabilités | 🔎 | Scan de vulnérabilités système |
| 11 | Outils de chiffrement | 🔐 | Chiffrement et déchiffrement |
| 12 | Journalisation sécurisée | 📝 | Gestion des logs sécurisés |
| 13 | Quitter | 🚪 | Fermeture du programme |

### 📁 Structure du projet

```
WinToolBox/
├── 📄 WintoolBox.bat          # Script principal avec logo ASCII
├── 📁 modules/                # Modules spécialisés
│   ├── 💻 sysinfo.bat         # Informations système
│   ├── 🧹 cleanup.bat         # Nettoyage et optimisation
│   ├── 🌐 network.bat         # Surveillance réseau
│   ├── 👥 users.bat           # Gestion utilisateurs
│   ├── 🔒 security.bat        # Sécurité et pare-feu
│   ├── 💾 backup.bat          # Sauvegarde et restauration
│   ├── 🔍 security_audit.bat  # Audit de sécurité avancé
│   ├── 🛡️ threat_detection.bat # Détection de menaces
│   ├── 📡 network_monitoring.bat # Surveillance réseau temps réel
│   ├── 🔎 vulnerability_scanner.bat # Scanner de vulnérabilités
│   ├── 🔐 encryption_tools.bat # Outils de chiffrement
│   └── 📝 secure_logging.bat  # Journalisation sécurisée
└── 📁 logs/                   # Rapports et logs
    ├── 📊 system_report.txt
    ├── 📊 cleanup_report.txt
    ├── 📊 network_report.txt
    └── 📊 ... (autres rapports)
```

### 🚀 Utilisation

```batch
# Afficher le menu et les options
WintoolBox.bat

# Exécuter un module spécifique
WintoolBox.bat 1    # Informations système
WintoolBox.bat 2    # Nettoyage et optimisation
WintoolBox.bat 13   # Quitter
```

### ✨ Nouvelles fonctionnalités v2.0

- 🎨 **Logo ASCII** : Logo professionnel en caractères Unicode
- ⏳ **Animations de chargement** : Barres de progression animées
- 🎯 **Interface améliorée** : Headers de modules avec icônes
- 🔒 **Sécurité renforcée** : 7 nouveaux modules de sécurité
- 📊 **Rapports détaillés** : Logs complets et structurés
- 🎨 **Expérience utilisateur** : Interface plus professionnelle

### 👨‍💻 Auteur
Projet développé par **[vischenzisch]**  
Licence : MIT  
Version : 2.0 - Security Suite Professional Edition by vischenzisch

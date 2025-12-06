#!/bin/bash

# ============================================================================
# Script de compilation Zephyr Wallet GUI pour Linux
# ============================================================================
# Ce script automatise la compilation du wallet Zephyr depuis les sources
# Auteur: Généré pour la compilation de Zephyr Wallet
# Date: 2025-12-06
# ============================================================================

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher des messages colorés
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# ÉTAPE 0 : Vérification des prérequis
# ============================================================================
print_info "Vérification des prérequis..."

if ! command_exists git; then
    print_error "Git n'est pas installé. Installation..."
    sudo apt-get update
    sudo apt-get install -y git
fi

if ! command_exists nvm; then
    print_warning "NVM n'est pas installé. Installation de NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Charger NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# Charger NVM si ce n'est pas déjà fait
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Installer et utiliser Node.js 16
print_info "Installation/activation de Node.js 16..."
nvm install 16
nvm use 16
nvm alias default 16

print_success "Node.js $(node --version) activé"

# Installer les dépendances système pour Electron
print_info "Installation des dépendances système..."
sudo apt-get update
sudo apt-get install -y \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libatspi2.0-0 \
    libdrm2 \
    libgbm1 \
    libxcb-dri3-0 \
    libasound2 \
    build-essential

# ============================================================================
# ÉTAPE 1 : Clonage ou mise à jour du dépôt
# ============================================================================
# Utiliser le répertoire courant comme base
WORK_DIR="$(pwd)"
REPO_DIR="$WORK_DIR/zephyr-wallet"

print_info "Répertoire de travail : $WORK_DIR"

if [ -d "$REPO_DIR" ]; then
    print_warning "Le dossier $REPO_DIR existe déjà."
    read -p "Voulez-vous le supprimer et recloner ? (o/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        print_info "Suppression du dossier existant..."
        rm -rf "$REPO_DIR"
        print_info "Clonage du dépôt Zephyr Wallet..."
        git clone https://github.com/ZephyrProtocol/zephyr-wallet.git "$REPO_DIR"
    else
        print_info "Mise à jour du dépôt existant..."
        cd "$REPO_DIR"
        git pull origin master
    fi
else
    print_info "Clonage du dépôt Zephyr Wallet dans $WORK_DIR..."
    git clone https://github.com/ZephyrProtocol/zephyr-wallet.git "$REPO_DIR"
fi

cd "$REPO_DIR"
print_success "Dépôt prêt dans $REPO_DIR"

# ============================================================================
# ÉTAPE 2 : Compilation du client
# ============================================================================
print_info "Installation des dépendances du client..."
cd "$REPO_DIR/client"
npm install

print_info "Compilation du client pour desktop..."
print_warning "Vous allez devoir choisir le type de réseau (1 pour mainnet)"
npm run build:desktop

print_success "Client compilé avec succès"

# ============================================================================
# ÉTAPE 3 : Préparation de l'application desktop
# ============================================================================
print_info "Installation des dépendances de l'application desktop..."
cd "$REPO_DIR/zephyr-desktop-app"
npm install

# Créer le dossier client et copier les fichiers build
print_info "Copie des fichiers du client compilé..."
mkdir -p "$REPO_DIR/zephyr-desktop-app/client"
cp -r "$REPO_DIR/client/build/"* "$REPO_DIR/zephyr-desktop-app/client/"

print_success "Fichiers copiés avec succès"

# ============================================================================
# ÉTAPE 4 : Construction du paquet .deb
# ============================================================================
print_info "Construction du paquet .deb..."
cd "$REPO_DIR"
chmod +x ./sh/make.sh
./sh/make.sh

print_success "Paquet .deb créé avec succès"

# ============================================================================
# ÉTAPE 5 : Installation (optionnelle)
# ============================================================================
DEB_FILE=$(find "$REPO_DIR/zephyr-desktop-app/out/make/deb/x64" -name "*.deb" | head -n 1)

if [ -f "$DEB_FILE" ]; then
    print_success "Paquet .deb trouvé : $DEB_FILE"
    echo
    read -p "Voulez-vous installer le paquet maintenant ? (o/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        print_info "Désinstallation de l'ancienne version (si présente)..."
        sudo apt remove -y zephyr 2>/dev/null || true
        
        print_info "Installation du nouveau paquet..."
        sudo dpkg -i "$DEB_FILE"
        
        # Corriger les dépendances manquantes si nécessaire
        sudo apt-get install -f -y
        
        print_success "Installation terminée !"
        echo
        print_info "Vous pouvez maintenant lancer Zephyr Wallet avec la commande: zephyr"
    else
        print_info "Le paquet .deb est disponible ici : $DEB_FILE"
        print_info "Vous pouvez l'installer plus tard avec : sudo dpkg -i $DEB_FILE"
    fi
else
    print_error "Aucun paquet .deb trouvé dans out/make/deb/x64"
    exit 1
fi

# ============================================================================
# Résumé final
# ============================================================================
echo
echo "============================================================================"
print_success "COMPILATION TERMINÉE AVEC SUCCÈS !"
echo "============================================================================"
echo
print_info "Emplacements importants :"
echo "  - Code source       : $REPO_DIR"
echo "  - Paquet .deb       : $DEB_FILE"
echo "  - Client compilé    : $REPO_DIR/client/build"
echo
print_info "Pour lancer Zephyr Wallet :"
echo "  zephyr"
echo
print_info "En cas d'écran blanc, essayez :"
echo "  zephyr --no-sandbox"
echo
print_info "Pour désinstaller :"
echo "  sudo apt remove zephyr"
echo
echo "============================================================================"

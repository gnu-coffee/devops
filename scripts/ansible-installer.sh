#!/bin/bash
# =============================================================================
# Script Name: ansible-installer.sh
# Author: gnu-coffee
# Created: 2025-10-07
# Description: Installs Ansible on Debian / Ubuntu 24.04
# License: GNU General Public License
# =============================================================================

set -euo pipefail

# --- Variables ---
SCRIPT_DIR="$(pwd)"
LOG_FILE="${SCRIPT_DIR}/ansible_install.log"

# --- Color codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Marker functions ---
function info() { echo -e "${YELLOW}[*] $1${NC}"; }
function success() { echo -e "${GREEN}[+] $1${NC}"; }
function error() { echo -e "${RED}[-] $1${NC}"; }

# --- Log header ---
echo "=== Ansible Installer Log ===" >> "$LOG_FILE"
echo "Execution Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
success "Log file: $LOG_FILE"

# --- Check if running as root ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root!"
    exit 1
fi

# --- Detect OS ---
OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
info "Detected OS: $OS_ID"

# --- Update package list ---
info "Updating package lists..."
apt update >>"$LOG_FILE" 2>&1

# --- Install dependencies ---
question="Installing dependencies: python3, python3-pip, python3-venv"
info "$question"
apt install -y python3 python3-pip python3-venv libssl-dev libffi-dev build-essential >>"$LOG_FILE" 2>&1
success "Dependencies installed."

# --- Installation based on OS ---
if [[ "$OS_ID" == "ubuntu" ]]; then
    info "Ubuntu detected. Installing Ansible from PPA..."
    sudo add-apt-repository --yes --update ppa:ansible/ansible >>"$LOG_FILE" 2>&1
    sudo apt update >>"$LOG_FILE" 2>&1
    sudo apt install -y ansible >>"$LOG_FILE" 2>&1
    success "Ansible installed via PPA."
elif [[ "$OS_ID" == "debian" ]]; then
    info "Debian detected. Installing latest Ansible via pip..."
    python3 -m pip install --upgrade pip >>"$LOG_FILE" 2>&1
    python3 -m pip install --user ansible >>"$LOG_FILE" 2>&1
    # Add ~/.local/bin to PATH if not already
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        info "Added $HOME/.local/bin to PATH"
    fi
    success "Ansible installed via pip."
else
    error "Unsupported OS: $OS_ID"
    exit 1
fi

# --- Verify installation ---
info "Verifying Ansible installation..."
if ansible --version >>"$LOG_FILE" 2>&1; then
    success "Ansible installed successfully!"
    ansible --version
else
    error "Ansible verification failed."
    exit 1
fi

# --- Final message ---
echo -e "${GREEN}[+] To run Ansible, use: ansible <command>${NC}"

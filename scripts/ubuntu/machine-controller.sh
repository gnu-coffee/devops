#!/bin/bash
# =============================================================================
# Script Name: infra-tools-installer.sh
# Author: gnu-coffee
# Created: 2025-08-17
# Description: Installer for Packer, Terraform, and Ansible on Ubuntu
# License: MIT License
# =============================================================================

# --- Variables ---
SCRIPT_DIR="$(pwd)"
LOG_FILE="${SCRIPT_DIR}/infra_tools_install.log"

# --- Color codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Marker functions ---
function info() { echo -e "${YELLOW}[*] $1${NC}"; }
function question() { echo -e "${YELLOW}[?] $1${NC}"; }
function success() { echo -e "${GREEN}[+] $1${NC}"; }
function error() { echo -e "${RED}[-] $1${NC}"; }

# --- Log file header ---
echo "=== Infra Tools Installer Log ===" >> "$LOG_FILE"
echo "Execution Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
success "Log file: $LOG_FILE"

# --- Check if running as root ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root!"
    exit 1
fi

# --- Check if Ubuntu ---
if ! grep -qi "ubuntu" /etc/os-release; then
    error "This script can only run on Ubuntu!"
    exit 1
fi
success "Running on Ubuntu - proceeding..."

# --- Install required tools ---
question "Checking required tools: curl, software-properties-common"
for cmd in curl software-properties-common; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        info "Required command '$cmd' is missing. Installing..."
        apt update >>"$LOG_FILE" 2>&1 && apt install -y "$cmd" >>"$LOG_FILE" 2>&1
        if [[ $? -ne 0 ]]; then
            error "Failed to install $cmd. Exiting."
            exit 1
        fi
        success "$cmd installed successfully."
    else
        success "$cmd is already installed."
    fi
done

# --- Add HashiCorp GPG key ---
info "Adding HashiCorp GPG key..."
if curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg >>"$LOG_FILE" 2>&1; then
    success "GPG key added successfully."
else
    error "Failed to add GPG key."
    exit 1
fi

# --- Add HashiCorp repository ---
info "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list >>"$LOG_FILE" 2>&1
success "HashiCorp repository added."

# --- Add Ansible PPA ---
info "Adding Ansible PPA..."
if add-apt-repository --yes --update ppa:ansible/ansible >>"$LOG_FILE" 2>&1; then
    success "Ansible PPA added successfully."
else
    error "Failed to add Ansible PPA."
    exit 1
fi

# --- Update repositories ---
info "Updating package lists..."
apt update >>"$LOG_FILE" 2>&1
success "Package lists updated."

# --- Install Packer, Terraform, Ansible ---
for pkg in packer terraform ansible; do
    info "Installing $pkg..."
    if apt install -y "$pkg" >>"$LOG_FILE" 2>&1; then
        success "$pkg installed successfully."
    else
        error "Failed to install $pkg."
        exit 1
    fi
done

# --- Show installed versions ---
success "Installed versions:"
echo -e "${GREEN}Packer: $(packer version)${NC}"
echo -e "${GREEN}Terraform: $(terraform version | head -n1)${NC}"
echo -e "${GREEN}Ansible: $(ansible --version | head -n1)${NC}"

success "Installation completed successfully!"

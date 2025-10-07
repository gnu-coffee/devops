#!/bin/bash
# =============================================================================
# Script Name: terraform-installer.sh
# Author: gnu-coffee
# Created: 2025-08-14
# Last Modified: 2025-10-07
# Description: Terraform installer for Debian / Ubuntu 24.04
# License: MIT License
# =============================================================================

set -euo pipefail

# --- Variables ---
SCRIPT_DIR="$(pwd)"
LOG_FILE="${SCRIPT_DIR}/terraform_install.log"
TMP_DIR="/tmp"

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
echo "=== Terraform Installer Log ===" >> "$LOG_FILE"
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

# --- Check and install dependencies ---
question "Checking required tools: curl, wget, unzip"
for cmd in curl wget unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        info "Required command '$cmd' is missing. Installing..."
        if [[ "$OS_ID" =~ ubuntu|debian ]]; then
            apt update >>"$LOG_FILE" 2>&1
            apt install -y "$cmd" >>"$LOG_FILE" 2>&1
        fi
        success "$cmd installed successfully."
    else
        success "$cmd is already installed."
    fi
done

# --- Determine system architecture ---
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH"; exit 1 ;;
esac
info "System architecture: $ARCH"

# --- Get latest Terraform release from GitHub ---
info "Fetching the latest Terraform version..."
TERRAFORM_RELEASE=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest \
                | grep '"tag_name":' \
                | cut -d '"' -f 4 \
                | sed 's/v//')
if [[ -z "$TERRAFORM_RELEASE" ]]; then
    error "Failed to retrieve the latest Terraform version from GitHub API."
    exit 1
fi
success "Latest Terraform version: $TERRAFORM_RELEASE"
echo "Latest Terraform version: $TERRAFORM_RELEASE" >> "$LOG_FILE"

# --- Download Terraform zip ---
ZIP_FILE="${TMP_DIR}/terraform_${TERRAFORM_RELEASE}_linux_${ARCH}.zip"
info "Downloading Terraform $TERRAFORM_RELEASE to $ZIP_FILE ..."
if wget -O "$ZIP_FILE" "https://releases.hashicorp.com/terraform/${TERRAFORM_RELEASE}/terraform_${TERRAFORM_RELEASE}_linux_${ARCH}.zip" >>"$LOG_FILE" 2>&1; then
    success "Download completed successfully."
else
    error "Download failed."
    exit 1
fi

# --- Unzip Terraform binary ---
info "Unzipping Terraform binary..."
if unzip -o "$ZIP_FILE" -d "$TMP_DIR" >>"$LOG_FILE" 2>&1; then
    success "Unzip completed."
else
    error "Failed to unzip."
    exit 1
fi

# --- Move binary to /usr/local/bin ---
info "Installing Terraform to /usr/local/bin ..."
if mv "$TMP_DIR/terraform" /usr/local/bin/ >>"$LOG_FILE" 2>&1 && chmod +x /usr/local/bin/terraform >>"$LOG_FILE" 2>&1; then
    success "Terraform installed successfully."
else
    error "Failed to install Terraform."
    exit 1
fi

# --- Cleanup ---
info "Cleaning up..."
rm -f "$ZIP_FILE"

# --- Verify installation ---
info "Verifying installation..."
if terraform version >>"$LOG_FILE" 2>&1; then
    success "Terraform installation completed successfully!"
else
    error "Terraform verification failed."
    exit 1
fi

# --- Final message to user ---
echo -e "${GREEN}[+] To run Terraform, use the following command:${NC}"
echo -e "${GREEN}    /usr/local/bin/terraform <command>${NC}"

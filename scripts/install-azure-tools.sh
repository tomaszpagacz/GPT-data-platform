#!/usr/bin/env bash
set -euo pipefail

# This script installs Azure CLI and the Bicep CLI on Debian/Ubuntu-based systems.
# It can be executed locally or inside CI runners prior to building Bicep templates.

if [[ $(id -u) -ne 0 ]]; then
  echo "[ERROR] Please run this script with sudo or as root." >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

AZ_REPO=$(lsb_release -cs)
if [[ -z "${AZ_REPO}" ]]; then
  echo "[ERROR] Unable to determine distribution codename via lsb_release." >&2
  exit 1
fi

# Register the Microsoft package repository if not already present.
if [[ ! -f /etc/apt/sources.list.d/azure-cli.list ]]; then
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >/etc/apt/trusted.gpg.d/microsoft.gpg
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${AZ_REPO} main" >/etc/apt/sources.list.d/azure-cli.list
fi

apt-get update
apt-get install -y azure-cli

# Install the Bicep CLI using the Azure CLI helper.
az bicep install

# Add Bicep CLI to PATH permanently for all future sessions (for the invoking user)
BICEP_BIN="$HOME/.azure/bin"
PROFILE_FILE="$HOME/.bashrc"
if ! grep -q "$BICEP_BIN" "$PROFILE_FILE"; then
  echo "export PATH=\"\$PATH:$BICEP_BIN\"" >> "$PROFILE_FILE"
fi

# Verify installations for the current session
export PATH="$PATH:$BICEP_BIN"
az --version | head -n 1
bicep --version

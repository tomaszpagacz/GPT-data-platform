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

# Install the Bicep CLI by downloading the latest release to /usr/local/bin
BICEP_VERSION=$(curl -s https://api.github.com/repos/Azure/bicep/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -Lo /usr/local/bin/bicep https://github.com/Azure/bicep/releases/download/${BICEP_VERSION}/bicep-linux-x64
chmod +x /usr/local/bin/bicep

# Verify installations for the current session
az --version | head -n 1
bicep --version

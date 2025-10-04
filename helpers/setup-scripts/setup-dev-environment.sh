#!/bin/bash

# Script to set up development environment for GPT-data-platform

# Exit on any error
set -e

echo "Setting up development environment..."

# Check if dotnet is installed
if ! command -v dotnet &> /dev/null; then
    echo "Installing .NET SDK..."
    wget https://dot.net/v1/dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --channel 6.0
    rm dotnet-install.sh
fi

# Install Azure Functions Core Tools
if ! command -v func &> /dev/null; then
    echo "Installing Azure Functions Core Tools..."
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
    sudo apt-get update
    sudo apt-get install azure-functions-core-tools-4
fi

# Install Bicep CLI
if ! command -v bicep &> /dev/null; then
    echo "Installing Bicep CLI..."
    # Install Bicep
    curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
    chmod +x ./bicep
    sudo mv ./bicep /usr/local/bin/bicep
fi

# Install Azure CLI if not present
if ! command -v az &> /dev/null; then
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

echo "Development environment setup complete!"
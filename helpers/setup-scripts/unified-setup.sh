#!/bin/bash

# Unified Development Environment Setup Script for GPT Data Platform
# This script consolidates functionality from multiple helper scripts for better clarity

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTNET_VERSION="8.0"
NODE_VERSION="18.0.0"
NPM_VERSION="9.0.0"

# Usage information
show_usage() {
    echo -e "${BLUE}GPT Data Platform - Unified Environment Setup${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dev-only        Install only development tools (no Azure CLI, minimal setup)"
    echo "  --full            Install all tools including Azure CLI, VS Code extensions"
    echo "  --check           Check current environment without installing anything"
    echo "  --update-dotnet   Update .NET SDK to version 8.0"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --full         # Complete setup for new environment"
    echo "  $0 --dev-only     # Minimal setup for development only"
    echo "  $0 --check        # Check what's installed"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to compare versions
version_compare() {
    printf '%s\n' "$@" | sort -V | head -n1
}

# Function to check .NET SDK version
check_dotnet_version() {
    if command_exists dotnet; then
        local current_version=$(dotnet --version | cut -d. -f1,2)
        echo -e "${GREEN}✓ .NET SDK version: $current_version${NC}"
        
        if [ "$(version_compare "$DOTNET_VERSION" "$current_version")" != "$DOTNET_VERSION" ]; then
            echo -e "${YELLOW}  Warning: Recommended version is $DOTNET_VERSION${NC}"
        fi
    else
        echo -e "${RED}✗ .NET SDK not found${NC}"
        return 1
    fi
}

# Function to install .NET SDK
install_dotnet() {
    if ! command_exists dotnet || [ "$1" = "update" ]; then
        echo -e "${BLUE}Installing .NET SDK $DOTNET_VERSION...${NC}"
        
        # Use the existing dotnet-install.sh in the repo root if available
        if [ -f "/workspaces/GPT-data-platform/dotnet-install.sh" ]; then
            chmod +x /workspaces/GPT-data-platform/dotnet-install.sh
            /workspaces/GPT-data-platform/dotnet-install.sh --channel $DOTNET_VERSION
        else
            wget -q https://dot.net/v1/dotnet-install.sh
            chmod +x dotnet-install.sh
            ./dotnet-install.sh --channel $DOTNET_VERSION
            rm dotnet-install.sh
        fi
        
        # Add dotnet to PATH
        export PATH="$HOME/.dotnet:$PATH"
        echo 'export PATH="$HOME/.dotnet:$PATH"' >> ~/.bashrc
        
        echo -e "${GREEN}✓ .NET SDK $DOTNET_VERSION installed${NC}"
    else
        echo -e "${GREEN}✓ .NET SDK already installed${NC}"
    fi
}

# Function to check Azure Functions Core Tools
check_azure_functions() {
    if command_exists func; then
        local version=$(func --version)
        echo -e "${GREEN}✓ Azure Functions Core Tools version: $version${NC}"
    else
        echo -e "${RED}✗ Azure Functions Core Tools not found${NC}"
        return 1
    fi
}

# Function to install Azure Functions Core Tools
install_azure_functions() {
    if ! command_exists func; then
        echo -e "${BLUE}Installing Azure Functions Core Tools...${NC}"
        
        # Add Microsoft repository
        curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
        
        sudo apt-get update -qq
        sudo apt-get install -y azure-functions-core-tools-4
        
        echo -e "${GREEN}✓ Azure Functions Core Tools installed${NC}"
    else
        echo -e "${GREEN}✓ Azure Functions Core Tools already installed${NC}"
    fi
}

# Function to check Node.js and npm
check_nodejs() {
    if command_exists node; then
        local node_version=$(node --version | cut -d 'v' -f 2)
        local npm_version=$(npm --version)
        echo -e "${GREEN}✓ Node.js version: $node_version${NC}"
        echo -e "${GREEN}✓ npm version: $npm_version${NC}"
        
        if [ "$(version_compare "$NODE_VERSION" "$node_version")" != "$NODE_VERSION" ]; then
            echo -e "${YELLOW}  Warning: Recommended Node.js version is >= $NODE_VERSION${NC}"
        fi
    else
        echo -e "${RED}✗ Node.js not found${NC}"
        return 1
    fi
}

# Function to install Node.js
install_nodejs() {
    if ! command_exists node; then
        echo -e "${BLUE}Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo -e "${GREEN}✓ Node.js and npm installed${NC}"
    else
        echo -e "${GREEN}✓ Node.js already installed${NC}"
    fi
}

# Function to check Bicep CLI
check_bicep() {
    if command_exists bicep; then
        local version=$(bicep --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "${GREEN}✓ Bicep CLI version: $version${NC}"
    else
        echo -e "${RED}✗ Bicep CLI not found${NC}"
        return 1
    fi
}

# Function to install Bicep CLI
install_bicep() {
    if ! command_exists bicep; then
        echo -e "${BLUE}Installing Bicep CLI...${NC}"
        curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
        chmod +x ./bicep
        sudo mv ./bicep /usr/local/bin/bicep
        echo -e "${GREEN}✓ Bicep CLI installed${NC}"
    else
        echo -e "${GREEN}✓ Bicep CLI already installed${NC}"
    fi
}

# Function to check Azure CLI
check_azure_cli() {
    if command_exists az; then
        local version=$(az --version | head -1 | cut -d' ' -f2)
        echo -e "${GREEN}✓ Azure CLI version: $version${NC}"
    else
        echo -e "${RED}✗ Azure CLI not found${NC}"
        return 1
    fi
}

# Function to install Azure CLI
install_azure_cli() {
    if ! command_exists az; then
        echo -e "${BLUE}Installing Azure CLI...${NC}"
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        echo -e "${GREEN}✓ Azure CLI installed${NC}"
    else
        echo -e "${GREEN}✓ Azure CLI already installed${NC}"
    fi
}

# Function to check VS Code and extensions
check_vscode() {
    if command_exists code; then
        echo -e "${GREEN}✓ VS Code available${NC}"
        
        # Check key extensions
        local required_extensions=(
            "ms-dotnettools.csdevkit"
            "ms-azuretools.vscode-bicep"
            "ms-vscode.vscode-node-azure-pack"
            "github.copilot"
        )
        
        local missing_extensions=()
        for ext in "${required_extensions[@]}"; do
            if ! code --list-extensions | grep -q "$ext"; then
                missing_extensions+=("$ext")
            fi
        done
        
        if [ ${#missing_extensions[@]} -eq 0 ]; then
            echo -e "${GREEN}✓ All recommended VS Code extensions installed${NC}"
        else
            echo -e "${YELLOW}  Missing VS Code extensions: ${missing_extensions[*]}${NC}"
        fi
    else
        echo -e "${RED}✗ VS Code not found in PATH${NC}"
        return 1
    fi
}

# Function to install VS Code extensions
install_vscode_extensions() {
    if command_exists code; then
        echo -e "${BLUE}Installing VS Code extensions...${NC}"
        
        local extensions=(
            "ms-dotnettools.csdevkit"
            "ms-dotnettools.csharp"
            "ms-azuretools.vscode-bicep"
            "ms-vscode.vscode-node-azure-pack"
            "ms-azuretools.vscode-docker"
            "github.copilot"
            "github.copilot-chat"
            "redhat.vscode-yaml"
            "editorconfig.editorconfig"
        )
        
        for ext in "${extensions[@]}"; do
            echo "Installing $ext..."
            code --install-extension "$ext" --force 2>/dev/null || true
        done
        
        echo -e "${GREEN}✓ VS Code extensions installed${NC}"
    else
        echo -e "${YELLOW}VS Code not found, skipping extension installation${NC}"
    fi
}

# Function to check project dependencies
check_project_deps() {
    echo -e "\n${BLUE}Checking project-specific dependencies...${NC}"
    
    # Check if we're in the correct directory
    if [ ! -f "/workspaces/GPT-data-platform/global.json" ]; then
        echo -e "${RED}✗ Not in GPT-data-platform workspace${NC}"
        return 1
    fi
    
    # Check if local.settings.json exists for functions
    local functions_dir="/workspaces/GPT-data-platform/src/functions"
    if [ -d "$functions_dir" ]; then
        local settings_files=$(find "$functions_dir" -name "local.settings.json" 2>/dev/null | wc -l)
        if [ "$settings_files" -gt 0 ]; then
            echo -e "${GREEN}✓ Found $settings_files local.settings.json files${NC}"
        else
            echo -e "${YELLOW}  Warning: No local.settings.json files found in functions${NC}"
        fi
    fi
    
    # Check if NuGet packages are restored
    if command_exists dotnet; then
        echo "Checking .NET project dependencies..."
        cd /workspaces/GPT-data-platform
        if dotnet restore --verbosity quiet; then
            echo -e "${GREEN}✓ .NET dependencies restored${NC}"
        else
            echo -e "${YELLOW}  Warning: Issues with .NET dependency restoration${NC}"
        fi
        cd - > /dev/null
    fi
}

# Function to run environment check
run_check() {
    echo -e "${BLUE}=== GPT Data Platform Environment Check ===${NC}\n"
    
    echo "1. Checking .NET SDK..."
    check_dotnet_version || true
    
    echo -e "\n2. Checking Azure Functions Core Tools..."
    check_azure_functions || true
    
    echo -e "\n3. Checking Node.js and npm..."
    check_nodejs || true
    
    echo -e "\n4. Checking Bicep CLI..."
    check_bicep || true
    
    echo -e "\n5. Checking Azure CLI..."
    check_azure_cli || true
    
    echo -e "\n6. Checking VS Code..."
    check_vscode || true
    
    check_project_deps
    
    echo -e "\n${BLUE}=== Environment Check Complete ===${NC}"
}

# Function to run development-only setup
run_dev_setup() {
    echo -e "${BLUE}=== Development-Only Setup ===${NC}\n"
    
    install_dotnet
    install_azure_functions
    install_bicep
    check_project_deps
    
    echo -e "\n${GREEN}✓ Development environment setup complete!${NC}"
    echo -e "${YELLOW}Note: Azure CLI not installed (use --full for complete setup)${NC}"
}

# Function to run full setup
run_full_setup() {
    echo -e "${BLUE}=== Full Environment Setup ===${NC}\n"
    
    install_dotnet
    install_azure_functions
    install_nodejs
    install_bicep
    install_azure_cli
    install_vscode_extensions
    check_project_deps
    
    echo -e "\n${GREEN}✓ Full environment setup complete!${NC}"
    echo -e "${BLUE}You may need to restart your terminal or run 'source ~/.bashrc' to update PATH${NC}"
}

# Main script logic
case "${1:-}" in
    --help)
        show_usage
        exit 0
        ;;
    --check)
        run_check
        ;;
    --dev-only)
        run_dev_setup
        ;;
    --full)
        run_full_setup
        ;;
    --update-dotnet)
        install_dotnet "update"
        ;;
    "")
        echo -e "${YELLOW}No option specified. Use --help for usage information.${NC}"
        echo -e "${BLUE}Quick start:${NC}"
        echo "  For development only: $0 --dev-only"
        echo "  For complete setup:   $0 --full"
        echo "  To check current:     $0 --check"
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_usage
        exit 1
        ;;
esac
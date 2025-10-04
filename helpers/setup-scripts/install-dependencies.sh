#!/bin/bash

# Script to install all required dependencies for the project

echo "Installing project dependencies..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install .NET 6.0 SDK if not present
install_dotnet() {
    if ! command_exists dotnet; then
        echo "Installing .NET 6.0 SDK..."
        wget https://dot.net/v1/dotnet-install.sh
        chmod +x dotnet-install.sh
        ./dotnet-install.sh --version 6.0.100
        rm dotnet-install.sh
        # Add dotnet to PATH
        export PATH="$HOME/.dotnet:$PATH"
        echo 'export PATH="$HOME/.dotnet:$PATH"' >> ~/.bashrc
    else
        echo ".NET SDK already installed"
    fi
}

# Install Node.js and npm if not present or if version is incorrect
install_nodejs() {
    local required_node_version="18.0.0"
    local required_npm_version="9.0.0"

    if ! command_exists node; then
        echo "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        local current_node_version=$(node --version | cut -d 'v' -f 2)
        local current_npm_version=$(npm --version)

        if [ "$(printf '%s\n' "$required_node_version" "$current_node_version" | sort -V | head -n1)" != "$required_node_version" ]; then
            echo "Updating Node.js (current: $current_node_version, required: >= $required_node_version)..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
        else
            echo "Node.js version $current_node_version is compatible"
        fi

        if [ "$(printf '%s\n' "$required_npm_version" "$current_npm_version" | sort -V | head -n1)" != "$required_npm_version" ]; then
            echo "Updating npm (current: $current_npm_version, required: >= $required_npm_version)..."
            npm install -g npm@latest
        else
            echo "npm version $current_npm_version is compatible"
        fi
    fi
}

# Install Azure Functions Core Tools with version check
install_azure_functions_tools() {
    local required_version="4.0.0"

    if ! command_exists func; then
        echo "Installing Azure Functions Core Tools..."
        npm install -g azure-functions-core-tools@4
    else
        local current_version=$(func --version | grep -oP '\d+\.\d+\.\d+')
        if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" != "$required_version" ]; then
            echo "Updating Azure Functions Core Tools (current: $current_version, required: >= $required_version)..."
            npm install -g azure-functions-core-tools@4
        else
            echo "Azure Functions Core Tools version $current_version is compatible"
        fi
    fi

    # Install extension bundle
    local bundle_path="$HOME/data/Functions/ExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle"
    if [ ! -d "$bundle_path" ]; then
        echo "Installing Azure Functions extension bundle..."
        mkdir -p "$bundle_path"
        func extensions install
    else
        echo "Azure Functions extension bundle already installed"
    fi
}

# Install Azurite for local storage emulation
install_azurite() {
    if ! npm list -g azurite >/dev/null 2>&1; then
        echo "Installing Azurite..."
        npm install -g azurite
    else
        local current_version=$(npm list -g azurite | grep azurite@ | cut -d'@' -f 2)
        echo "Azurite version $current_version is already installed"
    fi
}

# Install jq for JSON processing
install_jq() {
    if ! command_exists jq; then
        echo "Installing jq..."
        sudo apt-get update
        sudo apt-get install -y jq
    else
        local current_version=$(jq --version | cut -d '-' -f 2)
        echo "jq version $current_version is already installed"
    fi
}

# Install Azure CLI if not present
install_azure_cli() {
    if ! command_exists az; then
        echo "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        echo "Azure CLI already installed"
    fi
}

# Install Bicep CLI if not present
install_bicep() {
    if ! command_exists bicep; then
        echo "Installing Bicep CLI..."
        # First ensure Azure CLI is installed
        install_azure_cli
        az bicep install
    else
        echo "Bicep CLI already installed"
    fi
}

# Install VS Code extensions
install_vscode_extensions() {
    if command_exists code; then
        echo "Installing essential VS Code extensions..."
        
        # Core development extensions
        code --install-extension ms-dotnettools.csharp
        code --install-extension ms-azuretools.vscode-azurefunctions
        code --install-extension ms-azuretools.vscode-logicapps
        code --install-extension ms-azuretools.vscode-bicep
        code --install-extension ms-vscode.azure-account
        code --install-extension ms-vscode.azurecli
        
        # Testing
        code --install-extension formulahendry.dotnet-test-explorer
        
        # Infrastructure
        code --install-extension ms-azuretools.vscode-docker
        
        # Productivity
        code --install-extension editorconfig.editorconfig
        code --install-extension visualstudioexptteam.vscodeintellicode
        
        # REST API testing
        code --install-extension humao.rest-client
        
        echo "Essential VS Code extensions installed. Additional recommended extensions can be found in .vscode/extensions.json"
    else
        echo "VS Code not found - skipping extension installation"
    fi
}

# Restore project dependencies
restore_project() {
    echo "Restoring project dependencies..."
    # Main project restore
    dotnet restore /workspaces/GPT-data-platform/src/functions/location-intelligence/location-intelligence.csproj
    
    # Test project restore with specific package versions
    dotnet restore /workspaces/GPT-data-platform/tests/LocationIntelligence.Tests/LocationIntelligence.Tests.csproj
    
    # Ensure specific test package versions
    echo "Ensuring correct test package versions..."
    cd /workspaces/GPT-data-platform/tests/LocationIntelligence.Tests
    dotnet add package xunit.runner.visualstudio --version 2.5.7
    cd - > /dev/null # Return to previous directory
}

# Main installation sequence
main() {
    install_dotnet
    install_nodejs
    install_azure_functions_tools
    install_azure_cli
    install_bicep
    install_azurite
    install_jq
    install_vscode_extensions
    restore_project
    
    echo "All dependencies installed successfully!"
    echo ""
    echo "Environment details:"
    echo "Node.js: $(node --version)"
    echo "npm: $(npm --version)"
    echo "Azure Functions Core Tools: $(func --version)"
    echo "Azurite: $(npm list -g azurite | grep azurite@ | cut -d'@' -f 2)"
    echo "jq: $(jq --version)"
    echo "dotnet: $(dotnet --version)"
    echo "Azure CLI: $(az --version | grep 'azure-cli')"
    echo "Bicep CLI: $(bicep --version)"
}

# Run the installation
main
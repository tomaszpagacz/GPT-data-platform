#!/bin/bash

# Script to set up local development environment consistently across platforms

echo "Setting up local development environment..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check .NET SDK version
check_dotnet_version() {
    required_version="6.0"
    if command_exists dotnet; then
        current_version=$(dotnet --version | cut -d. -f1,2)
        if [ "$current_version" != "$required_version" ]; then
            echo "Error: .NET SDK version $required_version is required. Found version $current_version"
            echo "Please install .NET SDK $required_version from https://dotnet.microsoft.com/download/dotnet/6.0"
            exit 1
        fi
        echo ".NET SDK version $current_version is compatible"
    else
        echo "Error: .NET SDK is not installed"
        echo "Please install .NET SDK $required_version from https://dotnet.microsoft.com/download/dotnet/6.0"
        exit 1
    fi
}

# Function to check VS Code extensions
check_vscode_extensions() {
    if ! command_exists code; then
        echo "Warning: VS Code not found in PATH. Please install VS Code and 'code' command line tool"
        return
    fi

    required_extensions=(
        "ms-dotnettools.csdevkit"
        "ms-dotnettools.csharp"
        "ms-dotnettools.vscode-dotnet-runtime"
        "ms-dotnettools.vscodeintellicode-csharp"
        "ms-vscode.vscode-node-azure-pack"
        "ms-azuretools.vscode-bicep"
        "formulahendry.dotnet-test-explorer"
        "ms-azure-devops.azure-pipelines"
        "ms-azuretools.vscode-docker"
        "redhat.vscode-yaml"
        "editorconfig.editorconfig"
        "github.copilot"
        "github.copilot-chat"
        "humao.rest-client"
        "eamodio.gitlens"
        "ms-azuretools.vscode-azurestorage"
        "ms-azuretools.vscode-apimanagement"
    )

    echo "Checking VS Code extensions..."
    for ext in "${required_extensions[@]}"; do
        if ! code --list-extensions | grep -q "^$ext$"; then
            echo "Installing VS Code extension: $ext"
            code --install-extension "$ext"
        else
            echo "Extension already installed: $ext"
        fi
    done
}

# Function to set up local settings files
setup_local_settings() {
    local functions_dir="src/functions"
    
    # For each function app
    for func_app in "$functions_dir"/*; do
        if [ -d "$func_app" ]; then
            local settings_file="$func_app/local.settings.json"
            if [ ! -f "$settings_file" ]; then
                echo "Creating local settings file for $(basename "$func_app")"
                cat > "$settings_file" << EOF
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet",
        "FUNCTIONS_EXTENSION_VERSION": "~4"
    }
}
EOF
            fi
        fi
    done
}

# Function to clean and rebuild solution
clean_and_rebuild() {
    echo "Cleaning solution..."
    dotnet clean
    
    echo "Removing bin and obj directories..."
    find . -type d -name "bin" -o -name "obj" | xargs rm -rf
    
    echo "Restoring NuGet packages..."
    dotnet restore
    
    echo "Building solution..."
    dotnet build --configuration Debug
}

# Function to create/update solution file
setup_solution() {
    echo "Setting up solution file..."
    if [ -f "GPT-data-platform.sln" ]; then
        rm GPT-data-platform.sln
    fi
    
    dotnet new sln -n GPT-data-platform
    
    # Add all projects to solution
    find . -name "*.csproj" -exec dotnet sln GPT-data-platform.sln add {} \;
}

# Main setup sequence
main() {
    echo "=== Starting local environment setup ==="
    
    # Change to repository root
    cd "$(dirname "$0")/../.." || exit 1
    
    # Check prerequisites
    check_dotnet_version
    check_vscode_extensions
    
    # Setup solution and local settings
    setup_solution
    setup_local_settings
    
    # Clean and rebuild
    clean_and_rebuild
    
    echo "=== Local environment setup complete ==="
    echo ""
    echo "Next steps:"
    echo "1. Review and update local.settings.json files in function apps with your local values"
    echo "2. Restart VS Code to ensure all extensions are properly loaded"
    echo "3. Run 'dotnet test' to verify everything is working"
}

# Run setup
main
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running workspace environment checks...${NC}\n"

# Check GitHub Codespace environment
echo "1. Checking GitHub Codespace environment..."
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "${GREEN}✓ Running in GitHub Codespace: $CODESPACE_NAME${NC}"
else
    echo -e "${RED}✗ Not running in GitHub Codespace${NC}"
fi

# Check .NET environment
echo -e "\n2. Checking .NET environment..."
if command -v dotnet &> /dev/null; then
    DOTNET_VERSION=$(dotnet --version)
    echo -e "${GREEN}✓ .NET SDK version: $DOTNET_VERSION${NC}"
    
    # Check if required .NET packages are available
    echo "Checking required .NET packages..."
    dotnet restore /workspaces/GPT-data-platform/src/functions/location-intelligence/location-intelligence.csproj
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Function project packages restored successfully${NC}"
    else
        echo -e "${RED}✗ Failed to restore function project packages${NC}"
    fi
    
    # Check test project
    if [ -f "/workspaces/GPT-data-platform/tests/LocationIntelligence.Tests/LocationIntelligence.Tests.csproj" ]; then
        dotnet restore /workspaces/GPT-data-platform/tests/LocationIntelligence.Tests/LocationIntelligence.Tests.csproj
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Test project packages restored successfully${NC}"
        else
            echo -e "${RED}✗ Failed to restore test project packages${NC}"
        fi
    else
        echo -e "${RED}✗ Test project not found at expected location${NC}"
    fi
else
    echo -e "${RED}✗ .NET SDK not found${NC}"
fi

# Check Azure Functions Core Tools
echo -e "\n3. Checking Azure Functions Core Tools..."
if command -v func &> /dev/null; then
    FUNC_VERSION=$(func --version)
    echo -e "${GREEN}✓ Azure Functions Core Tools version: $FUNC_VERSION${NC}"
else
    echo -e "${RED}✗ Azure Functions Core Tools not found${NC}"
fi

# Check local.settings.json
echo -e "\n4. Checking local.settings.json..."
if [ -f "/workspaces/GPT-data-platform/src/functions/location-intelligence/local.settings.json" ]; then
    echo -e "${GREEN}✓ local.settings.json exists${NC}"
    # Check if it contains required settings without exposing sensitive data
    if grep -q "AzureWebJobsStorage" "/workspaces/GPT-data-platform/src/functions/location-intelligence/local.settings.json"; then
        echo -e "${GREEN}✓ Contains storage connection setting${NC}"
    else
        echo -e "${RED}✗ Missing storage connection setting${NC}"
    fi
else
    echo -e "${RED}✗ local.settings.json not found${NC}"
fi

# Check project references
echo -e "\n5. Checking project references..."
if grep -q "xunit" "/workspaces/GPT-data-platform/tests/LocationIntelligence.Tests/LocationIntelligence.Tests.csproj"; then
    echo -e "${GREEN}✓ xUnit references found in test project${NC}"
else
    echo -e "${RED}✗ xUnit references not found in test project${NC}"
fi

# Check Git configuration
echo -e "\n6. Checking Git configuration..."
if [ -d "/workspaces/GPT-data-platform/.git" ]; then
    echo -e "${GREEN}✓ Git repository initialized${NC}"
    BRANCH_NAME=$(git branch --show-current)
    echo -e "${GREEN}✓ Current branch: $BRANCH_NAME${NC}"
else
    echo -e "${RED}✗ Not a Git repository${NC}"
fi

# Final summary
echo -e "\n${YELLOW}Environment Check Summary:${NC}"
echo "========================================"
echo "Workspace: /workspaces/GPT-data-platform"
echo "Function Project: src/functions/location-intelligence"
echo "Test Project: tests/LocationIntelligence.Tests"
echo "----------------------------------------"
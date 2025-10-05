#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Azure CLI and login status
echo -e "${YELLOW}Checking Azure CLI and authentication...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI is not installed${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}Not logged into Azure. Please run 'az login'${NC}"
    exit 1
fi

# Function to check resource provider registration
check_provider() {
    local provider=$1
    local status=$(az provider show --namespace $provider --query "registrationState" -o tsv)
    if [ "$status" != "Registered" ]; then
        echo -e "${YELLOW}Provider $provider is not registered. Registering...${NC}"
        az provider register --namespace $provider
        return 1
    fi
    return 0
}

# Check required resource providers
echo -e "\n${YELLOW}Checking resource provider registration...${NC}"
providers=(
    "Microsoft.Storage"
    "Microsoft.Synapse"
    "Microsoft.KeyVault"
    "Microsoft.Web"
    "Microsoft.EventGrid"
    "Microsoft.Network"
    "Microsoft.OperationalInsights"
    "Microsoft.CognitiveServices"
    "Microsoft.Maps"
)

all_providers_registered=true
for provider in "${providers[@]}"; do
    if ! check_provider $provider; then
        all_providers_registered=false
    fi
done

if [ "$all_providers_registered" = false ]; then
    echo -e "${YELLOW}Waiting for provider registration to complete...${NC}"
    sleep 30
fi

# Check subscription quotas
echo -e "\n${YELLOW}Checking subscription quotas...${NC}"
location=${1:-"switzerlandnorth"}

check_quota() {
    local resource=$1
    local limit=$2
    local current=$(az vm list-usage --location $location --query "[?name.value=='$resource'].currentValue" -o tsv)
    local max=$(az vm list-usage --location $location --query "[?name.value=='$resource'].limit" -o tsv)
    
    if [ -z "$current" ] || [ -z "$max" ]; then
        echo -e "${YELLOW}Could not retrieve quota information for $resource${NC}"
        return
    fi
    
    local available=$((max - current))
    if [ $available -lt $limit ]; then
        echo -e "${RED}Warning: Only $available $resource available, need $limit${NC}"
        return 1
    else
        echo -e "${GREEN}Sufficient $resource quota available ($available)${NC}"
        return 0
    fi
}

# Check specific quotas
quotas_ok=true
if ! check_quota "standardESv3Family" 4; then quotas_ok=false; fi
if ! check_quota "virtualMachines" 10; then quotas_ok=false; fi
if ! check_quota "totalRegionalvCPUs" 20; then quotas_ok=false; fi

# Check networking limits
echo -e "\n${YELLOW}Checking networking limits...${NC}"
subscription_id=$(az account show --query id -o tsv)
vnet_count=$(az network vnet list --query "length(@)" -o tsv)
subnet_limit=3

if [ $vnet_count -gt 50 ]; then
    echo -e "${RED}Warning: High number of VNets ($vnet_count). Limit is 1000 per subscription${NC}"
    quotas_ok=false
fi

# Validate resource names
echo -e "\n${YELLOW}Validating resource names...${NC}"
name_prefix=${2:-"gptdata"}
environment=${3:-"dev"}

# Check storage account name
storage_name="${name_prefix}${environment}dls"
if [ ${#storage_name} -gt 24 ] || [ ${#storage_name} -lt 3 ]; then
    echo -e "${RED}Storage account name $storage_name is invalid (must be between 3-24 characters)${NC}"
    quotas_ok=false
fi

if ! [[ $storage_name =~ ^[a-z0-9]*$ ]]; then
    echo -e "${RED}Storage account name $storage_name contains invalid characters${NC}"
    quotas_ok=false
fi

# Final status
echo -e "\n${YELLOW}=== Deployment Prerequisites Check Summary ===${NC}"
if [ "$quotas_ok" = true ]; then
    echo -e "${GREEN}All checks passed. Deployment can proceed.${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed. Review warnings above before deploying.${NC}"
    exit 1
fi
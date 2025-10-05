#!/bin/bash

# Script to validate environment readiness for deployments
# Usage: ./validate-environment.sh <environment> <region> <resource-group>

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message=$*
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2
            ;;
    esac
}

# Validate input parameters
if [ "$#" -ne 3 ]; then
    log ERROR "Usage: $0 <environment> <region> <resource-group>"
    log ERROR "Example: $0 dev westeurope rg-data-platform-dev"
    exit 1
fi

# Set variables
ENV=$1
LOCATION=$2
RESOURCE_GROUP=$3

# Check Azure CLI installation and login status
log INFO "Checking Azure CLI status..."
if ! command -v az &> /dev/null; then
    log ERROR "Azure CLI is not installed"
    exit 1
fi

if ! az account show &> /dev/null; then
    log ERROR "Not logged into Azure CLI"
    exit 1
fi

# Check resource group
log INFO "Checking resource group..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    log ERROR "Resource group $RESOURCE_GROUP does not exist"
    exit 1
fi

# Check networking prerequisites
log INFO "Checking networking prerequisites..."

# VNET checks
VNET_NAME="vnet-${ENV}"
if ! az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    log ERROR "Required VNET $VNET_NAME not found"
    exit 1
fi

# Subnet checks
REQUIRED_SUBNETS=("snet-private-endpoints" "snet-functions" "snet-logic-apps")
for subnet in "${REQUIRED_SUBNETS[@]}"; do
    if ! az network vnet subnet show --name "$subnet" --vnet-name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log ERROR "Required subnet $subnet not found in VNET $VNET_NAME"
        exit 1
    fi
done

# Private DNS zones check
REQUIRED_DNS_ZONES=(
    "privatelink.eventgrid.azure.net"
    "privatelink.servicebus.windows.net"
    "privatelink.azurewebsites.net"
    "privatelink.blob.core.windows.net"
)

for zone in "${REQUIRED_DNS_ZONES[@]}"; do
    if ! az network private-dns zone show --name "$zone" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log ERROR "Required private DNS zone $zone not found"
        exit 1
    fi
done

# Check VNET links in DNS zones
for zone in "${REQUIRED_DNS_ZONES[@]}"; do
    if ! az network private-dns link vnet list \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$zone" \
        --query "[?virtualNetwork.id.contains(@, '${VNET_NAME}')]" \
        --output tsv &> /dev/null; then
        log ERROR "VNET link not found for DNS zone $zone"
        exit 1
    fi
done

# Check resource providers
log INFO "Checking required resource providers..."
REQUIRED_PROVIDERS=(
    "Microsoft.EventGrid"
    "Microsoft.EventHub"
    "Microsoft.Network"
    "Microsoft.OperationalInsights"
    "Microsoft.Insights"
)

for provider in "${REQUIRED_PROVIDERS[@]}"; do
    PROVIDER_STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
    if [ "$PROVIDER_STATE" != "Registered" ]; then
        log ERROR "Resource provider $provider is not registered"
        exit 1
    fi
done

# Check role assignments
log INFO "Checking role assignments..."
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)

REQUIRED_ROLES=(
    "Contributor"
    "Private DNS Zone Contributor"
    "Network Contributor"
)

for role in "${REQUIRED_ROLES[@]}"; do
    if ! az role assignment list \
        --resource-group "$RESOURCE_GROUP" \
        --assignee "$CURRENT_USER_ID" \
        --query "[?roleDefinitionName=='$role']" \
        --output tsv &> /dev/null; then
        log WARN "Current user does not have $role role in resource group $RESOURCE_GROUP"
    fi
done

# Check KeyVault access
log INFO "Checking Key Vault access..."
KV_NAME="kv-${ENV}-${RESOURCE_GROUP}"
if ! az keyvault show --name "$KV_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    log WARN "Key Vault $KV_NAME not found"
else
    if ! az keyvault list --resource-group "$RESOURCE_GROUP" --query "[?properties.enableRbacAuthorization]" -o tsv &> /dev/null; then
        log WARN "Key Vault $KV_NAME does not have RBAC authorization enabled"
    fi
fi

# Final validation status
log INFO "Environment validation completed"
echo ""
echo "Validation Summary:"
echo "==================="
echo "✓ Azure CLI Status"
echo "✓ Resource Group"
echo "✓ Virtual Network"
echo "✓ Required Subnets"
echo "✓ Private DNS Zones"
echo "✓ Resource Providers"
echo "✓ Role Assignments"
echo "✓ Key Vault Access"

exit 0
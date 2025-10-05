#!/bin/bash

# Script to deploy event handling infrastructure
# Usage: ./deploy-eventing.sh <environment> <region> <resource-group>

set -e

# Enable debug logging
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

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
    log ERROR "Example: $0 dev westeurope rg-gpt-data-platform-dev"
    exit 1
fi

# Set variables
ENV=$1
LOCATION=$2
RESOURCE_GROUP=$3

# Function to check dependencies
check_dependencies() {
    log INFO "Checking required dependencies..."
    
    # Check for required tools
    for cmd in az jq; do
        if ! command -v $cmd &> /dev/null; then
            log ERROR "$cmd is required but not installed."
            exit 1
        fi
    done
    
    # Check Azure CLI logged in
    if ! az account show &> /dev/null; then
        log ERROR "Not logged into Azure CLI"
        exit 1
    fi

    # Check networking dependencies
    log INFO "Checking networking dependencies..."
    
    # Check VNET exists
    VNET_NAME="vnet-${ENV}"
    if ! az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log ERROR "Required VNET '$VNET_NAME' not found in resource group '$RESOURCE_GROUP'"
        exit 1
    fi
    
    # Check required subnets exist
    SUBNET_NAME="snet-private-endpoints"
    if ! az network vnet subnet show --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log ERROR "Required subnet '$SUBNET_NAME' not found in VNET '$VNET_NAME'"
        exit 1
    fi
    
    # Check DNS zones exist
    local required_dns_zones=("privatelink.eventgrid.azure.net" "privatelink.servicebus.windows.net")
    for zone in "${required_dns_zones[@]}"; do
        if ! az network private-dns zone show --name "$zone" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
            log ERROR "Required private DNS zone '$zone' not found"
            exit 1
        fi
    done
    
    log INFO "All dependencies verified successfully"
}

# Function to validate deployment
validate_deployment() {
    local resource_type=$1
    local resource_name=$2
    local max_attempts=30
    local sleep_time=10
    
    log INFO "Validating deployment of $resource_type: $resource_name"
    
    for ((i=1; i<=max_attempts; i++)); do
        if [[ "$resource_type" == "eventhubs" ]]; then
            PROVISIONING_STATE=$(az eventhubs namespace show \
                --name "$resource_name" \
                --resource-group "$RESOURCE_GROUP" \
                --query "provisioningState" -o tsv 2>/dev/null)
        elif [[ "$resource_type" == "eventgrid" ]]; then
            PROVISIONING_STATE=$(az eventgrid topic show \
                --name "$resource_name" \
                --resource-group "$RESOURCE_GROUP" \
                --query "provisioningState" -o tsv 2>/dev/null)
        fi
        
        if [[ "$PROVISIONING_STATE" == "Succeeded" ]]; then
            log INFO "$resource_type $resource_name deployment successful"
            return 0
        elif [[ "$PROVISIONING_STATE" == "Failed" ]]; then
            log ERROR "$resource_type $resource_name deployment failed"
            exit 1
        fi
        
        log INFO "Waiting for $resource_type $resource_name deployment... Attempt $i/$max_attempts"
        sleep $sleep_time
    done
    
    log ERROR "Timeout waiting for $resource_type $resource_name deployment"
    exit 1
}

# Main execution starts here
log INFO "Starting deployment for environment: $ENV"
TEMPLATE_FILE="infra/modules/eventing.bicep"
PARAMS_FILE="infra/params/$ENV.eventing.parameters.json"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|sit|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, sit, prod"
    exit 1
fi

# Check if files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

if [ ! -f "$PARAMS_FILE" ]; then
    echo "Error: Parameters file not found: $PARAMS_FILE"
    exit 1
fi

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

# Get networking details
echo "Getting private endpoint subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "vnet-$ENV" \
    --name "snet-private-endpoints" \
    --query id -o tsv)

# Get private DNS zone IDs
echo "Getting private DNS zone IDs..."
EVENTGRID_DNS_ZONE_ID=$(az network private-dns zone show \
    --resource-group "$RESOURCE_GROUP" \
    --name "privatelink.eventgrid.azure.net" \
    --query id -o tsv)

EVENTHUB_DNS_ZONE_ID=$(az network private-dns zone show \
    --resource-group "$RESOURCE_GROUP" \
    --name "privatelink.servicebus.windows.net" \
    --query id -o tsv)

# Deploy infrastructure
echo "Deploying event infrastructure for environment: $ENV"
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMS_FILE" \
    --parameters \
        privateEndpointSubnetId="$SUBNET_ID" \
        privateDnsZoneIds="['$EVENTGRID_DNS_ZONE_ID', '$EVENTHUB_DNS_ZONE_ID']"

# Validate deployment
echo "Validating deployment..."

# Check Event Hub Namespace
NAMESPACE_NAME=$(az eventhubs namespace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?contains(name, 'evthub')].name" -o tsv)

if [ -z "$NAMESPACE_NAME" ]; then
    echo "Error: Event Hub Namespace deployment failed"
    exit 1
fi

# Check Event Grid Topic
TOPIC_NAME=$(az eventgrid topic list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?contains(name, 'evtgrid')].name" -o tsv)

if [ -z "$TOPIC_NAME" ]; then
    echo "Error: Event Grid Topic deployment failed"
    exit 1
fi

# Check private endpoints
echo "Checking private endpoints..."
az network private-endpoint list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?contains(name, 'evthub') || contains(name, 'evtgrid')].{Name:name, Status:privateLinkServiceConnections[0].provisioningState}" \
    -o table

echo "Deployment completed successfully!"
echo "Event Hub Namespace: $NAMESPACE_NAME"
echo "Event Grid Topic: $TOPIC_NAME"

# Print monitoring info
echo "Use the following Azure CLI commands to monitor events:"
echo "Event Hub monitoring:"
echo "az eventhubs eventhub show-message-count --resource-group $RESOURCE_GROUP --namespace-name $NAMESPACE_NAME --name storage-monitoring"
echo ""
echo "Event Grid monitoring:"
echo "az eventgrid topic show --resource-group $RESOURCE_GROUP --name $TOPIC_NAME --query publicNetworkAccess"
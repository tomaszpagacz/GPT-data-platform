#!/bin/bash

# Modern Data Platform Health Check Script
# This script validates the deployment of all modern platform components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP=""
ENVIRONMENT=""
NAME_PREFIX=""

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "FAILED")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to check if resource exists
check_resource() {
    local resource_name=$1
    local resource_type=$2
    local resource_group=$3
    
    if az resource show --name "$resource_name" --resource-type "$resource_type" --resource-group "$resource_group" &>/dev/null; then
        print_status "SUCCESS" "$resource_type: $resource_name exists"
        return 0
    else
        print_status "FAILED" "$resource_type: $resource_name does not exist"
        return 1
    fi
}

# Function to check service health
check_service_health() {
    local service_name=$1
    local service_type=$2
    local resource_group=$3
    
    case $service_type in
        "purview")
            local status=$(az purview account show --name "$service_name" --resource-group "$resource_group" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "ml")
            local status=$(az ml workspace show --name "$service_name" --resource-group "$resource_group" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "aks")
            local status=$(az aks show --name "$service_name" --resource-group "$resource_group" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "fabric")
            local status=$(az fabric capacity show --name "$service_name" --resource-group "$resource_group" --query "properties.state" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "container")
            local status=$(az container show --name "$service_name" --resource-group "$resource_group" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "apim")
            local status=$(az apim show --name "$service_name" --resource-group "$resource_group" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
            ;;
        "function")
            local status=$(az functionapp show --name "$service_name" --resource-group "$resource_group" --query "state" -o tsv 2>/dev/null || echo "NotFound")
            ;;
    esac
    
    if [ "$status" = "Succeeded" ] || [ "$status" = "Running" ] || [ "$status" = "Active" ]; then
        print_status "SUCCESS" "$service_type: $service_name is healthy (Status: $status)"
        return 0
    else
        print_status "FAILED" "$service_type: $service_name is not healthy (Status: $status)"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--name-prefix)
            NAME_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -g <resource-group> -e <environment> -p <name-prefix>"
            echo "Example: $0 -g rg-dataplatform-dev -e dev -p gptdata"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ] || [ -z "$ENVIRONMENT" ] || [ -z "$NAME_PREFIX" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 -g <resource-group> -e <environment> -p <name-prefix>"
    exit 1
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Modern Data Platform Health Check${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Environment: $ENVIRONMENT"
echo "Name Prefix: $NAME_PREFIX"
echo ""

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Check Core Infrastructure
echo -e "${BLUE}Checking Core Infrastructure...${NC}"

# Storage Account
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_resource "${NAME_PREFIX}stor${ENVIRONMENT}" "Microsoft.Storage/storageAccounts" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Key Vault
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_resource "${NAME_PREFIX}-kv-${ENVIRONMENT}" "Microsoft.KeyVault/vaults" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Log Analytics
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_resource "${NAME_PREFIX}-log-${ENVIRONMENT}" "Microsoft.OperationalInsights/workspaces" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Virtual Network
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_resource "${NAME_PREFIX}-vnet-${ENVIRONMENT}" "Microsoft.Network/virtualNetworks" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""

# Check Modern Platform Services
echo -e "${BLUE}Checking Modern Platform Services...${NC}"

# Microsoft Purview
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-purview-${ENVIRONMENT}" "purview" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Azure Machine Learning
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-ml-${ENVIRONMENT}" "ml" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Azure Kubernetes Service
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-aks-${ENVIRONMENT}" "aks" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Microsoft Fabric
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-fabric-${ENVIRONMENT}" "fabric" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# Container Instances
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-aci-${ENVIRONMENT}" "container" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# API Management
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-apigw-${ENVIRONMENT}" "apim" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""

# Check Upgraded Services
echo -e "${BLUE}Checking Upgraded Services...${NC}"

# Azure Functions (.NET 8)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_service_health "${NAME_PREFIX}-func-${ENVIRONMENT}" "function" "$RESOURCE_GROUP"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    
    # Check .NET 8 runtime
    RUNTIME=$(az functionapp config show --name "${NAME_PREFIX}-func-${ENVIRONMENT}" --resource-group "$RESOURCE_GROUP" --query "linuxFxVersion" -o tsv 2>/dev/null || echo "Unknown")
    if [[ "$RUNTIME" == *"dotnet-isolated"* ]]; then
        print_status "SUCCESS" "Functions: .NET 8 isolated runtime confirmed"
    else
        print_status "WARNING" "Functions: Runtime may not be .NET 8 isolated ($RUNTIME)"
    fi
fi

echo ""

# Check Connectivity and Network Security
echo -e "${BLUE}Checking Network Security...${NC}"

# Check private endpoints
PRIVATE_ENDPOINTS=$(az network private-endpoint list --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
print_status "INFO" "Private Endpoints found: $PRIVATE_ENDPOINTS"

# Check NSG rules
NSGS=$(az network nsg list --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
print_status "INFO" "Network Security Groups found: $NSGS"

echo ""

# Additional Health Checks
echo -e "${BLUE}Additional Health Checks...${NC}"

# Check AKS nodes (if AKS exists)
if az aks show --name "${NAME_PREFIX}-aks-${ENVIRONMENT}" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    # Get AKS credentials (suppress output)
    az aks get-credentials --name "${NAME_PREFIX}-aks-${ENVIRONMENT}" --resource-group "$RESOURCE_GROUP" --overwrite-existing &>/dev/null
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_status "SUCCESS" "AKS: $NODE_COUNT nodes available"
        
        # Check node status
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
        print_status "INFO" "AKS: $READY_NODES/$NODE_COUNT nodes ready"
    else
        print_status "WARNING" "AKS: No nodes found or kubectl not configured"
    fi
fi

# Check API Management APIs (if APIM exists)
if az apim show --name "${NAME_PREFIX}-apigw-${ENVIRONMENT}" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    API_COUNT=$(az apim api list --service-name "${NAME_PREFIX}-apigw-${ENVIRONMENT}" --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    print_status "INFO" "API Management: $API_COUNT APIs configured"
fi

echo ""

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Health Check Summary${NC}"
echo -e "${BLUE}================================${NC}"

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ $SUCCESS_RATE -eq 100 ]; then
    print_status "SUCCESS" "All checks passed ($PASSED_CHECKS/$TOTAL_CHECKS)"
    echo -e "${GREEN}✓ Modern Data Platform is fully operational!${NC}"
elif [ $SUCCESS_RATE -ge 80 ]; then
    print_status "WARNING" "Most checks passed ($PASSED_CHECKS/$TOTAL_CHECKS - $SUCCESS_RATE%)"
    echo -e "${YELLOW}⚠ Platform is mostly operational with some issues${NC}"
else
    print_status "FAILED" "Many checks failed ($PASSED_CHECKS/$TOTAL_CHECKS - $SUCCESS_RATE%)"
    echo -e "${RED}✗ Platform has significant issues requiring attention${NC}"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Review failed checks and resolve issues"
echo "2. Configure data sources in Purview"
echo "3. Set up ML experiments and pipelines"
echo "4. Deploy applications to AKS"
echo "5. Configure Power BI reports and dashboards"
echo "6. Test API endpoints and GraphQL queries"

# Exit with appropriate code
if [ $SUCCESS_RATE -eq 100 ]; then
    exit 0
elif [ $SUCCESS_RATE -ge 80 ]; then
    exit 1
else
    exit 2
fi
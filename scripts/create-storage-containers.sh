#!/bin/bash

# Azure Storage Container Creation Script
# Creates medallion architecture containers and additional data platform containers

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default containers
DEFAULT_CONTAINERS=(
    # Medallion Architecture
    "bronze"      # Raw data landing zone
    "silver"      # Cleaned and processed data
    "gold"        # Business-ready curated data

    # Testing & Development
    "test"        # Test data and validation datasets
    "functional"  # Functional testing data

    # Data Processing
    "raw"         # Alternative raw data or different data types
    "temp"        # Temporary processing data
    "checkpoints" # Streaming checkpoints and state

    # Operations
    "logs"        # Application and system logs
    "metadata"    # Data catalog metadata and schemas
    "archive"     # Archived historical data
    "quarantine"  # Data that failed validation or processing
)

# Functions
print_header() {
    echo -e "${CYAN}🚀 Azure Storage Container Creation Script${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group RESOURCE_GROUP    Azure resource group name (required)"
    echo "  -s, --storage-account STORAGE_ACCOUNT  Azure storage account name (required)"
    echo "  -c, --containers CONTAINER1,CONTAINER2  Comma-separated list of containers to create"
    echo "  -S, --subscription SUBSCRIPTION_ID      Azure subscription ID"
    echo "  --use-managed-identity                  Use managed identity instead of account key"
    echo "  -h, --help                             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -g myresourcegroup -s mystorageaccount"
    echo "  $0 -g myresourcegroup -s mystorageaccount -c bronze,silver,gold"
    echo "  $0 -g myresourcegroup -s mystorageaccount -S 12345678-1234-1234-1234-123456789012"
    echo ""
    echo "Default containers created:"
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        echo "  - $container"
    done
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_az_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi

    log_success "Azure CLI authentication verified"
}

get_storage_account_info() {
    local rg=$1
    local sa=$2
    local sub=$3

    log_info "Retrieving storage account information..."

    local az_cmd="az storage account show --name $sa --resource-group $rg --output json"
    if [ -n "$sub" ]; then
        az_cmd="$az_cmd --subscription $sub"
    fi

    if ! storage_info=$(eval "$az_cmd" 2>/dev/null); then
        log_error "Failed to retrieve storage account information"
        return 1
    fi

    sa_name=$(echo "$storage_info" | jq -r '.name')
    sa_rg=$(echo "$storage_info" | jq -r '.resourceGroup')
    sa_location=$(echo "$storage_info" | jq -r '.location')
    sa_kind=$(echo "$storage_info" | jq -r '.kind')
    sa_sku=$(echo "$storage_info" | jq -r '.sku.name')

    echo -e "${CYAN}📊 Storage Account Details:${NC}"
    echo "  Name: $sa_name"
    echo "  Resource Group: $sa_rg"
    echo "  Location: $sa_location"
    echo "  Kind: $sa_kind"
    echo "  SKU: $sa_sku"
    echo ""
}

create_container() {
    local sa=$1
    local container=$2
    local key=$3
    local sub=$4

    log_info "Creating container: $container"

    local az_cmd="az storage container create --name $container --account-name $sa --account-key '$key' --output json"
    if [ -n "$sub" ]; then
        az_cmd="$az_cmd --subscription $sub"
    fi

    if eval "$az_cmd" &>/dev/null; then
        log_success "Container '$container' created successfully"
        return 0
    else
        log_warning "Container '$container' may already exist"
        return 1
    fi
}

create_container_managed_identity() {
    local sa=$1
    local container=$2
    local sub=$3

    log_info "Creating container: $container (using managed identity)"

    local az_cmd="az storage container create --name $container --account-name $sa --output json --auth-mode login"
    if [ -n "$sub" ]; then
        az_cmd="$az_cmd --subscription $sub"
    fi

    if eval "$az_cmd" &>/dev/null; then
        log_success "Container '$container' created successfully"
        return 0
    else
        log_warning "Container '$container' may already exist or access denied"
        return 1
    fi
}

show_container_purposes() {
    echo -e "${CYAN}📋 Container Purposes:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cat << 'EOF'
• bronze      - Raw data landing zone - initial ingestion point for all data sources
• silver      - Cleaned and processed data - transformed, validated, and enriched data
• gold        - Business-ready curated data - aggregated, modeled data for analytics and reporting
• test        - Test data and validation datasets - used for testing pipelines and applications
• functional  - Functional testing data - datasets for functional testing scenarios
• raw         - Alternative raw data storage - for different data types or ingestion methods
• temp        - Temporary processing data - intermediate results and temporary files
• checkpoints - Streaming checkpoints and state - for Spark Streaming, Event Hubs, etc.
• logs        - Application and system logs - audit trails, error logs, performance metrics
• metadata    - Data catalog metadata and schemas - table schemas, data lineage, quality metrics
• archive     - Archived historical data - cold storage for compliance and historical analysis
• quarantine  - Data quarantine zone - data that failed validation or processing rules
EOF
    echo ""
}

# Parse command line arguments
RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
CONTAINERS=()
SUBSCRIPTION=""
USE_MANAGED_IDENTITY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -c|--containers)
            IFS=',' read -ra CONTAINERS <<< "$2"
            shift 2
            ;;
        -S|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        --use-managed-identity)
            USE_MANAGED_IDENTITY=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ] || [ -z "$STORAGE_ACCOUNT" ]; then
    log_error "Resource group and storage account name are required"
    print_usage
    exit 1
fi

# Use default containers if none specified
if [ ${#CONTAINERS[@]} -eq 0 ]; then
    CONTAINERS=("${DEFAULT_CONTAINERS[@]}")
fi

# Main execution
print_header

# Check Azure CLI
check_az_cli

# Get storage account info
if ! get_storage_account_info "$RESOURCE_GROUP" "$STORAGE_ACCOUNT" "$SUBSCRIPTION"; then
    exit 1
fi

# Show container purposes
show_container_purposes

# Create containers
created_count=0
failed_count=0

echo -e "${CYAN}🔨 Creating containers...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$USE_MANAGED_IDENTITY" = true ]; then
    # Use managed identity
    for container in "${CONTAINERS[@]}"; do
        if create_container_managed_identity "$STORAGE_ACCOUNT" "$container" "$SUBSCRIPTION"; then
            ((created_count++))
        else
            ((failed_count++))
        fi
    done
else
    # Get storage account key
    log_info "Retrieving storage account key..."
    az_cmd="az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --output json"
    if [ -n "$SUBSCRIPTION" ]; then
        az_cmd="$az_cmd --subscription $SUBSCRIPTION"
    fi

    if ! keys=$(eval "$az_cmd" 2>/dev/null); then
        log_error "Failed to retrieve storage account keys"
        exit 1
    fi

    storage_key=$(echo "$keys" | jq -r '.[0].value')

    # Create containers with account key
    for container in "${CONTAINERS[@]}"; do
        if create_container "$STORAGE_ACCOUNT" "$container" "$storage_key" "$SUBSCRIPTION"; then
            ((created_count++))
        else
            ((failed_count++))
        fi
    done
fi

# Summary
echo ""
echo -e "${CYAN}📈 Summary:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Containers processed: $created_count${NC}"
echo -e "${RED}❌ Containers failed: $failed_count${NC}"

if [ $failed_count -eq 0 ]; then
    echo ""
    log_success "All containers processed successfully!"
    echo -e "${CYAN}💡 Next steps:${NC}"
    echo "   • Configure appropriate RBAC permissions for data access"
    echo "   • Set up data lifecycle management policies"
    echo "   • Configure monitoring and alerting for storage metrics"
else
    echo ""
    log_warning "Some containers failed to create. Please check the errors above."
    exit 1
fi
#!/bin/bash

# Pipeline Configuration Upload Script
# Uploads Logic Apps pipeline routing configurations to Azure Storage

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CONFIG_DIR="/workspaces/GPT-data-platform/src/logic-apps/config"
CONTAINER_NAME="config"

print_header() {
    echo -e "${CYAN}📤 Pipeline Configuration Upload Script${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group RESOURCE_GROUP    Azure resource group name (required)"
    echo "  -s, --storage-account STORAGE_ACCOUNT  Azure storage account name (required)"
    echo "  -e, --environment ENV                  Environment (dev, sit, prod) - defaults to all"
    echo "  -S, --subscription SUBSCRIPTION_ID      Azure subscription ID"
    echo "  --use-managed-identity                  Use managed identity instead of account key"
    echo "  -h, --help                             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -g myresourcegroup -s mystorageaccount"
    echo "  $0 -g myresourcegroup -s mystorageaccount -e dev"
    echo "  $0 -g myresourcegroup -s mystorageaccount -S 12345678-1234-1234-1234-123456789012"
    echo ""
    echo "Configuration files uploaded:"
    echo "  - pipelines.dev.json"
    echo "  - pipelines.sit.json"
    echo "  - pipelines.prod.json"
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

upload_config_file() {
    local rg=$1
    local sa=$2
    local sub=$3
    local use_mi=$4
    local config_file=$5

    if [[ ! -f "$CONFIG_DIR/$config_file" ]]; then
        log_warning "Configuration file $config_file not found, skipping"
        return 0
    fi

    log_info "Uploading $config_file to $CONTAINER_NAME container..."

    if [[ "$use_mi" == "true" ]]; then
        az storage blob upload \
            --account-name "$sa" \
            --container-name "$CONTAINER_NAME" \
            --name "$config_file" \
            --file "$CONFIG_DIR/$config_file" \
            --auth-mode login \
            --overwrite true \
            --output none
    else
        local account_key
        account_key=$(az storage account keys list \
            --resource-group "$rg" \
            --account-name "$sa" \
            --query '[0].value' \
            --output tsv)

        az storage blob upload \
            --account-name "$sa" \
            --container-name "$CONTAINER_NAME" \
            --name "$config_file" \
            --file "$CONFIG_DIR/$config_file" \
            --account-key "$account_key" \
            --overwrite true \
            --output none
    fi

    log_success "Uploaded $config_file"
}

main() {
    local resource_group=""
    local storage_account=""
    local subscription=""
    local environment=""
    local use_managed_identity=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--resource-group)
                resource_group="$2"
                shift 2
                ;;
            -s|--storage-account)
                storage_account="$2"
                shift 2
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -S|--subscription)
                subscription="$2"
                shift 2
                ;;
            --use-managed-identity)
                use_managed_identity=true
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
    if [[ -z "$resource_group" ]]; then
        log_error "Resource group is required. Use -g or --resource-group"
        exit 1
    fi

    if [[ -z "$storage_account" ]]; then
        log_error "Storage account is required. Use -s or --storage-account"
        exit 1
    fi

    # Set subscription if provided
    if [[ -n "$subscription" ]]; then
        az account set --subscription "$subscription"
        log_info "Switched to subscription: $subscription"
    fi

    print_header

    # Check prerequisites
    check_az_cli

    # Verify config directory exists
    if [[ ! -d "$CONFIG_DIR" ]]; then
        log_error "Configuration directory not found: $CONFIG_DIR"
        exit 1
    fi

    # Determine which config files to upload
    local config_files=()
    if [[ -n "$environment" ]]; then
        config_files=("pipelines.${environment}.json")
    else
        config_files=("pipelines.dev.json" "pipelines.sit.json" "pipelines.prod.json")
    fi

    # Upload each configuration file
    for config_file in "${config_files[@]}"; do
        upload_config_file "$resource_group" "$storage_account" "$subscription" "$use_managed_identity" "$config_file"
    done

    log_success "All pipeline configuration files uploaded successfully!"
    log_info "Files are now available at: https://${storage_account}.blob.core.windows.net/${CONTAINER_NAME}/"
}

# Run main function with all arguments
main "$@"
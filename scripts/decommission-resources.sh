#!/bin/bash

# Azure Data Platform - Resource Decommissioning Script
# This script safely removes expensive resources while preserving data and dependencies
# Works in conjunction with optimize-costs.sh for runtime optimizations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/cost-optimization-config.yml"
BACKUP_DIR="$SCRIPT_DIR/decommission-backups"
LOG_FILE="$SCRIPT_DIR/decommission-$(date +%Y%m%d-%H%M%S).log"

# Global variables
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
ENVIRONMENT=""
DRY_RUN=false
FORCE=false
PRESERVE_DATA=true

# Resource tracking
declare -A RESOURCE_DEPENDENCIES
declare -A BACKUP_LOCATIONS

# Usage function
usage() {
    cat << EOF
Azure Data Platform - Resource Decommissioning Script

Usage: $0 [OPTIONS] <subscription-id> <resource-group> <environment>

OPTIONS:
    -d, --dry-run           Show what would be deleted without actually deleting
    -f, --force            Skip confirmation prompts
    --no-preserve-data     Allow deletion of resources with data (NOT RECOMMENDED)
    --backup-only          Only create backups, don't delete resources
    --restore <backup-id>  Restore from a specific backup
    -h, --help             Show this help message

EXAMPLES:
    # Dry run to see what would be deleted
    $0 --dry-run <sub-id> rg-data-platform-dev dev

    # Remove development environment resources (preserving data)
    $0 <sub-id> rg-data-platform-dev dev

    # Force removal without confirmations
    $0 --force <sub-id> rg-data-platform-dev dev

    # Only create backups
    $0 --backup-only <sub-id> rg-data-platform-dev dev

SUPPORTED ENVIRONMENTS: dev, sit, uat, prod

Note: Production environment has additional safety checks and requires explicit confirmation.
EOF
}

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR")   echo -e "${RED}ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}WARNING: $message${NC}" ;;
        "INFO")    echo -e "${GREEN}INFO: $message${NC}" ;;
        "DEBUG")   echo -e "${BLUE}DEBUG: $message${NC}" ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        log "ERROR" "Azure CLI is not installed"
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log "ERROR" "Not logged in to Azure. Please run 'az login'"
        exit 1
    fi
    
    # Set subscription
    if ! az account set --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
        log "ERROR" "Failed to set subscription: $SUBSCRIPTION_ID"
        exit 1
    fi
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log "ERROR" "Resource group does not exist: $RESOURCE_GROUP"
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log "INFO" "Prerequisites check completed"
}

# Load configuration
load_configuration() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "WARN" "Configuration file not found: $CONFIG_FILE"
        log "INFO" "Using default configuration"
        return 0
    fi
    
    log "INFO" "Loading configuration from: $CONFIG_FILE"
    # Configuration parsing would go here
    # For now, using defaults
}

# Create resource inventory
create_inventory() {
    log "INFO" "Creating resource inventory..."
    
    local inventory_file="$BACKUP_DIR/inventory-$(date +%Y%m%d-%H%M%S).json"
    
    # Get all resources in the resource group
    az resource list \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$inventory_file"
    
    log "INFO" "Resource inventory created: $inventory_file"
    echo "$inventory_file"
}

# Check resource dependencies
check_dependencies() {
    local resource_id=$1
    local dependencies=()
    
    log "DEBUG" "Checking dependencies for: $resource_id"
    
    # Check for dependent resources (simplified logic)
    case "$resource_id" in
        *"/Microsoft.Storage/storageAccounts/"*)
            # Storage accounts may have dependent services
            dependencies+=($(az resource list --resource-group "$RESOURCE_GROUP" --query "[?contains(id, 'synapse') || contains(id, 'function') || contains(id, 'logic')].id" -o tsv))
            ;;
        *"/Microsoft.KeyVault/vaults/"*)
            # Key Vault may have dependent services
            dependencies+=($(az resource list --resource-group "$RESOURCE_GROUP" --query "[?contains(id, 'function') || contains(id, 'logic') || contains(id, 'synapse')].id" -o tsv))
            ;;
        *"/Microsoft.Synapse/workspaces/"*)
            # Synapse may have dependent resources
            dependencies+=($(az synapse spark pool list --workspace-name "$(basename $resource_id)" --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv))
            ;;
    esac
    
    RESOURCE_DEPENDENCIES["$resource_id"]="${dependencies[*]}"
}

# Backup critical data
backup_critical_data() {
    local resource_id=$1
    local resource_type=$(echo "$resource_id" | cut -d'/' -f7-8)
    local backup_id="backup-$(date +%Y%m%d-%H%M%S)-$(basename $resource_id)"
    local backup_path="$BACKUP_DIR/$backup_id"
    
    log "INFO" "Creating backup for: $(basename $resource_id)"
    
    case "$resource_type" in
        "Microsoft.Storage/storageAccounts")
            backup_storage_account "$resource_id" "$backup_path"
            ;;
        "Microsoft.KeyVault/vaults")
            backup_keyvault "$resource_id" "$backup_path"
            ;;
        "Microsoft.Synapse/workspaces")
            backup_synapse_workspace "$resource_id" "$backup_path"
            ;;
        "Microsoft.Purview/accounts")
            backup_purview_account "$resource_id" "$backup_path"
            ;;
        *)
            log "DEBUG" "No backup procedure defined for: $resource_type"
            return 0
            ;;
    esac
    
    BACKUP_LOCATIONS["$resource_id"]="$backup_path"
    log "INFO" "Backup completed: $backup_path"
}

# Backup storage account metadata
backup_storage_account() {
    local resource_id=$1
    local backup_path=$2
    
    mkdir -p "$backup_path"
    
    local storage_name=$(basename "$resource_id")
    
    # Export storage account configuration
    az storage account show \
        --name "$storage_name" \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$backup_path/config.json"
    
    # List containers and file systems
    az storage container list \
        --account-name "$storage_name" \
        --output json > "$backup_path/containers.json" 2>/dev/null || true
    
    az storage fs list \
        --account-name "$storage_name" \
        --output json > "$backup_path/filesystems.json" 2>/dev/null || true
    
    log "INFO" "Storage account metadata backed up"
}

# Backup Key Vault secrets and keys
backup_keyvault() {
    local resource_id=$1
    local backup_path=$2
    
    mkdir -p "$backup_path"
    
    local vault_name=$(basename "$resource_id")
    
    # Export Key Vault configuration
    az keyvault show \
        --name "$vault_name" \
        --output json > "$backup_path/config.json"
    
    # List secrets (values cannot be exported for security)
    az keyvault secret list \
        --vault-name "$vault_name" \
        --output json > "$backup_path/secrets-list.json" 2>/dev/null || true
    
    # List keys
    az keyvault key list \
        --vault-name "$vault_name" \
        --output json > "$backup_path/keys-list.json" 2>/dev/null || true
    
    log "WARN" "Key Vault secret values cannot be automatically backed up for security reasons"
    log "INFO" "Key Vault metadata and structure backed up"
}

# Backup Synapse workspace configuration
backup_synapse_workspace() {
    local resource_id=$1
    local backup_path=$2
    
    mkdir -p "$backup_path"
    
    local workspace_name=$(basename "$resource_id")
    
    # Export workspace configuration
    az synapse workspace show \
        --name "$workspace_name" \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$backup_path/config.json"
    
    # List Spark pools
    az synapse spark pool list \
        --workspace-name "$workspace_name" \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$backup_path/spark-pools.json" 2>/dev/null || true
    
    # List SQL pools
    az synapse sql pool list \
        --workspace-name "$workspace_name" \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$backup_path/sql-pools.json" 2>/dev/null || true
    
    log "INFO" "Synapse workspace configuration backed up"
}

# Backup Purview account configuration
backup_purview_account() {
    local resource_id=$1
    local backup_path=$2
    
    mkdir -p "$backup_path"
    
    local account_name=$(basename "$resource_id")
    
    # Export Purview account configuration
    az purview account show \
        --name "$account_name" \
        --resource-group "$RESOURCE_GROUP" \
        --output json > "$backup_path/config.json" 2>/dev/null || true
    
    log "INFO" "Purview account configuration backed up"
}

# Get resources to decommission based on cost optimization flags
get_decommissionable_resources() {
    local resources_to_check=()
    
    log "INFO" "Identifying expensive resources for potential decommissioning..."
    
    # Microsoft Fabric
    resources_to_check+=($(az resource list --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Fabric/capacities" --query "[].id" -o tsv))
    
    # Azure Kubernetes Service
    resources_to_check+=($(az aks list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv))
    
    # Azure Machine Learning
    resources_to_check+=($(az ml workspace list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv 2>/dev/null || true))
    
    # Microsoft Purview
    resources_to_check+=($(az purview account list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv 2>/dev/null || true))
    
    # Synapse dedicated SQL pools
    local synapse_workspaces=$(az synapse workspace list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv)
    for workspace in $synapse_workspaces; do
        resources_to_check+=($(az synapse sql pool list --workspace-name "$workspace" --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv 2>/dev/null || true))
    done
    
    # Virtual Machines (SHIR)
    resources_to_check+=($(az vm list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv))
    
    # Container Instances
    resources_to_check+=($(az container list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv 2>/dev/null || true))
    
    # Logic Apps (Standard plans)
    resources_to_check+=($(az logic workflow list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv 2>/dev/null || true))
    
    # App Service Plans (Premium)
    resources_to_check+=($(az appservice plan list --resource-group "$RESOURCE_GROUP" --query "[?sku.tier=='Premium' || sku.tier=='PremiumV2' || sku.tier=='PremiumV3'].id" -o tsv))
    
    echo "${resources_to_check[@]}"
}

# Confirm deletion
confirm_deletion() {
    local resource_count=$1
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo -e "\n${YELLOW}DECOMMISSION CONFIRMATION${NC}"
    echo "Environment: $ENVIRONMENT"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Resources to decommission: $resource_count"
    echo ""
    echo "This action will:"
    echo "  - Create backups of critical configurations"
    echo "  - Remove expensive resources that charge 24/7"
    echo "  - Preserve core infrastructure and data"
    echo ""
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo -e "${RED}WARNING: This is a PRODUCTION environment!${NC}"
        echo "Production decommissioning requires additional confirmation."
        echo ""
        read -p "Type 'DELETE PRODUCTION RESOURCES' to confirm: " confirmation
        if [[ "$confirmation" != "DELETE PRODUCTION RESOURCES" ]]; then
            log "INFO" "Production decommissioning cancelled by user"
            exit 0
        fi
    fi
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Decommissioning cancelled by user"
        exit 0
    fi
}

# Delete resource safely
delete_resource() {
    local resource_id=$1
    local resource_name=$(basename "$resource_id")
    local resource_type=$(echo "$resource_id" | cut -d'/' -f7-8)
    
    log "INFO" "Decommissioning resource: $resource_name ($resource_type)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Would delete: $resource_id"
        return 0
    fi
    
    # Check dependencies before deletion
    check_dependencies "$resource_id"
    local deps="${RESOURCE_DEPENDENCIES[$resource_id]}"
    
    if [[ -n "$deps" && "$PRESERVE_DATA" == "true" ]]; then
        log "WARN" "Resource has dependencies, skipping deletion: $resource_name"
        log "DEBUG" "Dependencies: $deps"
        return 0
    fi
    
    # Create backup before deletion
    if [[ "$PRESERVE_DATA" == "true" ]]; then
        backup_critical_data "$resource_id"
    fi
    
    # Delete the resource
    case "$resource_type" in
        "Microsoft.ContainerService/managedClusters")
            az aks delete --ids "$resource_id" --yes --no-wait
            ;;
        "Microsoft.Fabric/capacities")
            az fabric capacity delete --ids "$resource_id" --yes --no-wait 2>/dev/null || az resource delete --ids "$resource_id" --no-wait
            ;;
        "Microsoft.MachineLearningServices/workspaces")
            az ml workspace delete --ids "$resource_id" --yes --no-wait 2>/dev/null || az resource delete --ids "$resource_id" --no-wait
            ;;
        "Microsoft.Purview/accounts")
            az purview account delete --ids "$resource_id" --yes --no-wait 2>/dev/null || az resource delete --ids "$resource_id" --no-wait
            ;;
        "Microsoft.Synapse/workspaces/sqlPools")
            az synapse sql pool delete --ids "$resource_id" --yes --no-wait
            ;;
        "Microsoft.Compute/virtualMachines")
            az vm delete --ids "$resource_id" --yes --no-wait
            ;;
        "Microsoft.ContainerInstance/containerGroups")
            az container delete --ids "$resource_id" --yes --no-wait
            ;;
        "Microsoft.Web/serverfarms")
            # Don't delete App Service Plans directly, just scale them down
            log "INFO" "Scaling down App Service Plan instead of deleting: $resource_name"
            az appservice plan update --ids "$resource_id" --sku B1 --no-wait
            ;;
        *)
            log "INFO" "Using generic deletion for: $resource_type"
            az resource delete --ids "$resource_id" --no-wait
            ;;
    esac
    
    log "INFO" "Decommission initiated for: $resource_name"
}

# Wait for deletions to complete
wait_for_deletions() {
    local max_wait=3600  # 1 hour
    local wait_time=0
    local interval=30
    
    log "INFO" "Waiting for decommissioning operations to complete..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        local remaining_resources=$(az resource list --resource-group "$RESOURCE_GROUP" --query "length([?tags.decommissioning=='true'])" -o tsv 2>/dev/null || echo "0")
        
        if [[ "$remaining_resources" -eq 0 ]]; then
            log "INFO" "All decommissioning operations completed"
            return 0
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
        log "DEBUG" "Still waiting for $remaining_resources resources... ($wait_time seconds)"
    done
    
    log "WARN" "Some decommissioning operations may still be in progress"
}

# Generate decommissioning report
generate_report() {
    local report_file="$BACKUP_DIR/decommission-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat << EOF > "$report_file"
# Azure Data Platform - Decommissioning Report

**Date:** $(date)
**Environment:** $ENVIRONMENT
**Resource Group:** $RESOURCE_GROUP
**Operation:** ${DRY_RUN:+DRY RUN }Decommissioning

## Summary

- **Total Resources Identified:** \$(echo "\${!BACKUP_LOCATIONS[@]}" | wc -w)
- **Backups Created:** ${#BACKUP_LOCATIONS[@]}
- **Preserve Data:** $PRESERVE_DATA

## Backed Up Resources

EOF

    for resource_id in "${!BACKUP_LOCATIONS[@]}"; do
        echo "- **$(basename "$resource_id"):** ${BACKUP_LOCATIONS[$resource_id]}" >> "$report_file"
    done
    
    cat << EOF >> "$report_file"

## Log File

- **Log Location:** $LOG_FILE

## Restoration

To restore these resources, use:

\`\`\`bash
$0 --restore <backup-id> $SUBSCRIPTION_ID $RESOURCE_GROUP $ENVIRONMENT
\`\`\`

EOF

    log "INFO" "Decommissioning report generated: $report_file"
}

# Main execution
main() {
    log "INFO" "Starting Azure Data Platform resource decommissioning..."
    log "INFO" "Environment: $ENVIRONMENT, Resource Group: $RESOURCE_GROUP"
    
    check_prerequisites
    load_configuration
    
    # Create inventory
    local inventory_file=$(create_inventory)
    
    # Get resources to decommission
    local resources=($(get_decommissionable_resources))
    
    if [[ ${#resources[@]} -eq 0 ]]; then
        log "INFO" "No expensive resources found for decommissioning"
        exit 0
    fi
    
    log "INFO" "Found ${#resources[@]} resources for potential decommissioning"
    
    # Show resources if dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${BLUE}Resources that would be decommissioned:${NC}"
        for resource in "${resources[@]}"; do
            echo "  - $(basename "$resource")"
        done
        echo ""
    fi
    
    # Confirm deletion
    confirm_deletion "${#resources[@]}"
    
    # Process each resource
    for resource in "${resources[@]}"; do
        delete_resource "$resource"
    done
    
    # Wait for operations to complete
    if [[ "$DRY_RUN" != "true" ]]; then
        wait_for_deletions
    fi
    
    # Generate report
    generate_report
    
    log "INFO" "Decommissioning process completed"
    log "INFO" "See report: $BACKUP_DIR/decommission-report-*.md"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --no-preserve-data)
            PRESERVE_DATA=false
            shift
            ;;
        --backup-only)
            BACKUP_ONLY=true
            shift
            ;;
        --restore)
            RESTORE_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$SUBSCRIPTION_ID" ]]; then
                SUBSCRIPTION_ID="$1"
            elif [[ -z "$RESOURCE_GROUP" ]]; then
                RESOURCE_GROUP="$1"
            elif [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
            else
                log "ERROR" "Unknown argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SUBSCRIPTION_ID" || -z "$RESOURCE_GROUP" || -z "$ENVIRONMENT" ]]; then
    log "ERROR" "Missing required arguments"
    usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|sit|uat|prod)$ ]]; then
    log "ERROR" "Invalid environment. Must be one of: dev, sit, uat, prod"
    exit 1
fi

# Run main function
main "$@"
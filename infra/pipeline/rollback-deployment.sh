#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get deployment parameters
deployment_name=$1
resource_group=$2
subscription_id=$3
environment=$4

# Function to log rollback actions
log_rollback() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "rollback_${deployment_name}.log"
    echo -e "${YELLOW}$1${NC}"
}

# Function to check if a resource exists
resource_exists() {
    local resource_id=$1
    az resource show --ids "$resource_id" &>/dev/null
    return $?
}

# Get the list of resources created by the deployment
log_rollback "Starting rollback for deployment: $deployment_name"
log_rollback "Getting deployment resources..."

resources=$(az deployment sub show \
    --name "$deployment_name" \
    --query "properties.outputResources[].id" \
    -o tsv)

if [ -z "$resources" ]; then
    log_rollback "No resources found for deployment"
    exit 0
fi

# Sort resources in reverse dependency order for deletion
declare -a resource_order=(
    "Microsoft.Web/sites"
    "Microsoft.Web/serverfarms"
    "Microsoft.Storage/storageAccounts"
    "Microsoft.Network/privateEndpoints"
    "Microsoft.Network/virtualNetworks"
    "Microsoft.KeyVault/vaults"
    "Microsoft.Synapse/workspaces"
    "Microsoft.EventGrid/topics"
    "Microsoft.OperationalInsights/workspaces"
)

# Function to get resource type priority
get_priority() {
    local resource_type=$1
    for i in "${!resource_order[@]}"; do
        if [[ "${resource_order[$i]}" == "$resource_type" ]]; then
            echo $i
            return
        fi
    done
    echo 999
}

# Sort resources by priority
IFS=$'\n' sorted_resources=($(for res in $resources; do
    type=$(echo $res | awk -F'/' '{print $1"/"$2}')
    priority=$(get_priority "$type")
    echo "$priority|$res"
done | sort -rn | cut -d'|' -f2))

# Rollback each resource
for resource in "${sorted_resources[@]}"; do
    if [ -z "$resource" ]; then continue; fi
    
    log_rollback "Rolling back resource: $resource"
    
    # Check if resource still exists
    if ! resource_exists "$resource"; then
        log_rollback "Resource already deleted: $resource"
        continue
    fi
    
    # Backup resource configuration if possible
    resource_type=$(echo $resource | awk -F'/' '{print $1"/"$2}')
    backup_dir="backup_${deployment_name}"
    mkdir -p "$backup_dir"
    
    az resource show --ids "$resource" > "$backup_dir/$(basename $resource).json" 2>/dev/null
    log_rollback "Configuration backed up to: $backup_dir/$(basename $resource).json"
    
    # Delete the resource
    if az resource delete --ids "$resource" --verbose; then
        log_rollback "Successfully deleted: $resource"
    else
        log_rollback "Failed to delete: $resource"
        echo -e "${RED}Manual intervention may be required for: $resource${NC}"
    fi
done

# Clean up any deployment-specific role assignments
log_rollback "Cleaning up role assignments..."
az role assignment list --query "[?contains(roleDefinitionName, '$deployment_name')]" -o json | \
while read -r role; do
    assignment_id=$(echo $role | jq -r '.id')
    if [ ! -z "$assignment_id" ] && [ "$assignment_id" != "null" ]; then
        az role assignment delete --ids "$assignment_id"
        log_rollback "Deleted role assignment: $assignment_id"
    fi
done

# Final cleanup check
log_rollback "Performing final cleanup verification..."
remaining_resources=$(az resource list --query "[?tags.deployment=='$deployment_name']" -o tsv)
if [ ! -z "$remaining_resources" ]; then
    log_rollback "Warning: Some resources may still exist:"
    echo "$remaining_resources"
fi

log_rollback "Rollback completed for deployment: $deployment_name"
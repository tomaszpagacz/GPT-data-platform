#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

subscription_id=$1
resource_group=$2
environment=$3
config_file="$(dirname "$0")/cost-optimization-config.yml"

# Function to read YAML configuration
parse_yaml() {
    local yaml_file=$1
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*'
    
    # Read the YAML file and parse values
    eval "$(grep -v '^#' "$yaml_file" | sed -e "s|:|=|" -e "s|$s\$||g" \
        -e "s|$s#.*||g" -e "s|$s$w\$s=\$s|=$s|" \
        -e "s|\$s=\$s|\$s=\"|g" -e "s|\$\$|$|g" -e "s|,\$||g" \
        -e "s|\$|}\"|g" -e "s|{|\"|g" -e "s|}|\"|g" \
        -e "s|\[|\"|g" -e "s|\]|\"|g")"
}

# Load configuration
if [ -f "$config_file" ]; then
    parse_yaml "$config_file" "config_"
    
    # Load environment-specific settings
    SYNAPSE_SQL_PAUSE=${config_environments_${environment}_synapseSqlPoolsPause:-true}
    SYNAPSE_SHIR_OPTIMIZE=${config_environments_${environment}_synapseShirOptimize:-false}
    APP_SERVICE_SCALE_DOWN=${config_environments_${environment}_appServiceScaleDown:-true}
    EVENT_HUBS_SCALE_DOWN=${config_environments_${environment}_eventHubsScaleDown:-true}
    VM_DEALLOCATE=${config_environments_${environment}_vmDeallocate:-true}
    AKS_SCALE_DOWN=${config_environments_${environment}_aksScaleDown:-true}
    
    # Load thresholds
    SYNAPSE_SQL_POOL_IDLE_TIME=${config_thresholds_synapseSqlPoolIdleTime:-60}
    APP_SERVICE_MIN_INSTANCES=${config_thresholds_appServiceMinInstances:-1}
    AKS_MIN_NODES=${config_thresholds_aksMinNodes:-1}
else
    echo -e "${YELLOW}Warning: Configuration file not found at $config_file. Using defaults.${NC}"
    # Default values if config file is not found
    SYNAPSE_SQL_PAUSE=${SYNAPSE_SQL_PAUSE:-true}
    SYNAPSE_SHIR_OPTIMIZE=${SYNAPSE_SHIR_OPTIMIZE:-false}
    APP_SERVICE_SCALE_DOWN=${APP_SERVICE_SCALE_DOWN:-true}
    EVENT_HUBS_SCALE_DOWN=${EVENT_HUBS_SCALE_DOWN:-true}
    VM_DEALLOCATE=${VM_DEALLOCATE:-true}
    AKS_SCALE_DOWN=${AKS_SCALE_DOWN:-true}
fi

# Function to log actions
log_action() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1"
}

# Function to wait for operation completion
wait_for_operation() {
    local resource_id=$1
    local operation=$2
    local max_wait=1800  # 30 minutes timeout
    local wait_time=0
    local interval=30

    while [ $wait_time -lt $max_wait ]; do
        status=$(az resource show --ids "$resource_id" --query "properties.${operation}State" -o tsv)
        if [[ "$status" == "Succeeded" || "$status" == "Stopped" || "$status" == "Paused" ]]; then
            return 0
        elif [[ "$status" == "Failed" ]]; then
            return 1
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
        log_action "Waiting for $operation completion... ($wait_time seconds)"
    done
    
    return 1
}

# Pause Synapse SQL Pools
pause_synapse_sql_pools() {
    if [[ "$SYNAPSE_SQL_PAUSE" != "true" ]]; then
        log_action "Synapse SQL pool optimization disabled"
        return 0
    fi

    log_action "Checking Synapse workspaces..."
    
    workspaces=$(az synapse workspace list \
        --resource-group "$resource_group" \
        --query "[].id" -o tsv)
        
    for workspace in $workspaces; do
        log_action "Processing workspace: $workspace"
        
        # Skip SHIR-related resources if optimization is disabled
        if [[ "$SYNAPSE_SHIR_OPTIMIZE" != "true" ]]; then
            shir_count=$(az synapse integration-runtime list \
                --workspace-name $(basename $workspace) \
                --resource-group "$resource_group" \
                --query "length([?type=='SelfHosted'])" -o tsv)
            
            if [[ "$shir_count" -gt 0 ]]; then
                log_action "Skipping workspace with SHIR: $workspace"
                continue
            fi
        fi
        
        # Get SQL pools
        pools=$(az synapse sql pool list \
            --workspace-name $(basename $workspace) \
            --resource-group "$resource_group" \
            --query "[].{id:id, state:properties.status}" -o tsv)
            
        while IFS=$'\t' read -r pool_id state; do
            if [[ "$state" != "Paused" ]]; then
                log_action "Pausing SQL pool: $pool_id"
                az synapse sql pool pause --ids "$pool_id"
                wait_for_operation "$pool_id" "provisioning"
            fi
        done <<< "$pools"
    done
}

# Scale down App Service Plans
scale_down_app_plans() {
    log_action "Checking App Service Plans..."
    
    plans=$(az appservice plan list \
        --resource-group "$resource_group" \
        --query "[?sku.tier=='PremiumV3'].id" -o tsv)
        
    for plan in $plans; do
        log_action "Scaling down plan: $plan"
        az appservice plan update --ids "$plan" --sku P1V3
    done
}

# Scale down Event Hub namespaces
scale_down_eventhubs() {
    log_action "Checking Event Hub namespaces..."
    
    namespaces=$(az eventhubs namespace list \
        --resource-group "$resource_group" \
        --query "[?sku.name=='Premium'].id" -o tsv)
        
    for namespace in $namespaces; do
        if [[ "$environment" != "prod" ]]; then
            log_action "Scaling down Event Hub namespace: $namespace"
            az eventhubs namespace update --ids "$namespace" --sku "Standard" --capacity 1
        fi
    done
}

# Deallocate development/test VMs
deallocate_vms() {
    if [[ "$environment" != "prod" ]]; then
        log_action "Checking Virtual Machines..."
        
        vms=$(az vm list \
            --resource-group "$resource_group" \
            --query "[?powerState=='VM running'].id" -o tsv)
            
        for vm in $vms; do
            log_action "Deallocating VM: $vm"
            az vm deallocate --ids "$vm"
        done
    fi
}

# Scale down AKS clusters
scale_down_aks() {
    if [[ "$environment" != "prod" ]]; then
        log_action "Checking AKS clusters..."
        
        clusters=$(az aks list \
            --resource-group "$resource_group" \
            --query "[].id" -o tsv)
            
        for cluster in $clusters; do
            log_action "Scaling down AKS cluster: $cluster"
            az aks scale --ids "$cluster" --node-count 1
        done
    fi
}

# Main execution
log_action "Starting cost optimization procedures..."

pause_synapse_sql_pools
scale_down_app_plans
scale_down_eventhubs
deallocate_vms
scale_down_aks

log_action "Cost optimization procedures completed."
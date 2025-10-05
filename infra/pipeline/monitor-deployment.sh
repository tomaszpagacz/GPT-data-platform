#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

deployment_name=$1
subscription_id=$2
environment=$3

# Function to log monitoring events
log_monitoring() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "deployment_${deployment_name}_monitoring.log"
    echo -e "${BLUE}$1${NC}"
}

# Function to check resource health
check_resource_health() {
    local resource_id=$1
    local health=$(az resource show --ids "$resource_id" --query "properties.provisioningState" -o tsv 2>/dev/null)
    echo "$health"
}

# Function to monitor metrics
monitor_metrics() {
    local resource_id=$1
    local resource_type=$(echo $resource_id | awk -F'/' '{print $7"/"$8}')
    
    case $resource_type in
        "Microsoft.Storage/storageAccounts")
            az monitor metrics list --resource "$resource_id" --metric "Availability" --interval 5M
            ;;
        "Microsoft.Web/sites")
            az monitor metrics list --resource "$resource_id" --metric "Http5xx" --interval 5M
            ;;
        "Microsoft.Network/virtualNetworks")
            az network watcher test-ip-flow --resource-group $(echo $resource_id | cut -d'/' -f5) \
                --vm $(az vm list --query "[0].id" -o tsv) \
                --direction Inbound --protocol TCP --local 80 --remote 8.8.8.8
            ;;
    esac
}

# Start monitoring
log_monitoring "Starting deployment monitoring for: $deployment_name"

# Monitor deployment progress
while true; do
    deployment_state=$(az deployment sub show --name "$deployment_name" \
        --query "properties.provisioningState" -o tsv)
    
    case $deployment_state in
        "Succeeded")
            log_monitoring "Deployment completed successfully!"
            break
            ;;
        "Failed")
            log_monitoring "Deployment failed!"
            # Trigger rollback script
            ./rollback-deployment.sh "$deployment_name" "$subscription_id" "$environment"
            exit 1
            ;;
        "Running"|"Accepted")
            log_monitoring "Deployment in progress..."
            # Get currently deploying resources
            deploying_resources=$(az deployment sub show --name "$deployment_name" \
                --query "properties.outputResources[?properties.provisioningState=='Running'].id" -o tsv)
            
            for resource in $deploying_resources; do
                health=$(check_resource_health "$resource")
                log_monitoring "Resource: $resource - State: $health"
                
                # Monitor resource-specific metrics
                monitor_metrics "$resource"
            done
            ;;
        *)
            log_monitoring "Unknown deployment state: $deployment_state"
            exit 1
            ;;
    esac
    
    sleep 30
done

# Final health check
log_monitoring "Performing final health check..."
resources=$(az deployment sub show --name "$deployment_name" \
    --query "properties.outputResources[].id" -o tsv)

for resource in $resources; do
    health=$(check_resource_health "$resource")
    log_monitoring "Resource: $resource - Final State: $health"
    
    # Collect and store metrics
    metric_data=$(monitor_metrics "$resource")
    echo "$metric_data" >> "metrics_${deployment_name}.json"
done

# Generate monitoring summary
log_monitoring "Generating deployment summary..."
cat << EOF > "deployment_${deployment_name}_summary.md"
# Deployment Summary: ${deployment_name}

## Overview
- Environment: ${environment}
- Start Time: $(date -d @$(az deployment sub show --name "$deployment_name" --query "properties.timestamp" -o tsv) '+%Y-%m-%d %H:%M:%S')
- End Time: $(date '+%Y-%m-%d %H:%M:%S')

## Resource Status
$(for resource in $resources; do
    echo "- $(basename $resource): $(check_resource_health "$resource")"
done)

## Metrics Summary
- See detailed metrics in: metrics_${deployment_name}.json

## Logs
- Detailed logs available in: deployment_${deployment_name}_monitoring.log
EOF

log_monitoring "Monitoring completed. Summary available in deployment_${deployment_name}_summary.md"
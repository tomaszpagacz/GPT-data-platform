#!/bin/bash

# Script for managing RBAC and Managed Identities in Azure
# Usage: ./manage-identities.sh <command> [options]

set -e

# Configuration
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
DEFAULT_RESOURCE_GROUP="rg-dataplatform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
function print_usage() {
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  list-mi                     List all managed identities"
    echo "  list-roles                  List role assignments"
    echo "  create-group                Create a new security group"
    echo "  assign-role                 Assign a role to a principal"
    echo "  remove-role                 Remove a role assignment"
    echo "  sync-env                    Synchronize RBAC between environments"
    echo "  audit                       Generate RBAC audit report"
    echo
    echo "Options:"
    echo "  -g, --resource-group        Resource group name"
    echo "  -e, --environment           Environment (dev/sit/prod)"
    echo "  -n, --name                  Name for group/identity"
    echo "  -r, --role                  Role name"
    echo "  -p, --principal-id          Principal ID"
    echo "  -s, --source-env           Source environment for sync"
    echo "  -t, --target-env           Target environment for sync"
    echo "  -h, --help                 Show this help message"
}

function list_managed_identities() {
    local rg=${1:-$DEFAULT_RESOURCE_GROUP}
    echo -e "${GREEN}Listing Managed Identities in $rg...${NC}"
    az identity list --resource-group "$rg" --output table
}

function list_role_assignments() {
    local rg=${1:-$DEFAULT_RESOURCE_GROUP}
    echo -e "${GREEN}Listing Role Assignments in $rg...${NC}"
    az role assignment list --resource-group "$rg" --output table
}

function create_security_group() {
    local name=$1
    local description=$2
    echo -e "${GREEN}Creating Security Group: $name${NC}"
    az ad group create --display-name "$name" --mail-nickname "$name" \
        --description "$description"
}

function assign_role() {
    local rg=$1
    local role=$2
    local principal_id=$3
    echo -e "${GREEN}Assigning Role: $role to Principal: $principal_id${NC}"
    az role assignment create \
        --role "$role" \
        --assignee "$principal_id" \
        --resource-group "$rg"
}

function remove_role_assignment() {
    local rg=$1
    local role=$2
    local principal_id=$3
    echo -e "${YELLOW}Removing Role Assignment: $role from Principal: $principal_id${NC}"
    az role assignment delete \
        --role "$role" \
        --assignee "$principal_id" \
        --resource-group "$rg"
}

function sync_environments() {
    local source_env=$1
    local target_env=$2
    local source_rg="rg-dataplatform-$source_env"
    local target_rg="rg-dataplatform-$target_env"

    echo -e "${GREEN}Synchronizing RBAC from $source_env to $target_env...${NC}"
    
    # Get role assignments from source
    local source_assignments=$(az role assignment list -g "$source_rg" --query "[].{principalId:principalId, roleDefinitionName:roleDefinitionName}")
    
    # Apply to target
    echo "$source_assignments" | jq -c '.[]' | while read -r assignment; do
        local principal_id=$(echo "$assignment" | jq -r '.principalId')
        local role=$(echo "$assignment" | jq -r '.roleDefinitionName')
        
        # Skip certain roles based on environment
        if [[ "$target_env" == "prod" && "$role" == "Owner" ]]; then
            echo -e "${YELLOW}Skipping Owner role assignment in prod${NC}"
            continue
        fi
        
        assign_role "$target_rg" "$role" "$principal_id"
    done
}

function generate_audit_report() {
    local rg=$1
    local report_file="rbac-audit-report-$(date +%Y%m%d).csv"
    
    echo -e "${GREEN}Generating RBAC Audit Report...${NC}"
    echo "Principal ID,Principal Name,Role,Scope,Type" > "$report_file"
    
    az role assignment list -g "$rg" --include-groups --include-inherited \
        --query "[].{principalId:principalId, roleDefinitionName:roleDefinitionName, scope:scope, principalType:principalType}" \
        -o json | jq -r '.[] | [.principalId, .principalName, .roleDefinitionName, .scope, .principalType] | @csv' \
        >> "$report_file"
    
    echo -e "${GREEN}Report generated: $report_file${NC}"
}

# Main script
if [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]]; then
    print_usage
    exit 0
fi

command=$1
shift

# Parse options
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
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -r|--role)
            ROLE="$2"
            shift 2
            ;;
        -p|--principal-id)
            PRINCIPAL_ID="$2"
            shift 2
            ;;
        -s|--source-env)
            SOURCE_ENV="$2"
            shift 2
            ;;
        -t|--target-env)
            TARGET_ENV="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Execute command
case $command in
    list-mi)
        list_managed_identities "$RESOURCE_GROUP"
        ;;
    list-roles)
        list_role_assignments "$RESOURCE_GROUP"
        ;;
    create-group)
        create_security_group "$NAME" "$DESCRIPTION"
        ;;
    assign-role)
        assign_role "$RESOURCE_GROUP" "$ROLE" "$PRINCIPAL_ID"
        ;;
    remove-role)
        remove_role_assignment "$RESOURCE_GROUP" "$ROLE" "$PRINCIPAL_ID"
        ;;
    sync-env)
        sync_environments "$SOURCE_ENV" "$TARGET_ENV"
        ;;
    audit)
        generate_audit_report "$RESOURCE_GROUP"
        ;;
    *)
        echo -e "${RED}Unknown command: $command${NC}"
        print_usage
        exit 1
        ;;
esac
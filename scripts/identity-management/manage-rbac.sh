#!/bin/bash

# Script for easy RBAC management in Data Platform
# This script helps administrators and developers manage role assignments efficiently

set -e

# Default values
DEFAULT_RG="rg-dataplatform"
DEFAULT_ENV="dev"
CONFIG_FILE="rbac_config.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_usage() {
    echo "Data Platform RBAC Management Tool"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  init              Initialize RBAC configuration"
    echo "  assign            Assign a role to a user/group"
    echo "  revoke            Remove a role assignment"
    echo "  sync              Synchronize RBAC between environments"
    echo "  audit             Generate RBAC audit report"
    echo "  list              List current role assignments"
    echo "  deploy            Deploy RBAC using Bicep templates"
    echo
    echo "Options:"
    echo "  -e, --env        Environment (dev/sit/prod)"
    echo "  -g, --group      Security group name/ID"
    echo "  -r, --role       Role name"
    echo "  -s, --scope      Resource scope"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 init -e dev"
    echo "  $0 assign -g platform-admins -r contributor -s /subscriptions/xxx/resourceGroups/rg-dataplatform-dev"
    echo "  $0 audit -e prod"
}

validate_env() {
    local env=$1
    if [[ ! "$env" =~ ^(dev|sit|prod)$ ]]; then
        echo -e "${RED}Error: Invalid environment. Must be dev, sit, or prod${NC}"
        exit 1
    fi
}

check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo -e "${RED}Error: Azure CLI is not installed${NC}"
        exit 1
    fi
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}Please login to Azure:${NC}"
        az login
    fi
}

# Initialize RBAC configuration for an environment
init_rbac() {
    local env=${1:-$DEFAULT_ENV}
    local rg="$DEFAULT_RG-$env"
    
    echo -e "${GREEN}Initializing RBAC configuration for $env environment...${NC}"
    
    # Create basic security groups if they don't exist
    groups=(
        "platform-admins-$env"
        "platform-developers-$env"
        "platform-readers-$env"
        "data-contributors-$env"
    )
    
    for group in "${groups[@]}"; do
        if ! az ad group show --group "$group" &> /dev/null; then
            echo "Creating security group: $group"
            az ad group create --display-name "$group" --mail-nickname "$group"
        fi
    done
    
    # Deploy base RBAC template
    echo "Deploying RBAC configuration..."
    az deployment group create \
        --resource-group "$rg" \
        --template-file "infra/modules/identities/rbac.bicep" \
        --parameters @infra/params/rbac-assignments.parameters.json \
        --parameters environment="$env"
}

# Assign a role to a user/group
assign_role() {
    local group=$1
    local role=$2
    local scope=$3
    
    echo -e "${GREEN}Assigning role $role to $group at scope $scope...${NC}"
    
    az role assignment create \
        --assignee "$group" \
        --role "$role" \
        --scope "$scope"
}

# Remove a role assignment
revoke_role() {
    local group=$1
    local role=$2
    local scope=$3
    
    echo -e "${YELLOW}Removing role assignment: $role from $group at scope $scope...${NC}"
    
    az role assignment delete \
        --assignee "$group" \
        --role "$role" \
        --scope "$scope"
}

# Synchronize RBAC between environments
sync_environments() {
    local source_env=$1
    local target_env=$2
    local source_rg="$DEFAULT_RG-$source_env"
    local target_rg="$DEFAULT_RG-$target_env"
    
    echo -e "${GREEN}Synchronizing RBAC from $source_env to $target_env...${NC}"
    
    # Get role assignments from source
    local assignments=$(az role assignment list -g "$source_rg" --query "[].{principalId:principalId, roleDefinitionName:roleDefinitionName}")
    
    # Apply to target
    echo "$assignments" | jq -c '.[]' | while read -r assignment; do
        local principal_id=$(echo "$assignment" | jq -r '.principalId')
        local role=$(echo "$assignment" | jq -r '.roleDefinitionName')
        
        # Skip restricted roles in prod
        if [[ "$target_env" == "prod" && "$role" =~ ^(Owner|Contributor)$ ]]; then
            echo -e "${YELLOW}Skipping $role role assignment in prod${NC}"
            continue
        fi
        
        assign_role "$principal_id" "$role" "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$target_rg"
    done
}

# Generate RBAC audit report
generate_audit() {
    local env=${1:-$DEFAULT_ENV}
    local rg="$DEFAULT_RG-$env"
    local report_file="rbac-audit-$env-$(date +%Y%m%d).csv"
    
    echo -e "${GREEN}Generating RBAC audit report for $env environment...${NC}"
    
    echo "Principal,Role,Scope,Type" > "$report_file"
    
    az role assignment list -g "$rg" --include-groups --include-inherited \
        --query "[].{principal:principalName, role:roleDefinitionName, scope:scope, type:principalType}" \
        -o tsv >> "$report_file"
    
    echo -e "${GREEN}Audit report generated: $report_file${NC}"
}

# List current role assignments
list_assignments() {
    local env=${1:-$DEFAULT_ENV}
    local rg="$DEFAULT_RG-$env"
    
    echo -e "${GREEN}Current role assignments in $env environment:${NC}"
    
    az role assignment list -g "$rg" \
        --query "[].{principal:principalName, role:roleDefinitionName, scope:scope}" \
        -o table
}

# Deploy RBAC using Bicep templates
deploy_rbac() {
    local env=${1:-$DEFAULT_ENV}
    local rg="$DEFAULT_RG-$env"
    
    echo -e "${GREEN}Deploying RBAC configuration to $env environment...${NC}"
    
    az deployment group create \
        --resource-group "$rg" \
        --template-file "infra/modules/identities/rbac.bicep" \
        --parameters @infra/params/rbac-assignments.parameters.json \
        --parameters environment="$env"
}

# Main script
check_azure_cli

if [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]]; then
    print_usage
    exit 0
fi

command=$1
shift

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -g|--group)
            GROUP="$2"
            shift 2
            ;;
        -r|--role)
            ROLE="$2"
            shift 2
            ;;
        -s|--scope)
            SCOPE="$2"
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
    init)
        validate_env "${ENV:-$DEFAULT_ENV}"
        init_rbac "${ENV:-$DEFAULT_ENV}"
        ;;
    assign)
        [[ -z "$GROUP" || -z "$ROLE" || -z "$SCOPE" ]] && { echo -e "${RED}Error: Missing required parameters${NC}"; exit 1; }
        assign_role "$GROUP" "$ROLE" "$SCOPE"
        ;;
    revoke)
        [[ -z "$GROUP" || -z "$ROLE" || -z "$SCOPE" ]] && { echo -e "${RED}Error: Missing required parameters${NC}"; exit 1; }
        revoke_role "$GROUP" "$ROLE" "$SCOPE"
        ;;
    sync)
        [[ -z "$ENV" ]] && { echo -e "${RED}Error: Source environment not specified${NC}"; exit 1; }
        read -p "Target environment: " TARGET_ENV
        validate_env "$ENV"
        validate_env "$TARGET_ENV"
        sync_environments "$ENV" "$TARGET_ENV"
        ;;
    audit)
        validate_env "${ENV:-$DEFAULT_ENV}"
        generate_audit "${ENV:-$DEFAULT_ENV}"
        ;;
    list)
        validate_env "${ENV:-$DEFAULT_ENV}"
        list_assignments "${ENV:-$DEFAULT_ENV}"
        ;;
    deploy)
        validate_env "${ENV:-$DEFAULT_ENV}"
        deploy_rbac "${ENV:-$DEFAULT_ENV}"
        ;;
    *)
        echo -e "${RED}Unknown command: $command${NC}"
        print_usage
        exit 1
        ;;
esac
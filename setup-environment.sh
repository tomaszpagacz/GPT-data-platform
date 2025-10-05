#!/bin/bash

# =============================================================================
# Azure Data Platform - Parameter File Generator
# =============================================================================
# This script helps generate environment-specific parameter files
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARAMS_DIR="$SCRIPT_DIR/infra/params"

print_header() {
    echo -e "\n${BLUE}$1${NC}\n"
}

print_step() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Get security group GUIDs
get_security_groups() {
    print_header "Azure AD Security Groups Setup"
    
    echo -e "${YELLOW}Please provide Object IDs for your Azure AD Security Groups:${NC}"
    echo -e "${BLUE}Tip: Use 'az ad group list --query \"[].{Name:displayName, ObjectId:id}\" --output table' to list groups${NC}\n"
    
    declare -A GROUPS
    GROUP_NAMES=("platformAdmins" "platformOperators" "platformDevelopers" "platformReaders" "mlEngineers" "dataAnalysts" "dataScientists" "dataEngineers" "dataGovernanceTeam")
    
    for group in "${GROUP_NAMES[@]}"; do
        read -p "$(echo -e ${YELLOW}"$group Object ID: "${NC})" group_id
        GROUPS[$group]=$group_id
    done
    
    echo "${GROUPS[@]}"
}

# Generate parameter file
generate_param_file() {
    local environment=$1
    local name_prefix=$2
    local output_file="$PARAMS_DIR/${environment}.main.parameters.json"
    
    # Read security groups into associative array
    declare -A SECURITY_GROUPS
    IFS=' ' read -r -a group_values <<< "$(get_security_groups)"
    GROUP_NAMES=("platformAdmins" "platformOperators" "platformDevelopers" "platformReaders" "mlEngineers" "dataAnalysts" "dataScientists" "dataEngineers" "dataGovernanceTeam")
    
    for i in "${!GROUP_NAMES[@]}"; do
        SECURITY_GROUPS[${GROUP_NAMES[$i]}]=${group_values[$i]}
    done
    
    # Generate password
    local synapse_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    
    # Create parameter file
    cat > "$output_file" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "namePrefix": {
      "value": "$name_prefix"
    },
    "environment": {
      "value": "$environment"
    },
    "synapseSqlAdminLogin": {
      "value": "sqladmin"
    },
    "synapseSqlAdminPassword": {
      "value": "$synapse_password"
    },
    "securityGroups": {
      "value": {
        "platformAdmins": "${SECURITY_GROUPS[platformAdmins]}",
        "platformOperators": "${SECURITY_GROUPS[platformOperators]}", 
        "platformDevelopers": "${SECURITY_GROUPS[platformDevelopers]}",
        "platformReaders": "${SECURITY_GROUPS[platformReaders]}",
        "mlEngineers": "${SECURITY_GROUPS[mlEngineers]}",
        "dataAnalysts": "${SECURITY_GROUPS[dataAnalysts]}",
        "dataScientists": "${SECURITY_GROUPS[dataScientists]}",
        "dataEngineers": "${SECURITY_GROUPS[dataEngineers]}",
        "dataGovernanceTeam": "${SECURITY_GROUPS[dataGovernanceTeam]}"
      }
    }
  }
}
EOF
    
    print_success "Parameter file created: $output_file"
    echo -e "${YELLOW}Generated Synapse Password: $synapse_password${NC}"
    echo -e "${YELLOW}Please save this password securely!${NC}"
}

# Main function
main() {
    print_header "Azure Data Platform - Parameter File Generator"
    
    # Get environment
    echo -e "${YELLOW}Select environment:${NC}"
    echo "1) dev"
    echo "2) sit"  
    echo "3) prod"
    read -p "Enter choice (1-3): " env_choice
    
    case $env_choice in
        1) ENVIRONMENT="dev" ;;
        2) ENVIRONMENT="sit" ;;
        3) ENVIRONMENT="prod" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
    
    # Get name prefix
    read -p "$(echo -e ${YELLOW}"Enter name prefix (default: gptdata): "${NC})" NAME_PREFIX
    NAME_PREFIX=${NAME_PREFIX:-gptdata}
    
    # Check if parameter file already exists
    PARAM_FILE="$PARAMS_DIR/${ENVIRONMENT}.main.parameters.json"
    if [[ -f "$PARAM_FILE" ]]; then
        read -p "$(echo -e ${YELLOW}"Parameter file exists. Overwrite? (y/n): "${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 1
        fi
    fi
    
    # Generate parameter file
    generate_param_file "$ENVIRONMENT" "$NAME_PREFIX"
    
    print_success "Setup completed for environment: $ENVIRONMENT"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Review the generated parameter file: $PARAM_FILE"
    echo "2. Update any additional parameters as needed"
    echo "3. Run deployment: ./deploy-platform.sh"
}

# Execute main function
main "$@"
#!/bin/bash

# =============================================================================
# Azure Data Platform - Quick Deployment Script
# =============================================================================
# This script provides a guided deployment of the Azure Data Platform
# Prerequisites: Azure CLI logged in, appropriate permissions
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_step() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

confirm_action() {
    read -p "$(echo -e ${YELLOW}"$1 (y/n): "${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi
}

# =============================================================================
# Main Deployment Functions
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install it first."
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check Bicep CLI
    if ! command -v bicep &> /dev/null; then
        print_error "Bicep CLI not found. Installing..."
        az bicep install
    fi
    
    print_success "Prerequisites check completed"
    
    # Run detailed prerequisite check
    if [[ -f "$INFRA_DIR/pipeline/check-prerequisites.sh" ]]; then
        print_step "Running detailed prerequisite validation..."
        bash "$INFRA_DIR/pipeline/check-prerequisites.sh"
    fi
}

validate_templates() {
    print_header "Validating Bicep Templates"
    
    if [[ -f "$INFRA_DIR/pipeline/validate-all-bicep.sh" ]]; then
        bash "$INFRA_DIR/pipeline/validate-all-bicep.sh"
        if [[ $? -eq 0 ]]; then
            print_success "All Bicep templates validated successfully"
        else
            print_error "Bicep template validation failed"
            exit 1
        fi
    else
        print_error "Validation script not found"
        exit 1
    fi
}

get_deployment_parameters() {
    print_header "Deployment Configuration"
    
    # Get environment
    echo -e "${YELLOW}Select deployment environment:${NC}"
    echo "1) dev (Development)"
    echo "2) sit (System Integration Testing)"  
    echo "3) prod (Production)"
    read -p "Enter choice (1-3): " env_choice
    
    case $env_choice in
        1) ENVIRONMENT="dev" ;;
        2) ENVIRONMENT="sit" ;;
        3) ENVIRONMENT="prod" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
    
    # Get name prefix
    read -p "$(echo -e ${YELLOW}"Enter name prefix (default: gptdata): "${NC})" NAME_PREFIX
    NAME_PREFIX=${NAME_PREFIX:-gptdata}
    
    # Get location
    read -p "$(echo -e ${YELLOW}"Enter Azure region (default: switzerlandnorth): "${NC})" LOCATION
    LOCATION=${LOCATION:-switzerlandnorth}
    
    # Parameter file path
    PARAM_FILE="$INFRA_DIR/params/${ENVIRONMENT}.main.parameters.json"
    
    if [[ ! -f "$PARAM_FILE" ]]; then
        print_error "Parameter file not found: $PARAM_FILE"
        print_step "Creating parameter file from template..."
        
        if [[ -f "$INFRA_DIR/params/dev.main.parameters.json" ]]; then
            cp "$INFRA_DIR/params/dev.main.parameters.json" "$PARAM_FILE"
            # Update environment in the new file
            sed -i "s/\"dev\"/\"$ENVIRONMENT\"/g" "$PARAM_FILE"
            print_success "Parameter file created: $PARAM_FILE"
        else
            print_error "No template parameter file found"
            exit 1
        fi
    fi
    
    print_success "Configuration completed"
    echo -e "  Environment: ${GREEN}$ENVIRONMENT${NC}"
    echo -e "  Name Prefix: ${GREEN}$NAME_PREFIX${NC}"
    echo -e "  Location: ${GREEN}$LOCATION${NC}"
    echo -e "  Parameter File: ${GREEN}$PARAM_FILE${NC}"
}

check_security_groups() {
    print_header "Security Groups Validation"
    
    print_step "Checking if security groups are configured in parameter file..."
    
    # Extract security group IDs from parameter file
    PLATFORM_ADMINS=$(jq -r '.parameters.securityGroups.value.platformAdmins' "$PARAM_FILE")
    
    if [[ "$PLATFORM_ADMINS" == "00000000-0000-0000-0000-000000000000" ]] || [[ "$PLATFORM_ADMINS" == "null" ]]; then
        print_error "Security groups not configured!"
        echo -e "${YELLOW}Please update the security group Object IDs in: $PARAM_FILE${NC}"
        echo -e "${YELLOW}Use this command to find your Azure AD groups:${NC}"
        echo -e "${BLUE}az ad group list --query \"[].{Name:displayName, ObjectId:id}\" --output table${NC}"
        echo ""
        confirm_action "Have you updated the security groups in the parameter file?"
    else
        print_success "Security groups appear to be configured"
    fi
}

deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    DEPLOYMENT_NAME="${NAME_PREFIX}-${ENVIRONMENT}-${TIMESTAMP}"
    
    print_step "Starting deployment: $DEPLOYMENT_NAME"
    print_step "This may take 30-45 minutes..."
    
    # Confirmation for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        confirm_action "You are deploying to PRODUCTION. Are you sure?"
    fi
    
    # What-if analysis
    print_step "Running what-if analysis..."
    az deployment sub what-if \
        --name "$DEPLOYMENT_NAME" \
        --location "$LOCATION" \
        --template-file "$INFRA_DIR/main.bicep" \
        --parameters @"$PARAM_FILE"
    
    confirm_action "Proceed with deployment?"
    
    # Actual deployment
    print_step "Deploying infrastructure..."
    az deployment sub create \
        --name "$DEPLOYMENT_NAME" \
        --location "$LOCATION" \
        --template-file "$INFRA_DIR/main.bicep" \
        --parameters @"$PARAM_FILE" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "Infrastructure deployment completed successfully!"
        echo -e "  Deployment Name: ${GREEN}$DEPLOYMENT_NAME${NC}"
    else
        print_error "Infrastructure deployment failed"
        exit 1
    fi
}

deploy_additional_components() {
    print_header "Deploying Additional Components"
    
    RESOURCE_GROUP="rg-${NAME_PREFIX}-${ENVIRONMENT}"
    
    # Check if additional parameter files exist and deploy them
    local components=("eventing" "keyvaultsecrets" "apimanagement")
    
    for component in "${components[@]}"; do
        local param_file="$INFRA_DIR/params/${ENVIRONMENT}.${component}.parameters.json"
        local template_file="$INFRA_DIR/modules/${component}.bicep"
        
        if [[ -f "$param_file" ]] && [[ -f "$template_file" ]]; then
            print_step "Deploying $component component..."
            
            az deployment group create \
                --resource-group "$RESOURCE_GROUP" \
                --name "${component}-${TIMESTAMP}" \
                --template-file "$template_file" \
                --parameters @"$param_file"
            
            if [[ $? -eq 0 ]]; then
                print_success "$component component deployed successfully"
            else
                print_error "$component component deployment failed"
            fi
        else
            print_step "Skipping $component (template or parameters not found)"
        fi
    done
}

post_deployment_validation() {
    print_header "Post-Deployment Validation"
    
    RESOURCE_GROUP="rg-${NAME_PREFIX}-${ENVIRONMENT}"
    
    # Check if resource group exists
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_success "Resource group created: $RESOURCE_GROUP"
    else
        print_error "Resource group not found: $RESOURCE_GROUP"
        return 1
    fi
    
    # List deployed resources
    print_step "Listing deployed resources..."
    az resource list --resource-group "$RESOURCE_GROUP" --output table
    
    # Check deployment status
    print_step "Checking deployment status..."
    az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.provisioningState" --output tsv
    
    # Run health check if available
    if [[ -f "$INFRA_DIR/pipeline/check-platform-health.sh" ]]; then
        print_step "Running platform health check..."
        bash "$INFRA_DIR/pipeline/check-platform-health.sh"
    fi
    
    print_success "Post-deployment validation completed"
}

display_next_steps() {
    print_header "Deployment Complete - Next Steps"
    
    echo -e "${GREEN}🎉 Azure Data Platform deployed successfully!${NC}\n"
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Verify user access to security groups"
    echo "2. Configure data sources and ingestion pipelines"
    echo "3. Set up monitoring dashboards"
    echo "4. Configure backup and disaster recovery"
    echo "5. Conduct user training"
    echo ""
    
    echo -e "${YELLOW}Important URLs:${NC}"
    
    # Get Synapse workspace URL
    if SYNAPSE_URL=$(az synapse workspace show --name "${NAME_PREFIX}-${ENVIRONMENT}-synapse" --resource-group "rg-${NAME_PREFIX}-${ENVIRONMENT}" --query "connectivityEndpoints.web" -o tsv 2>/dev/null); then
        echo -e "  Synapse Studio: ${BLUE}$SYNAPSE_URL${NC}"
    fi
    
    # Get Azure ML workspace URL
    if ML_URL=$(az ml workspace show --name "${NAME_PREFIX}-${ENVIRONMENT}-ml" --resource-group "rg-${NAME_PREFIX}-${ENVIRONMENT}" --query "workspaceUrl" -o tsv 2>/dev/null); then
        echo -e "  Azure ML Studio: ${BLUE}$ML_URL${NC}"
    fi
    
    echo -e "\n${YELLOW}Documentation:${NC}"
    echo -e "  Deployment Strategy: ${BLUE}./DEPLOYMENT-STRATEGY.md${NC}"
    echo -e "  Architecture Docs: ${BLUE}./docs/${NC}"
    
    echo -e "\n${GREEN}Deployment completed successfully! 🚀${NC}"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "Azure Data Platform - Quick Deployment"
    echo -e "${BLUE}This script will guide you through deploying the Azure Data Platform${NC}\n"
    
    # Execution steps
    check_prerequisites
    validate_templates
    get_deployment_parameters
    check_security_groups
    deploy_infrastructure
    deploy_additional_components
    post_deployment_validation
    display_next_steps
}

# Handle script arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Azure Data Platform Deployment Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --validate     Only validate templates"
        echo "  --prereq       Only check prerequisites"
        echo ""
        echo "Interactive deployment: $0"
        exit 0
        ;;
    "--validate")
        validate_templates
        exit 0
        ;;
    "--prereq")
        check_prerequisites
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
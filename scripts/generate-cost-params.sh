#!/bin/bash

# Azure Data Platform - Cost-Optimized Parameter Generator
# This script reads the cost optimization configuration and generates appropriate deployment parameters

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../infra/pipeline/cost-optimization-config.yml"
OUTPUT_DIR="$SCRIPT_DIR/../infra/params"

# Default values
ENVIRONMENT=""
OUTPUT_FORMAT="bicep"  # bicep or arm
INCLUDE_COMMENTS=true

# Usage function
usage() {
    cat << EOF
Azure Data Platform - Cost-Optimized Parameter Generator

Usage: $0 [OPTIONS] <environment>

OPTIONS:
    -f, --format <format>   Output format: bicep (default) or arm
    -o, --output <dir>      Output directory (default: ../infra/params)
    --no-comments          Don't include explanatory comments
    -h, --help             Show this help message

EXAMPLES:
    # Generate parameters for development environment
    $0 dev

    # Generate ARM template parameters
    $0 --format arm sit

    # Generate to custom directory
    $0 --output ./custom-params uat

SUPPORTED ENVIRONMENTS: dev, sit, uat, prod
EOF
}

# Parse YAML configuration (simplified parser)
parse_yaml_value() {
    local file="$1"
    local key_path="$2"
    local default_value="${3:-}"
    
    # Convert key path to grep pattern (e.g., "deploymentFlags.deployFabric.dev" -> "deployFabric:" then "dev:")
    local section=$(echo "$key_path" | cut -d. -f1-2)
    local env_key=$(echo "$key_path" | cut -d. -f3)
    local service=$(echo "$key_path" | cut -d. -f2)
    
    # Extract the value using a simple approach
    local value
    if [[ -f "$file" ]]; then
        # Find the service section and then the environment value
        value=$(awk "
        /$service:/ {found=1; next}
        found && /$env_key:/ {
            gsub(/^[[:space:]]*$env_key:[[:space:]]*/, \"\");
            gsub(/[[:space:]]*#.*\$/, \"\");
            print;
            exit
        }
        found && /^[[:space:]]*[a-zA-Z]/ && !/$env_key:/ {found=0}
        " "$file" | head -1)
    fi
    
    # Return value or default
    echo "${value:-$default_value}"
}

# Get deployment flag value
get_deployment_flag() {
    local service="$1"
    local environment="$2"
    local default_value="${3:-true}"
    
    local key_path="deploymentFlags.${service}.${environment}"
    local value=$(parse_yaml_value "$CONFIG_FILE" "$key_path" "$default_value")
    
    echo "$value"
}

# Generate cost optimization explanation
generate_cost_explanation() {
    local service="$1"
    local enabled="$2"
    local monthly_cost="$3"
    
    if [[ "$enabled" == "true" ]]; then
        echo "// ✅ ENABLED: $service - Est. cost: $monthly_cost"
    else
        echo "// 💰 DISABLED: $service - Saves: $monthly_cost"
    fi
}

# Generate Bicep parameters file
generate_bicep_params() {
    local environment="$1"
    local output_file="$OUTPUT_DIR/cost-optimized-${environment}.bicepparam"
    
    echo -e "${BLUE}Generating Bicep parameters for $environment environment...${NC}"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Start building the file
    cat > "$output_file" << EOF
using '../main.bicep'

// ========================================
// COST-OPTIMIZED DEPLOYMENT PARAMETERS
// ========================================
// Generated automatically for: $environment environment
// Generated on: $(date)
//
// This parameter file is optimized for cost management in $environment environments.
// Expensive 24/7 charging resources are selectively disabled to reduce costs.

EOF

    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        cat >> "$output_file" << EOF
// ========================================
// COST OPTIMIZATION SWITCHES
// ========================================
// These parameters control which expensive resources get deployed.
// Setting to false prevents deployment and saves costs.

EOF
    fi

    # Get deployment flags for each service
    local deploy_fabric=$(get_deployment_flag "deployFabric" "$environment" "true")
    local deploy_aks=$(get_deployment_flag "deployAKS" "$environment" "true")
    local deploy_ml=$(get_deployment_flag "deployMachineLearning" "$environment" "true")
    local deploy_purview=$(get_deployment_flag "deployPurview" "$environment" "true")
    local deploy_sql=$(get_deployment_flag "deploySynapseDedicatedSQL" "$environment" "false")
    local deploy_shir=$(get_deployment_flag "deploySHIR" "$environment" "false")
    local deploy_aci=$(get_deployment_flag "deployContainerInstances" "$environment" "true")
    local deploy_logic=$(get_deployment_flag "deployLogicApps" "$environment" "true")
    local deploy_cognitive=$(get_deployment_flag "deployCognitiveServices" "$environment" "true")
    local deploy_maps=$(get_deployment_flag "deployAzureMaps" "$environment" "true")

    # Add cost optimization parameters
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Microsoft Fabric" "$deploy_fabric" "\$525/month (F2 minimum)" >> "$output_file"
    fi
    echo "param deployFabric = $deploy_fabric" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Azure Kubernetes Service" "$deploy_aks" "\$420/month (3 nodes)" >> "$output_file"
    fi
    echo "param deployAKS = $deploy_aks" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Azure Machine Learning" "$deploy_ml" "\$200+/month (compute instances)" >> "$output_file"
    fi
    echo "param deployMachineLearning = $deploy_ml" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Microsoft Purview" "$deploy_purview" "\$400/month (4 capacity units)" >> "$output_file"
    fi
    echo "param deployPurview = $deploy_purview" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Synapse Dedicated SQL" "$deploy_sql" "\$1,200/month (DW100c)" >> "$output_file"
    fi
    echo "param deploySynapseDedicatedSQL = $deploy_sql" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Self-Hosted IR VM" "$deploy_shir" "\$140/month (Standard_D2s_v3)" >> "$output_file"
    fi
    echo "param deploySHIR = $deploy_shir" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Container Instances" "$deploy_aci" "Variable (pay-per-use)" >> "$output_file"
    fi
    echo "param deployContainerInstances = $deploy_aci" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Logic Apps Standard" "$deploy_logic" "\$200/month (base plan)" >> "$output_file"
    fi
    echo "param deployLogicApps = $deploy_logic" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Cognitive Services" "$deploy_cognitive" "Variable by tier" >> "$output_file"
    fi
    echo "param deployCognitiveServices = $deploy_cognitive" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        generate_cost_explanation "Azure Maps" "$deploy_maps" "Variable by tier" >> "$output_file"
    fi
    echo "param deployAzureMaps = $deploy_maps" >> "$output_file"
    echo "" >> "$output_file"

    # Calculate estimated monthly savings
    local savings=0
    [[ "$deploy_fabric" == "false" ]] && savings=$((savings + 525))
    [[ "$deploy_aks" == "false" ]] && savings=$((savings + 420))
    [[ "$deploy_ml" == "false" ]] && savings=$((savings + 200))
    [[ "$deploy_purview" == "false" ]] && savings=$((savings + 400))
    [[ "$deploy_sql" == "false" ]] && savings=$((savings + 1200))
    [[ "$deploy_shir" == "false" ]] && savings=$((savings + 140))

    if [[ "$INCLUDE_COMMENTS" == "true" ]]; then
        cat >> "$output_file" << EOF

// ========================================
// COST SAVINGS SUMMARY
// ========================================
// Estimated monthly savings for $environment: ~\$$savings USD
// (Based on disabled expensive resources)
//
// To use these parameters:
// az deployment group create \\
//   --resource-group <rg-name> \\
//   --template-file ../main.bicep \\
//   --parameters @$output_file \\
//   --parameters namePrefix=<prefix> environment=$environment

EOF
    fi
    
    echo -e "${GREEN}✅ Bicep parameters generated: $output_file${NC}"
    echo -e "${YELLOW}💰 Estimated monthly savings: \$$savings USD${NC}"
}

# Generate ARM template parameters file
generate_arm_params() {
    local environment="$1"
    local output_file="$OUTPUT_DIR/cost-optimized-${environment}.parameters.json"
    
    echo -e "${BLUE}Generating ARM parameters for $environment environment...${NC}"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Get deployment flags for each service
    local deploy_fabric=$(get_deployment_flag "deployFabric" "$environment" "true")
    local deploy_aks=$(get_deployment_flag "deployAKS" "$environment" "true")
    local deploy_ml=$(get_deployment_flag "deployMachineLearning" "$environment" "true")
    local deploy_purview=$(get_deployment_flag "deployPurview" "$environment" "true")
    local deploy_sql=$(get_deployment_flag "deploySynapseDedicatedSQL" "$environment" "false")
    local deploy_shir=$(get_deployment_flag "deploySHIR" "$environment" "false")
    local deploy_aci=$(get_deployment_flag "deployContainerInstances" "$environment" "true")
    local deploy_logic=$(get_deployment_flag "deployLogicApps" "$environment" "true")
    local deploy_cognitive=$(get_deployment_flag "deployCognitiveServices" "$environment" "true")
    local deploy_maps=$(get_deployment_flag "deployAzureMaps" "$environment" "true")

    # Build JSON file
    cat > "$output_file" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "deployFabric": {
      "value": $deploy_fabric
    },
    "deployAKS": {
      "value": $deploy_aks
    },
    "deployMachineLearning": {
      "value": $deploy_ml
    },
    "deployPurview": {
      "value": $deploy_purview
    },
    "deploySynapseDedicatedSQL": {
      "value": $deploy_sql
    },
    "deploySHIR": {
      "value": $deploy_shir
    },
    "deployContainerInstances": {
      "value": $deploy_aci
    },
    "deployLogicApps": {
      "value": $deploy_logic
    },
    "deployCognitiveServices": {
      "value": $deploy_cognitive
    },
    "deployAzureMaps": {
      "value": $deploy_maps
    }
  }
}
EOF

    echo -e "${GREEN}✅ ARM parameters generated: $output_file${NC}"
}

# Show cost optimization summary
show_cost_summary() {
    local environment="$1"
    
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}COST OPTIMIZATION SUMMARY - $environment${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    echo -e "\n${YELLOW}Deployment Flags:${NC}"
    echo "  Microsoft Fabric: $(get_deployment_flag "deployFabric" "$environment")"
    echo "  Azure Kubernetes Service: $(get_deployment_flag "deployAKS" "$environment")"
    echo "  Azure Machine Learning: $(get_deployment_flag "deployMachineLearning" "$environment")"
    echo "  Microsoft Purview: $(get_deployment_flag "deployPurview" "$environment")"
    echo "  Synapse Dedicated SQL: $(get_deployment_flag "deploySynapseDedicatedSQL" "$environment")"
    echo "  Self-Hosted Integration Runtime: $(get_deployment_flag "deploySHIR" "$environment")"
    echo "  Container Instances: $(get_deployment_flag "deployContainerInstances" "$environment")"
    echo "  Logic Apps Standard: $(get_deployment_flag "deployLogicApps" "$environment")"
    echo "  Cognitive Services: $(get_deployment_flag "deployCognitiveServices" "$environment")"
    echo "  Azure Maps: $(get_deployment_flag "deployAzureMaps" "$environment")"
    
    echo -e "\n${YELLOW}Configuration Source:${NC} $CONFIG_FILE"
    echo -e "${YELLOW}Output Directory:${NC} $OUTPUT_DIR"
}

# Main execution
main() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}Warning: Configuration file not found: $CONFIG_FILE${NC}"
        echo "Using default values for all deployment flags."
    fi
    
    # Show cost summary
    show_cost_summary "$ENVIRONMENT"
    
    # Generate parameters based on format
    case "$OUTPUT_FORMAT" in
        "bicep")
            generate_bicep_params "$ENVIRONMENT"
            ;;
        "arm")
            generate_arm_params "$ENVIRONMENT"
            ;;
        *)
            echo "Error: Unsupported output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}Cost-optimized parameters generated successfully!${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Review the generated parameter file"
    echo "  2. Customize additional parameters as needed"
    echo "  3. Deploy using the parameter file"
    echo "  4. Run runtime optimizations: ./infra/pipeline/optimize-costs.sh"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-comments)
            INCLUDE_COMMENTS=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
            else
                echo "Error: Unknown argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ENVIRONMENT" ]]; then
    echo "Error: Environment is required"
    usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|sit|uat|prod)$ ]]; then
    echo "Error: Invalid environment. Must be one of: dev, sit, uat, prod"
    exit 1
fi

# Validate output format
if [[ ! "$OUTPUT_FORMAT" =~ ^(bicep|arm)$ ]]; then
    echo "Error: Invalid output format. Must be: bicep or arm"
    exit 1
fi

# Run main function
main "$@"
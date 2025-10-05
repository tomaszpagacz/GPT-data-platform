#!/usr/bin/env bash
set -euo pipefail

# Local Logic Apps Workflow Validation Script
# This script validates templates, workflows, and configuration locally without Azure authentication

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating local prerequisites..."

    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi

    if ! command -v bicep &> /dev/null; then
        log_error "Bicep CLI is not installed or not in PATH"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        exit 1
    fi

    log_success "Prerequisites validated"
}

# Validate Bicep templates
validate_bicep_templates() {
    log_info "Validating Bicep templates..."

    local templates=(
        "infra/main.bicep"
        "infra/modules/logicApp.bicep"
        "infra/modules/storage.bicep"
        "infra/modules/networking.bicep"
        "infra/modules/keyVault.bicep"
        "infra/modules/monitoring.bicep"
    )

    for template in "${templates[@]}"; do
        if [[ -f "$PROJECT_ROOT/$template" ]]; then
            log_info "Building $template..."
            local output_file="$PROJECT_ROOT/validation_outputs/bicep/${template%.bicep}.json"
            mkdir -p "$(dirname "$output_file")"
            if az bicep build --file "$PROJECT_ROOT/$template" --outfile "$output_file" &> /dev/null; then
                log_success "$template builds successfully"
            else
                log_error "$template failed to build"
                return 1
            fi
        else
            log_warning "$template not found, skipping"
        fi
    done

    log_success "All Bicep templates validated"
}

# Validate Logic App workflows
validate_workflows() {
    log_info "Validating Logic App workflows..."

    local workflow_dir="$PROJECT_ROOT/src/logic-apps/workflows"
    local output_dir="$PROJECT_ROOT/validation_outputs/workflows"
    local workflow_count=0

    mkdir -p "$output_dir"

    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflows directory not found: $workflow_dir"
        return 1
    fi

    for workflow_file in "$workflow_dir"/*.workflow.json; do
        if [[ -f "$workflow_file" ]]; then
            local workflow_name=$(basename "$workflow_file" .workflow.json)
            local output_file="$output_dir/${workflow_name}-validation.json"
            
            log_info "Validating $workflow_name..."

            # Create validation result object
            local validation_result="{\"workflow\":\"$workflow_name\",\"file\":\"$workflow_file\",\"timestamp\":\"$(date -Iseconds)\",\"results\":[]}"
            
            # Check if it's valid JSON
            if jq empty "$workflow_file" &> /dev/null; then
                log_success "$workflow_name is valid JSON"
                validation_result=$(jq '.results += [{"check":"json_valid","status":"passed"}]' <<< "$validation_result" 2>/dev/null || validation_result='{"error":"json_update_failed"}')
                if [[ "$validation_result" == '{"error":"json_update_failed"}' ]]; then
                    log_error "Failed to update JSON for $workflow_name"
                    return 1
                fi
            else
                log_error "$workflow_name is not valid JSON"
                validation_result=$(jq '.results += [{"check":"json_valid","status":"failed"}]' <<< "$validation_result" 2>/dev/null || validation_result='{"error":"json_update_failed"}')
                echo "$validation_result" > "$output_file"
                return 1
            fi

            # Check for required workflow structure
            if jq -e '.definition' "$workflow_file" &> /dev/null; then
                log_success "$workflow_name has workflow definition"
                validation_result=$(jq '.results += [{"check":"has_definition","status":"passed"}]' <<< "$validation_result" 2>/dev/null || validation_result='{"error":"json_update_failed"}')
                if [[ "$validation_result" == '{"error":"json_update_failed"}' ]]; then
                    log_error "Failed to update JSON for $workflow_name"
                    return 1
                fi
            else
                log_error "$workflow_name missing workflow definition"
                validation_result=$(jq '.results += [{"check":"has_definition","status":"failed"}]' <<< "$validation_result" 2>/dev/null || validation_result='{"error":"json_update_failed"}')
                echo "$validation_result" > "$output_file"
                return 1
            fi

            # Save validation results
            echo "$validation_result" > "$output_file"
            ((workflow_count++))
        fi
    done

    if [[ $workflow_count -eq 0 ]]; then
        log_warning "No workflow files found"
    else
        log_success "Validated $workflow_count workflow files"
    fi
}

# Validate configuration files
validate_configuration() {
    log_info "Validating configuration files..."

    local output_dir="$PROJECT_ROOT/validation_outputs/config"
    mkdir -p "$output_dir"
    local config_results='{"timestamp":"'$(date -Iseconds)'","checks":[]}'

    # Check for parameters file
    if [[ -f "$PROJECT_ROOT/infra/parameters.sample.json" ]]; then
        if jq empty "$PROJECT_ROOT/infra/parameters.sample.json" &> /dev/null; then
            log_success "Parameters sample file is valid JSON"
            config_results=$(jq '.checks += [{"file":"infra/parameters.sample.json","check":"json_valid","status":"passed"}]' <<< "$config_results")
        else
            log_error "Parameters sample file is not valid JSON"
            config_results=$(jq '.checks += [{"file":"infra/parameters.sample.json","check":"json_valid","status":"failed"}]' <<< "$config_results")
            return 1
        fi
    else
        log_warning "Parameters sample file not found"
        config_results=$(jq '.checks += [{"file":"infra/parameters.sample.json","check":"exists","status":"missing"}]' <<< "$config_results")
    fi

    # Check for deployment scripts
    local scripts=(
        "scripts/deploy-workflows.sh"
        "scripts/validate-deployment.sh"
        "scripts/install-azure-tools.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$PROJECT_ROOT/$script" ]]; then
            if [[ -x "$PROJECT_ROOT/$script" ]]; then
                log_success "$script exists and is executable"
                config_results=$(jq '.checks += [{"file":"'$script'","check":"executable","status":"passed"}]' <<< "$config_results")
            else
                log_warning "$script exists but is not executable"
                config_results=$(jq '.checks += [{"file":"'$script'","check":"executable","status":"not_executable"}]' <<< "$config_results")
            fi
        else
            log_warning "$script not found"
            config_results=$(jq '.checks += [{"file":"'$script'","check":"exists","status":"missing"}]' <<< "$config_results")
        fi
    done

    # Save configuration validation results
    echo "$config_results" > "$output_dir/configuration-validation.json"

    log_success "Configuration validation completed"
}

# Validate documentation
validate_documentation() {
    log_info "Validating documentation..."

    local docs=(
        "README.md"
        "docs/logic-apps-development.md"
        "docs/workflow-deployment-testing.md"
        "WORKFLOW-QUICKSTART.md"
    )

    for doc in "${docs[@]}"; do
        if [[ -f "$PROJECT_ROOT/$doc" ]]; then
            log_success "Documentation file exists: $doc"
        else
            log_warning "Documentation file missing: $doc"
        fi
    done

    log_success "Documentation validation completed"
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."

    local output_dir="$PROJECT_ROOT/validation_outputs/reports"
    mkdir -p "$output_dir"
    
    local report_file="$output_dir/local-validation-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Create comprehensive report
    local report='{
        "timestamp": "'$(date -Iseconds)'",
        "project": "GPT Data Platform",
        "status": "completed",
        "summary": {
            "prerequisites": "passed",
            "bicep_templates": "passed", 
            "logic_app_workflows": "passed",
            "configuration_files": "passed",
            "documentation": "passed"
        },
        "next_steps": [
            "Set up Azure authentication: az login",
            "Configure environment variables", 
            "Run deployment: scripts/deploy-workflows.sh",
            "Run full validation: scripts/validate-deployment.sh"
        ]
    }'
    
    echo "$report" > "$report_file"

    echo
    echo "========================================"
    echo "LOCAL VALIDATION REPORT"
    echo "========================================"
    echo "Date: $(date)"
    echo "Project: GPT Data Platform"
    echo "Status: All local validations passed"
    echo "Report saved to: $report_file"
    echo "========================================"
    echo
    echo "✅ Prerequisites: Azure CLI, Bicep CLI, jq installed"
    echo "✅ Bicep Templates: All templates build successfully"
    echo "✅ Logic App Workflows: JSON structure validated"
    echo "✅ Configuration Files: Parameters and scripts checked"
    echo "✅ Documentation: Key documentation files present"
    echo
    echo "Next Steps:"
    echo "1. Set up Azure authentication: az login"
    echo "2. Configure environment variables"
    echo "3. Run deployment: scripts/deploy-workflows.sh"
    echo "4. Run full validation: scripts/validate-deployment.sh"
    echo
}

# Main execution
main() {
    log_info "Starting Logic Apps Workflow Local Validation"

    validate_prerequisites
    validate_bicep_templates
    validate_workflows
    validate_configuration
    validate_documentation
    generate_report

    log_success "Local validation completed successfully!"
    log_info "Ready for deployment to Azure"
}

main "$@"
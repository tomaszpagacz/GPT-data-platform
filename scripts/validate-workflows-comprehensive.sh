#!/usr/bin/env bash
#set -euo pipefail

# Comprehensive Logic Apps Workflow Validation Script
# Validates workflow definitions, structure, parameters, triggers, actions, and connections

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SCRIPT_DIR" || "$SCRIPT_DIR" == "." ]]; then
    SCRIPT_DIR="$(pwd)"
fi
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Hardcode for testing
PROJECT_ROOT="/workspaces/GPT-data-platform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validate JSON structure
validate_json_structure() {
    local workflow_file="$1"
    local workflow_name="$2"
    local output_file="$3"

    log_info "Validating JSON structure for $workflow_name..."

    local timestamp=$(date -Iseconds)
    local temp_file=$(mktemp)
    
    jq -n \
        --arg workflow "$workflow_name" \
        --arg file "$workflow_file" \
        --arg timestamp "$timestamp" \
        '{"workflow":$workflow,"file":$file,"timestamp":$timestamp,"checks":[]}' > "$temp_file"

    # Check if valid JSON
    if jq empty "$workflow_file" &> /dev/null; then
        log_success "$workflow_name is valid JSON"
        jq '.checks += [{"check":"json_valid","status":"passed"}]' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
    else
        log_error "$workflow_name is not valid JSON"
        jq '.checks += [{"check":"json_valid","status":"failed","error":"Invalid JSON syntax"}]' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
        cat "$temp_file"
        rm "$temp_file"
        return 1
    fi

    cat "$temp_file"
    rm "$temp_file"
}

# Validate workflow definition structure
validate_workflow_definition() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow definition structure for $workflow_name..."

    # Check for definition object
    if jq -e '.definition' "$workflow_file" &> /dev/null; then
        log_success "$workflow_name has workflow definition"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_definition","status":"passed"}]')
    else
        log_error "$workflow_name missing workflow definition"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_definition","status":"failed","error":"Missing definition object"}]')
        return 1
    fi

    # Check for required definition fields
    local required_fields=("contentVersion" "parameters" "triggers" "actions")
    for field in "${required_fields[@]}"; do
        if jq -e ".definition.$field" "$workflow_file" &> /dev/null; then
            log_success "$workflow_name has $field"
            validation_result=$(echo "$validation_result" | jq --arg check "has_$field" '.checks += [{"check":$check,"status":"passed"}]')
        else
            log_warning "$workflow_name missing $field"
            validation_result=$(echo "$validation_result" | jq --arg check "has_$field" --arg field "$field" '.checks += [{"check":$check,"status":"warning","message":"Missing \($field) field"}]')
        fi
    done

    # Check for schema
    if jq -e '.definition."$schema"' "$workflow_file" &> /dev/null; then
        log_success "$workflow_name has schema definition"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_schema","status":"passed"}]')
    else
        log_warning "$workflow_name missing schema definition"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_schema","status":"warning","message":"Missing $schema field"}]')
    fi

    echo "$validation_result"
}

# Validate workflow parameters
validate_workflow_parameters() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow parameters for $workflow_name..."

    # Get parameters count
    local param_count=$(jq '.definition.parameters | length' "$workflow_file" 2>/dev/null || echo "0")

    if [[ "$param_count" -gt 0 ]]; then
        log_success "$workflow_name has $param_count parameters"

        # Validate each parameter has required fields
        local param_names=$(jq -r '.definition.parameters | keys[]' "$workflow_file" 2>/dev/null || echo "")
        for param in $param_names; do
            if jq -e ".definition.parameters.\"$param\".type" "$workflow_file" &> /dev/null; then
                local param_type=$(jq -r ".definition.parameters.\"$param\".type" "$workflow_file")
                log_success "Parameter $param has type: $param_type"
                validation_result=$(echo "$validation_result" | jq --arg check "param_${param}_type" --arg type "$param_type" '.checks += [{"check":$check,"status":"passed","type":$type}]')
            else
                log_warning "Parameter $param missing type"
                validation_result=$(echo "$validation_result" | jq --arg check "param_${param}_type" --arg param "$param" '.checks += [{"check":$check,"status":"warning","message":"Missing type for parameter \($param)"}]')
            fi
        done
    else
        log_warning "$workflow_name has no parameters"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_parameters","status":"warning","message":"No parameters defined"}]')
    fi

    echo "$validation_result"
}

# Validate workflow triggers
validate_workflow_triggers() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow triggers for $workflow_name..."

    # Get triggers count
    local trigger_count=$(jq '.definition.triggers | length' "$workflow_file" 2>/dev/null || echo "0")

    if [[ "$trigger_count" -gt 0 ]]; then
        log_success "$workflow_name has $trigger_count trigger(s)"

        # Validate each trigger
        local trigger_names=$(jq -r '.definition.triggers | keys[]' "$workflow_file" 2>/dev/null || echo "")
        for trigger in $trigger_names; do
            if jq -e ".definition.triggers.\"$trigger\".type" "$workflow_file" &> /dev/null; then
                local trigger_type=$(jq -r ".definition.triggers.\"$trigger\".type" "$workflow_file")
                log_success "Trigger $trigger has type: $trigger_type"
                validation_result=$(echo "$validation_result" | jq --arg check "trigger_${trigger}_type" --arg type "$trigger_type" '.checks += [{"check":$check,"status":"passed","type":$type}]')
            else
                log_warning "Trigger $trigger missing type"
                validation_result=$(echo "$validation_result" | jq --arg check "trigger_${trigger}_type" --arg trigger "$trigger" '.checks += [{"check":$check,"status":"warning","message":"Missing type for trigger \($trigger)"}]')
            fi
        done
    else
        log_warning "$workflow_name has no triggers"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_triggers","status":"warning","message":"No triggers defined"}]')
    fi

    echo "$validation_result"
}

# Validate workflow actions
validate_workflow_actions() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow actions for $workflow_name..."

    # Get actions count
    local action_count=$(jq '.definition.actions | length' "$workflow_file" 2>/dev/null || echo "0")

    if [[ "$action_count" -gt 0 ]]; then
        log_success "$workflow_name has $action_count action(s)"

        # Validate each action
        local action_names=$(jq -r '.definition.actions | keys[]' "$workflow_file" 2>/dev/null || echo "")
        for action in $action_names; do
            if jq -e ".definition.actions.\"$action\".type" "$workflow_file" &> /dev/null; then
                local action_type=$(jq -r ".definition.actions.\"$action\".type" "$workflow_file")
                log_success "Action $action has type: $action_type"
                validation_result=$(echo "$validation_result" | jq --arg check "action_${action}_type" --arg type "$action_type" '.checks += [{"check":$check,"status":"passed","type":$type}]')
            else
                log_warning "Action $action missing type"
                validation_result=$(echo "$validation_result" | jq --arg check "action_${action}_type" --arg action "$action" '.checks += [{"check":$check,"status":"warning","message":"Missing type for action \($action)"}]')
            fi
        done
    else
        log_warning "$workflow_name has no actions"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_actions","status":"warning","message":"No actions defined"}]')
    fi

    echo "$validation_result"
}

# Validate workflow connections
validate_workflow_connections() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow connections for $workflow_name..."

    # Check for connections object
    if jq -e '.connections' "$workflow_file" &> /dev/null; then
        log_success "$workflow_name has connections object"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_connections","status":"passed"}]')

        # Get connections count
        local conn_count=$(jq '.connections | length' "$workflow_file" 2>/dev/null || echo "0")
        log_info "$workflow_name has $conn_count connection(s)"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"connection_count","status":"info","count":'$conn_count'}]')
    else
        log_info "$workflow_name has no connections (using inline authentication)"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_connections","status":"info","message":"No connections object (using inline authentication)"}]')
    fi

    echo "$validation_result"
}

# Validate workflow kind
validate_workflow_kind() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Validating workflow kind for $workflow_name..."

    # Check for kind
    if jq -e '.kind' "$workflow_file" &> /dev/null; then
        local workflow_kind=$(jq -r '.kind' "$workflow_file")
        log_success "$workflow_name has kind: $workflow_kind"
        validation_result=$(echo "$validation_result" | jq --arg kind "$workflow_kind" '.checks += [{"check":"workflow_kind","status":"passed","kind":$kind}]')
    else
        log_warning "$workflow_name missing kind (defaulting to Stateful)"
        validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"workflow_kind","status":"warning","message":"Missing kind field (will default to Stateful)"}]')
    fi

    echo "$validation_result"
}

# Generate workflow summary
generate_workflow_summary() {
    local workflow_file="$1"
    local workflow_name="$2"
    local validation_result="$3"

    log_info "Generating summary for $workflow_name..."

    # Extract key metrics
    local param_count=$(jq '.definition.parameters | length' "$workflow_file" 2>/dev/null || echo "0")
    local trigger_count=$(jq '.definition.triggers | length' "$workflow_file" 2>/dev/null || echo "0")
    local action_count=$(jq '.definition.actions | length' "$workflow_file" 2>/dev/null || echo "0")
    local conn_count=$(jq '.connections | length' "$workflow_file" 2>/dev/null || echo "0")
    local workflow_kind=$(jq -r '.kind // "Stateful"' "$workflow_file")

    local summary=$(jq -n \
        --arg name "$workflow_name" \
        --arg kind "$workflow_kind" \
        --argjson params "$param_count" \
        --argjson triggers "$trigger_count" \
        --argjson actions "$action_count" \
        --argjson connections "$conn_count" \
        '{"name":$name,"kind":$kind,"metrics":{"parameters":$params,"triggers":$triggers,"actions":$actions,"connections":$connections}}')

    validation_result=$(echo "$validation_result" | jq --argjson summary "$summary" '.summary = $summary')

    echo "$validation_result"
}

# Validate single workflow
validate_single_workflow() {
    local workflow_file="$1"
    local output_dir="$2"

    local workflow_name=$(basename "$workflow_file" .workflow.json)
    local output_file="$output_dir/${workflow_name}-validation.json"

    log_info "Starting comprehensive validation for $workflow_name..."

    # Initialize validation result
    local validation_result=$(validate_json_structure "$workflow_file" "$workflow_name" "$output_file")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Continue with other validations
    validation_result=$(validate_workflow_definition "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(validate_workflow_parameters "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(validate_workflow_triggers "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(validate_workflow_actions "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(validate_workflow_connections "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(validate_workflow_kind "$workflow_file" "$workflow_name" "$validation_result")
    validation_result=$(generate_workflow_summary "$workflow_file" "$workflow_name" "$validation_result")

    # Save final validation result
    echo "$validation_result" > "$output_file"

    log_success "Completed validation for $workflow_name"
}

# Generate comprehensive report
generate_comprehensive_report() {
    local output_dir="$1"
    local workflow_count="$2"

    log_info "Generating comprehensive validation report..."

    local report_file="$output_dir/workflow-validation-report-$(date +%Y%m%d-%H%M%S).json"

    # Initialize report structure
    local report='{
        "timestamp": "'$(date -Iseconds)'",
        "total_workflows": '$workflow_count',
        "validation_results": [],
        "summary": {
            "passed_checks": 0,
            "warning_checks": 0,
            "failed_checks": 0,
            "info_checks": 0,
            "total_checks": 0
        }
    }'

    # Collect all validation results safely
    local validation_files=("$output_dir"/*-validation.json)
    local collected_results=0

    for validation_file in "${validation_files[@]}"; do
        if [[ -f "$validation_file" && "$validation_file" != "$report_file" ]]; then
            log_info "Processing validation file: $(basename "$validation_file")"

            # Read the validation result safely
            if local result=$(cat "$validation_file" 2>/dev/null); then
                # Validate it's proper JSON
                if echo "$result" | jq empty &>/dev/null; then
                    # Add to results array using jq safely
                    if report=$(echo "$report" | jq --argjson item "$result" '.validation_results += [$item]' 2>/dev/null); then
                        ((collected_results++))
                        log_success "Added validation result for $(basename "$validation_file" -validation.json)"
                    else
                        log_warning "Failed to add result from $(basename "$validation_file") to report"
                    fi
                else
                    log_warning "Invalid JSON in $(basename "$validation_file")"
                fi
            else
                log_warning "Could not read $(basename "$validation_file")"
            fi
        fi
    done

    log_info "Collected $collected_results validation results"

    # Calculate summary statistics safely
    if [[ $collected_results -gt 0 ]]; then
        # Count checks by status
        local passed_count=$(echo "$report" | jq '[.validation_results[] | .checks[] | select(.status == "passed")] | length' 2>/dev/null || echo "0")
        local warning_count=$(echo "$report" | jq '[.validation_results[] | .checks[] | select(.status == "warning")] | length' 2>/dev/null || echo "0")
        local failed_count=$(echo "$report" | jq '[.validation_results[] | .checks[] | select(.status == "failed")] | length' 2>/dev/null || echo "0")
        local info_count=$(echo "$report" | jq '[.validation_results[] | .checks[] | select(.status == "info")] | length' 2>/dev/null || echo "0")
        local total_checks=$((passed_count + warning_count + failed_count + info_count))

        # Update summary in report
        report=$(echo "$report" | jq \
            --argjson passed "$passed_count" \
            --argjson warnings "$warning_count" \
            --argjson failed "$failed_count" \
            --argjson info "$info_count" \
            --argjson total "$total_checks" \
            '.summary.passed_checks = $passed | .summary.warning_checks = $warnings | .summary.failed_checks = $failed | .summary.info_checks = $info | .summary.total_checks = $total' 2>/dev/null || echo "$report")
    fi

    # Save the report
    echo "$report" > "$report_file"

    # Print summary to console
    echo
    echo "========================================"
    echo "WORKFLOW VALIDATION REPORT"
    echo "========================================"
    echo "Date: $(date)"
    echo "Total Workflows: $workflow_count"
    echo "Collected Results: $collected_results"
    echo "Report saved to: $report_file"
    echo "========================================"

    if [[ $collected_results -gt 0 ]]; then
        local passed_count=$(echo "$report" | jq -r '.summary.passed_checks' 2>/dev/null || echo "0")
        local warning_count=$(echo "$report" | jq -r '.summary.warning_checks' 2>/dev/null || echo "0")
        local failed_count=$(echo "$report" | jq -r '.summary.failed_checks' 2>/dev/null || echo "0")
        local info_count=$(echo "$report" | jq -r '.summary.info_checks' 2>/dev/null || echo "0")
        local total_checks=$(echo "$report" | jq -r '.summary.total_checks' 2>/dev/null || echo "0")

        echo "Validation Summary:"
        echo "✅ Passed checks: $passed_count"
        echo "⚠️  Warning checks: $warning_count"
        echo "❌ Failed checks: $failed_count"
        echo "ℹ️  Info checks: $info_count"
        echo "📊 Total checks: $total_checks"
    else
        echo "❌ No validation results could be collected"
    fi

    echo "========================================"
}

# Main execution
main() {
    log_info "Starting Comprehensive Logic Apps Workflow Validation"

    local workflow_dir="$PROJECT_ROOT/src/logic-apps/workflows"
    local output_dir="$PROJECT_ROOT/validation_outputs/workflows"

    # Create output directory
    mkdir -p "$output_dir"

    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflows directory not found: $workflow_dir"
        exit 1
    fi

    local workflow_count=0
    local failed_count=0

    # Validate each workflow
    for workflow_file in "$workflow_dir"/*.workflow.json; do
        if [[ -f "$workflow_file" ]]; then
            ((workflow_count++))
            local workflow_name=$(basename "$workflow_file" .workflow.json)

            if validate_single_workflow "$workflow_file" "$output_dir"; then
                log_success "Successfully validated $workflow_name"
            else
                log_error "Failed to validate $workflow_name"
                ((failed_count++))
            fi
        fi
    done

    if [[ $workflow_count -eq 0 ]]; then
        log_warning "No workflow files found"
        exit 1
    fi

    # Generate comprehensive report
    log_info "About to generate comprehensive report..."
    generate_comprehensive_report "$output_dir" "$workflow_count"
    log_info "Report generation completed successfully"

    log_info "Validation complete. failed_count=$failed_count, workflow_count=$workflow_count"

    if [[ $failed_count -eq 0 ]]; then
        log_success "All $workflow_count workflow(s) validated successfully!"
        log_info "Exiting with code 0"
        exit 0
    else
        log_error "$failed_count out of $workflow_count workflow(s) failed validation"
        log_info "Exiting with code 1"
        exit 1
    fi
}

main "$@"
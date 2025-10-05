#!/usr/bin/env bash

PROJECT_ROOT="/workspaces/GPT-data-platform"
workflow_dir="$PROJECT_ROOT/src/logic-apps/workflows"
output_dir="$PROJECT_ROOT/validation_outputs/workflows"

echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "workflow_dir=$workflow_dir"
echo "output_dir=$output_dir"

mkdir -p "$output_dir"

if [[ ! -d "$workflow_dir" ]]; then
    echo "ERROR: Workflows directory not found: $workflow_dir"
    exit 1
fi

echo "Workflow directory exists"

workflow_count=0
failed_count=0

# Validate each workflow
for workflow_file in "$workflow_dir"/*.workflow.json; do
    echo "Processing file: $workflow_file"
    if [[ -f "$workflow_file" ]]; then
        ((workflow_count++))
        workflow_name=$(basename "$workflow_file" .workflow.json)
        echo "Workflow name: $workflow_name, count: $workflow_count"

        # Simple validation
        if jq empty "$workflow_file" >/dev/null 2>&1; then
            echo "JSON is valid for $workflow_name"
            
            # Check definition
            if jq -e '.definition' "$workflow_file" >/dev/null 2>&1; then
                echo "Has definition for $workflow_name"
                
                # Check required fields
                required_fields=("contentVersion" "parameters" "triggers" "actions")
                for field in "${required_fields[@]}"; do
                    if jq -e ".definition.$field" "$workflow_file" >/dev/null 2>&1; then
                        echo "Has $field for $workflow_name"
                    else
                        echo "Missing $field for $workflow_name"
                    fi
                done
                
                echo "Successfully validated $workflow_name"
                echo "{\"workflow\":\"$workflow_name\",\"status\":\"passed\"}" > "$output_dir/${workflow_name}-validation.json"
            else
                echo "No definition for $workflow_name"
                echo "Failed to validate $workflow_name"
                ((failed_count++))
            fi
        else
            echo "Invalid JSON for $workflow_name"
            echo "Failed to validate $workflow_name"
            ((failed_count++))
        fi
    else
        echo "Not a file: $workflow_file"
    fi
done

echo "Total workflows: $workflow_count"
echo "Failed: $failed_count"

if [[ $failed_count -eq 0 ]]; then
    echo "All $workflow_count workflow(s) validated successfully!"
    exit 0
else
    echo "$failed_count out of $workflow_count workflow(s) failed validation"
    exit 1
fi
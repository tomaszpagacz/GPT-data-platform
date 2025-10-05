#!/usr/bin/env bash

PROJECT_ROOT="/workspaces/GPT-data-platform"
workflow_file="$PROJECT_ROOT/src/logic-apps/workflows/wf-blob-router-to-events.workflow.json"
workflow_name="wf-blob-router-to-events"
output_file="$PROJECT_ROOT/validation_outputs/workflows/debug-validation.json"

mkdir -p "$PROJECT_ROOT/validation_outputs/workflows"

echo "Testing individual validation functions..."

# Test validate_json_structure
echo "1. Testing validate_json_structure..."
if jq empty "$workflow_file" 2>/dev/null; then
    echo "   JSON is valid"
else
    echo "   ERROR: Invalid JSON"
    exit 1
fi

# Test validate_workflow_definition
echo "2. Testing validate_workflow_definition..."
if jq -e '.definition' "$workflow_file" >/dev/null 2>&1; then
    echo "   Has definition"
else
    echo "   ERROR: No definition"
    exit 1
fi

# Test validate_workflow_parameters
echo "3. Testing validate_workflow_parameters..."
param_count=$(jq '.definition.parameters | length' "$workflow_file" 2>/dev/null || echo "0")
echo "   Parameter count: $param_count"

param_names=$(jq -r '.definition.parameters | keys[]' "$workflow_file" 2>/dev/null || echo "")
echo "   Parameter names: $param_names"

for param in $param_names; do
    echo "   Processing parameter: $param"
    if jq -e ".definition.parameters.\"$param\".type" "$workflow_file" >/dev/null 2>&1; then
        param_type=$(jq -r ".definition.parameters.\"$param\".type" "$workflow_file")
        echo "   Parameter $param has type: $param_type"
    else
        echo "   ERROR: Parameter $param missing type"
    fi
done

echo "Test completed successfully"
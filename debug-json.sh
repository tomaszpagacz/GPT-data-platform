#!/usr/bin/env bash

PROJECT_ROOT="/workspaces/GPT-data-platform"
workflow_file="$PROJECT_ROOT/src/logic-apps/workflows/wf-blob-router-to-events.workflow.json"
workflow_name="wf-blob-router-to-events"
output_file="$PROJECT_ROOT/validation_outputs/workflows/debug-validation.json"

mkdir -p "$PROJECT_ROOT/validation_outputs/workflows"

echo "Testing JSON manipulation..."

# Initialize validation result
timestamp=$(date -Iseconds)
validation_result=$(jq -n \
    --arg workflow "$workflow_name" \
    --arg file "$workflow_file" \
    --arg timestamp "$timestamp" \
    '{"workflow":$workflow,"file":$file,"timestamp":$timestamp,"checks":[]}')

echo "Initial validation_result:"
echo "$validation_result" | jq .

# Test adding a check
echo "Adding json_valid check..."
validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"json_valid","status":"passed"}]')
echo "After adding json_valid:"
echo "$validation_result" | jq .

# Test adding has_definition check
echo "Adding has_definition check..."
validation_result=$(echo "$validation_result" | jq '.checks += [{"check":"has_definition","status":"passed"}]')
echo "After adding has_definition:"
echo "$validation_result" | jq .

# Test parameter validation
echo "Testing parameter validation..."
param_names=$(jq -r '.definition.parameters | keys[]' "$workflow_file" 2>/dev/null || echo "")
for param in $param_names; do
    echo "Processing parameter: $param"
    param_type=$(jq -r ".definition.parameters.\"$param\".type" "$workflow_file")
    echo "Type: $param_type"
    validation_result=$(echo "$validation_result" | jq --arg check "param_${param}_type" --arg type "$param_type" '.checks += [{"check":$check,"status":"passed","type":$type}]')
    echo "After adding param check:"
    echo "$validation_result" | jq .
done

echo "JSON manipulation test completed successfully"
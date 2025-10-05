#!/usr/bin/env bash

PROJECT_ROOT="/workspaces/GPT-data-platform"

# Test script to validate one workflow
workflow_file="$PROJECT_ROOT/src/logic-apps/workflows/wf-blob-router-to-events.workflow.json"
output_dir="$PROJECT_ROOT/validation_outputs/workflows"

mkdir -p "$output_dir"
output_file="$output_dir/test-validation.json"

echo "Testing validation of $workflow_file"

# Check if file exists
if [[ ! -f "$workflow_file" ]]; then
    echo "ERROR: Workflow file not found: $workflow_file"
    exit 1
fi

echo "File exists, checking JSON validity..."

# Check JSON validity
if jq empty "$workflow_file" 2>/dev/null; then
    echo "JSON is valid"
else
    echo "ERROR: Invalid JSON"
    exit 1
fi

echo "JSON valid, checking definition..."

# Check definition
if jq -e '.definition' "$workflow_file" >/dev/null 2>&1; then
    echo "Has definition"
else
    echo "ERROR: No definition"
    exit 1
fi

echo "Test completed successfully"
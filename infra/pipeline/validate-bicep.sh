#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Bicep validation...${NC}"

# Check if bicep is installed
if ! command -v bicep &> /dev/null; then
    echo -e "${RED}Bicep is not installed. Installing...${NC}"
    az bicep install
fi

# Directory containing Bicep files
BICEP_DIR="/workspaces/GPT-data-platform/infra"
OUTPUT_DIR="/workspaces/GPT-data-platform/infra/build_output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to validate a single Bicep file
validate_bicep() {
    local file=$1
    local relative_path=${file#$BICEP_DIR/}
    echo -e "\n${YELLOW}Validating: $relative_path${NC}"
    
    # Create output directory structure
    local output_file="$OUTPUT_DIR/${relative_path%.bicep}.json"
    mkdir -p "$(dirname "$output_file")"
    
    # Linting check (if available)
    if command -v bicep-lint &> /dev/null; then
        if ! bicep-lint "$file" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Linting warnings in: $relative_path${NC}"
        fi
    fi
    
    # Build Bicep to ARM template
    if bicep build "$file" --outfile "$output_file" 2>&1; then
        echo -e "${GREEN}✓ Successfully built: $relative_path${NC}"
        
        # Validate JSON structure
        if jq empty "$output_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Valid JSON structure: $relative_path${NC}"
        else
            echo -e "${RED}✗ Invalid JSON structure: $relative_path${NC}"
            return 1
        fi
        
        # Check for required ARM template properties
        if ! jq -e '.schema' "$output_file" >/dev/null 2>&1; then
            echo -e "${RED}✗ Missing schema definition: $relative_path${NC}"
            return 1
        fi
        
        echo -e "${GREEN}✓ All validations passed: $relative_path${NC}"
    else
        echo -e "${RED}✗ Build failed: $relative_path${NC}"
        return 1
    fi
}

# Counter for failures
FAILURES=0
TOTAL=0

# Process all Bicep files
while IFS= read -r -d '' file; do
    ((TOTAL++))
    if ! validate_bicep "$file"; then
        ((FAILURES++))
    fi
done < <(find "$BICEP_DIR" -name "*.bicep" -print0)

# Summary
echo -e "\n${YELLOW}=== Validation Summary ===${NC}"
echo -e "Total files processed: $TOTAL"
echo -e "Successful: $((TOTAL-FAILURES))"
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All Bicep files validated successfully!${NC}"
    exit 0
else
    echo -e "${RED}Failed validations: $FAILURES${NC}"
    exit 1
fi
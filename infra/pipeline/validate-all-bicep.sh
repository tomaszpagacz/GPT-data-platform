#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to validate a Bicep file
validate_bicep() {
    local file=$1
    echo -e "\n${YELLOW}Testing: $file${NC}"
    
    # Create build output directory structure
    local relative_path=${file#/workspaces/GPT-data-platform/}
    local output_dir="/workspaces/GPT-data-platform/validation_outputs/bicep"
    local output_file="$output_dir/${relative_path%.bicep}.json"
    mkdir -p "$(dirname "$output_file")"

    # Try to build the Bicep file
    if bicep build "$file" --outfile "$output_file" 2>&1; then
        echo -e "${GREEN}✓ Successfully built: $file${NC}"
        return 0
    else
        echo -e "${RED}✗ Build failed: $file${NC}"
        return 1
    fi
}

# Find and validate all Bicep files
echo -e "${YELLOW}Starting Bicep validation for all files...${NC}"

# Initialize counters
total=0
success=0
failed=0
failed_files=()

# Process each Bicep file
while IFS= read -r -d '' file; do
    ((total++))
    if validate_bicep "$file"; then
        ((success++))
    else
        ((failed++))
        failed_files+=("$file")
    fi
done < <(find /workspaces/GPT-data-platform -name "*.bicep" -type f -print0)

# Print summary
echo -e "\n${YELLOW}=== Validation Summary ===${NC}"
echo -e "Total files processed: $total"
echo -e "${GREEN}Successfully built: $success${NC}"
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All Bicep files built successfully!${NC}"
else
    echo -e "${RED}Failed builds: $failed${NC}"
    echo -e "\n${RED}Failed files:${NC}"
    printf '%s\n' "${failed_files[@]}"
    exit 1
fi
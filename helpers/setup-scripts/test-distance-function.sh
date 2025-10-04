#!/bin/bash

# Script to test the Distance Calculation Function

echo "Testing Distance Calculation Function..."

# Function to make a test request
make_request() {
    local data=$1
    local description=$2
    echo "Testing: $description"
    curl -X POST \
         -H "Content-Type: application/json" \
         -d "$data" \
         http://localhost:7071/api/CalculateDistance
    echo -e "\n"
}

# Read test cases from JSON file
TEST_CASES_FILE="../test-data/distance-test-cases.json"

if [ ! -f "$TEST_CASES_FILE" ]; then
    echo "Error: Test cases file not found at $TEST_CASES_FILE"
    exit 1
fi

# Extract and run each test case
for test in $(jq -c '.testCases[]' "$TEST_CASES_FILE"); do
    name=$(echo $test | jq -r '.name')
    input=$(echo $test | jq -r '.input')
    description=$(echo $test | jq -r '.description')
    
    echo "Running test: $name"
    echo "$description"
    make_request "$input" "$description"
done
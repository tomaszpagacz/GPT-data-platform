#!/bin/bash

# Script to run Logic Apps locally using Azure Functions runtime

echo "Setting up local Logic Apps environment..."

# Function to find an available port
find_available_port() {
    local port=$1
    while nc -z localhost "$port" 2>/dev/null; do
        port=$((port + 1))
    done
    echo "$port"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    local missing_deps=()

    if ! command_exists func; then
        missing_deps+=("Azure Functions Core Tools")
    fi

    if ! command_exists jq; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies:"
        printf '%s\n' "${missing_deps[@]}"
        echo -e "\nPlease run: ./helpers/setup-scripts/install-dependencies.sh"
        exit 1
    fi
}

# Create or update workflow files for Logic Apps
create_workflows() {
    echo "Creating workflow files..."
    
    for workflow in "hello-world" "travel-assistant"; do
        # Initialize function app if it doesn't exist
        if [ ! -d "/workspaces/GPT-data-platform/src/logic-apps/$workflow" ]; then
            mkdir -p "/workspaces/GPT-data-platform/src/logic-apps/$workflow"
            cd "/workspaces/GPT-data-platform/src/logic-apps/$workflow"
            func init . --javascript
            func new --template "HTTP trigger" --name workflow
            npm install
            cd - > /dev/null
        fi
    done
}

# Create local settings for Logic Apps
create_local_settings() {
    echo "Creating local settings..."
    
    for workflow in "hello-world" "travel-assistant"; do
        # Create local.settings.json
        cat > "/workspaces/GPT-data-platform/src/logic-apps/$workflow/local.settings.json" << EOF
{
    "IsEncrypted": false,
    "Values": {
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "AzureWebJobsStorage": "UseDevelopmentStorage=true"
    }
}
EOF

        # Create host.json
        cat > "/workspaces/GPT-data-platform/src/logic-apps/$workflow/host.json" << EOF
{
    "version": "2.0",
    "extensionBundle": {
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[2.6.1, 3.0.0)"
    },
    "logging": {
        "logLevel": {
            "default": "Information"
        }
    }
}
EOF
    done
}

# Function to start a Logic App instance
start_logic_app() {
    local workflow=$1
    local requested_port=$2
    local port=$(find_available_port "$requested_port")
    echo "Starting Logic App: $workflow on port $port..."
    cd "/workspaces/GPT-data-platform/src/logic-apps/$workflow"
    func start --port "$port" &
    local pid=$!
    cd - > /dev/null
    # Convert dashes to underscores in workflow name for valid variable names
    local workflow_var=$(echo "$workflow" | tr '-' '_')
    export "${workflow_var}_PID"="$pid"
    export "${workflow_var}_PORT"="$port"
    echo "Logic App $workflow started with PID: $pid on port $port"
    sleep 10 # Give it more time to start
}

# Run test cases
run_tests() {
    local hw_port="${hello_world_PORT:-7072}"
    local ta_port="${travel_assistant_PORT:-7073}"

    echo -e "\nTesting Hello World Logic App..."
    response=$(curl -s -X POST "http://localhost:$hw_port/api/workflow" \
         -H "Content-Type: application/json" \
         -d '{"name": "Local Test User"}')
    if [[ "$response" == "[object Object]" ]]; then
        echo "Error: Function returned [object Object]. This usually means JSON.stringify() wasn't called."
    else
        echo "$response" | jq '.'
    fi

    echo -e "\nTesting Travel Assistant Logic App..."
    response=$(curl -s -X POST "http://localhost:$ta_port/api/workflow" \
         -H "Content-Type: application/json" \
         -d '{
             "address": "350 5th Ave, New York, NY 10118",
             "targetLanguage": "es",
             "sourceLanguage": "en",
             "currentLocation": {
                 "latitude": 40.7484,
                 "longitude": -73.9857
             },
             "travelMode": "driving"}')
    if [[ "$response" == "[object Object]" ]]; then
        echo "Error: Function returned [object Object]. This usually means JSON.stringify() wasn't called."
    else
        echo "$response" | jq '.'
    fi
}

# Cleanup function
cleanup() {
    echo -e "\nCleaning up..."
    kill $hello_world_PID 2>/dev/null
    kill $travel_assistant_PID 2>/dev/null
}

# Set up trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    check_prerequisites
    create_workflows
    create_local_settings
    start_logic_app "hello-world" 7072
    start_logic_app "travel-assistant" 7073
    
    echo -e "\nLocal environment is ready!"
    echo "Hello World Logic App: http://localhost:7072/api/workflow"
    echo "Travel Assistant Logic App: http://localhost:7073/api/workflow"
    
    read -p "Do you want to run test cases now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_tests
    fi
    
    echo -e "\nPress Ctrl+C to stop all services..."
    wait
}

main
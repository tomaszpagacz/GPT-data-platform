#!/bin/bash

# Script to run Logic Apps locally using Azure Functions runtime

echo "Setting up local Logic Apps environment..."

# Function to cleanup ports and processes
cleanup_ports() {
    local ports=("$@")
    echo "Cleaning up ports ${ports[*]}..."
    
    # Find and kill processes using the specified ports
    for port in "${ports[@]}"; do
        local pids=$(lsof -ti :"$port" 2>/dev/null)
        if [ -n "$pids" ]; then
            echo "Killing processes on port $port: $pids"
            kill -9 $pids 2>/dev/null || true
        fi
    done
    
    # Additional cleanup for any lingering func processes
    pkill -f "func host start" 2>/dev/null || true
    
    # Wait a moment to ensure ports are released
    sleep 2
}

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
        fi
    done
}

# Create or update local settings for Logic Apps
create_settings() {
    echo "Creating local settings..."

    for workflow in "hello-world" "travel-assistant"; do
        local settings_file="/workspaces/GPT-data-platform/src/logic-apps/$workflow/local.settings.json"
        if [ ! -f "$settings_file" ]; then
            cat > "$settings_file" << EOL
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "node"
    }
}
EOL
        fi
    done
}

# Start Logic App with specified port
start_logic_app() {
    local workflow=$1
    local port=$2

    echo "Starting Logic App: $workflow on port $port..."
    cd "/workspaces/GPT-data-platform/src/logic-apps/$workflow"

    # Check if func is already running and if it is, kill it
    pgrep -f "func host start --port $port" >/dev/null && pkill -f "func host start --port $port"

    func host start --port "$port" &
    local pid=$!
    echo "Logic App $workflow started with PID: $pid on port $port"

    # Wait a bit for the app to start
    sleep 5
}

# Function to test the Logic App endpoints
test_logic_apps() {
    local hello_port=$1
    local travel_port=$2

    echo "Testing Logic App endpoints..."

    # Test hello-world endpoint
    hello_response=$(curl -s -X POST "http://localhost:$hello_port/api/workflow" \
        -H "Content-Type: application/json" \
        -d '{"name": "Test User"}')
    
    echo "Hello-world response: $hello_response"

    # Test travel-assistant endpoint
    travel_response=$(curl -s -X POST "http://localhost:$travel_port/api/workflow" \
        -H "Content-Type: application/json" \
        -d '{"destination": "Paris", "duration": "7 days"}')
    
    echo "Travel-assistant response: $travel_response"
}

# Cleanup function
cleanup() {
    echo -e "\nCleaning up..."
    cleanup_ports $hello_port $travel_port
    exit 0
}

# Set up trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Main execution
check_prerequisites
create_workflows
create_settings

# Define default ports
hello_port=7072
travel_port=7073

# Clean up ports before starting
cleanup_ports $hello_port $travel_port

# Start Logic Apps
start_logic_app "hello-world" "$hello_port"
start_logic_app "travel-assistant" "$travel_port"

# Wait for apps to start properly
sleep 10

test_logic_apps "$hello_port" "$travel_port"

# Keep the script running
echo "Press Ctrl+C to stop the Logic Apps"
wait
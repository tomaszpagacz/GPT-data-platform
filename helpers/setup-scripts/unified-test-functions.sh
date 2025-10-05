#!/bin/bash

# Unified Azure Functions Local Testing Script
# Consolidates functionality from test-functions-local.sh and test-functions-local-v2.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_FUNCTIONS_PORT=7071
DEFAULT_LOGIC_APPS_PORT=7072
STORAGE_EMULATOR_PORT=10000

# Global variables
FUNCTIONS_PORT=""
LOGIC_APPS_PORT=""
CLEANUP_ON_EXIT=true
VERBOSE=false

# Usage information
show_usage() {
    echo -e "${BLUE}Azure Functions & Logic Apps Local Testing${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --functions-port PORT    Port for Azure Functions (default: $DEFAULT_FUNCTIONS_PORT)"
    echo "  --logic-apps-port PORT   Port for Logic Apps (default: $DEFAULT_LOGIC_APPS_PORT)"
    echo "  --no-cleanup            Don't cleanup processes on exit"
    echo "  --verbose               Enable verbose output"
    echo "  --test-distance         Run distance function tests only"
    echo "  --check-deps            Check dependencies and exit"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run with default settings"
    echo "  $0 --verbose            # Run with detailed output"
    echo "  $0 --test-distance      # Test distance function only"
}

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
    fi
}

# Function to cleanup ports and processes
cleanup_ports() {
    local ports=("$@")
    echo -e "${YELLOW}Cleaning up ports ${ports[*]}...${NC}"
    
    # Find and kill processes using the specified ports
    for port in "${ports[@]}"; do
        local pids=$(lsof -ti :"$port" 2>/dev/null || true)
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
    local max_attempts=50
    local attempts=0
    
    while nc -z localhost "$port" 2>/dev/null && [ $attempts -lt $max_attempts ]; do
        port=$((port + 1))
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        echo -e "${RED}Error: Could not find available port after $max_attempts attempts${NC}"
        exit 1
    fi
    
    echo "$port"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    local missing_deps=()

    if ! command_exists func; then
        missing_deps+=("Azure Functions Core Tools")
    fi

    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    if ! command_exists nc; then
        missing_deps+=("netcat")
    fi
    
    if ! command_exists lsof; then
        missing_deps+=("lsof")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        echo -e "\nPlease run: ./helpers/setup-scripts/unified-setup.sh --full"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites satisfied${NC}"
}

# Function to setup local.settings.json for Functions
setup_functions_config() {
    local functions_dir="$1"
    local settings_file="$functions_dir/local.settings.json"
    
    log "Setting up configuration for $functions_dir"
    
    if [ ! -f "$settings_file" ]; then
        echo -e "${YELLOW}Creating local.settings.json for Functions...${NC}"
        cat > "$settings_file" << EOF
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "AzureWebJobsFeatureFlags": "EnableWorkerIndexing",
    "AZURE_MAPS_KEY": "your-azure-maps-key-here",
    "AZURE_MAPS_CLIENT_ID": "your-azure-maps-client-id-here",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=00000000-0000-0000-0000-000000000000"
  },
  "Host": {
    "LocalHttpPort": $FUNCTIONS_PORT,
    "CORS": "*"
  }
}
EOF
        echo -e "${GREEN}✓ Created local.settings.json${NC}"
    else
        # Update the port in existing config
        jq --arg port "$FUNCTIONS_PORT" '.Host.LocalHttpPort = ($port | tonumber)' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
        echo -e "${GREEN}✓ Updated local.settings.json with port $FUNCTIONS_PORT${NC}"
    fi
}

# Function to test the distance function specifically
test_distance_function() {
    echo -e "${BLUE}Testing Distance Function...${NC}"
    
    local test_data_file="/workspaces/GPT-data-platform/helpers/test-data/distance-test-cases.json"
    
    if [ ! -f "$test_data_file" ]; then
        echo -e "${RED}Error: Test data file not found: $test_data_file${NC}"
        return 1
    fi
    
    # Wait for function to be ready
    local max_wait=30
    local wait_count=0
    
    while ! curl -s "http://localhost:$FUNCTIONS_PORT/api/health" >/dev/null 2>&1 && [ $wait_count -lt $max_wait ]; do
        sleep 1
        wait_count=$((wait_count + 1))
        echo -n "."
    done
    echo ""
    
    if [ $wait_count -eq $max_wait ]; then
        echo -e "${RED}Error: Function app did not start within $max_wait seconds${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Function app is ready${NC}"
    
    # Run test cases
    local test_count=0
    local passed_count=0
    
    while IFS= read -r test_case; do
        test_count=$((test_count + 1))
        
        local description=$(echo "$test_case" | jq -r '.description')
        local origin_lat=$(echo "$test_case" | jq -r '.origin.latitude')
        local origin_lng=$(echo "$test_case" | jq -r '.origin.longitude')
        local dest_lat=$(echo "$test_case" | jq -r '.destination.latitude')
        local dest_lng=$(echo "$test_case" | jq -r '.destination.longitude')
        local expected_min=$(echo "$test_case" | jq -r '.expected_range.min_km')
        local expected_max=$(echo "$test_case" | jq -r '.expected_range.max_km')
        
        echo -e "\n${BLUE}Test $test_count: $description${NC}"
        
        # Call the distance function
        local response=$(curl -s -X POST "http://localhost:$FUNCTIONS_PORT/api/distance" \
            -H "Content-Type: application/json" \
            -d "{\"origin\":{\"latitude\":$origin_lat,\"longitude\":$origin_lng},\"destination\":{\"latitude\":$dest_lat,\"longitude\":$dest_lng}}")
        
        if [ $? -eq 0 ] && echo "$response" | jq -e '.distance_km' >/dev/null 2>&1; then
            local actual_distance=$(echo "$response" | jq -r '.distance_km')
            
            # Check if distance is within expected range
            if (( $(echo "$actual_distance >= $expected_min && $actual_distance <= $expected_max" | bc -l) )); then
                echo -e "${GREEN}✓ PASSED: Distance $actual_distance km (expected: $expected_min-$expected_max km)${NC}"
                passed_count=$((passed_count + 1))
            else
                echo -e "${RED}✗ FAILED: Distance $actual_distance km (expected: $expected_min-$expected_max km)${NC}"
            fi
        else
            echo -e "${RED}✗ FAILED: Error calling function or invalid response${NC}"
            echo "Response: $response"
        fi
        
    done < <(jq -c '.test_cases[]' "$test_data_file")
    
    echo -e "\n${BLUE}=== Test Results ===${NC}"
    echo -e "Total tests: $test_count"
    echo -e "Passed: ${GREEN}$passed_count${NC}"
    echo -e "Failed: ${RED}$((test_count - passed_count))${NC}"
    
    if [ $passed_count -eq $test_count ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Function to start Azure Functions
start_functions() {
    local functions_dir="/workspaces/GPT-data-platform/src/functions"
    
    # Find all function apps
    local function_apps=$(find "$functions_dir" -name "*.csproj" -exec dirname {} \; 2>/dev/null || true)
    
    if [ -z "$function_apps" ]; then
        echo -e "${RED}No function apps found in $functions_dir${NC}"
        return 1
    fi
    
    # Start each function app
    for app_dir in $function_apps; do
        local app_name=$(basename "$app_dir")
        echo -e "${BLUE}Starting Function App: $app_name${NC}"
        
        setup_functions_config "$app_dir"
        
        cd "$app_dir"
        
        # Build the project
        echo "Building $app_name..."
        if ! dotnet build --verbosity quiet; then
            echo -e "${RED}Error: Failed to build $app_name${NC}"
            continue
        fi
        
        # Start the function app in background
        log "Starting func host for $app_name on port $FUNCTIONS_PORT"
        func host start --port "$FUNCTIONS_PORT" &
        local func_pid=$!
        
        echo -e "${GREEN}✓ Started $app_name (PID: $func_pid) on port $FUNCTIONS_PORT${NC}"
        
        # Store PID for cleanup
        echo $func_pid >> /tmp/func_pids.tmp
        
        cd - > /dev/null
        
        # Increment port for next app
        FUNCTIONS_PORT=$((FUNCTIONS_PORT + 1))
    done
}

# Function to start Logic Apps
start_logic_apps() {
    local logic_apps_dir="/workspaces/GPT-data-platform/src/logic-apps"
    
    if [ ! -d "$logic_apps_dir" ]; then
        echo -e "${YELLOW}No Logic Apps directory found, skipping...${NC}"
        return 0
    fi
    
    # Find Logic Apps
    local logic_apps=$(find "$logic_apps_dir" -name "workflow.json" -exec dirname {} \; 2>/dev/null || true)
    
    if [ -z "$logic_apps" ]; then
        echo -e "${YELLOW}No Logic Apps found in $logic_apps_dir${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Starting Logic Apps on port $LOGIC_APPS_PORT...${NC}"
    
    # Logic Apps would require more complex setup with the Logic Apps runtime
    # For now, just indicate where they would run
    echo -e "${YELLOW}Logic Apps runtime setup not implemented in this script${NC}"
    echo -e "${YELLOW}Use Azure Logic Apps extension in VS Code for local development${NC}"
}

# Cleanup function for script exit
cleanup_on_exit() {
    if [ "$CLEANUP_ON_EXIT" = true ]; then
        echo -e "\n${YELLOW}Cleaning up...${NC}"
        
        # Kill function processes
        if [ -f /tmp/func_pids.tmp ]; then
            while read -r pid; do
                kill "$pid" 2>/dev/null || true
            done < /tmp/func_pids.tmp
            rm -f /tmp/func_pids.tmp
        fi
        
        # Cleanup ports
        cleanup_ports "$FUNCTIONS_PORT" "$LOGIC_APPS_PORT"
        
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    fi
}

# Set up signal handlers
trap cleanup_on_exit EXIT INT TERM

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --functions-port)
            FUNCTIONS_PORT="$2"
            shift 2
            ;;
        --logic-apps-port)
            LOGIC_APPS_PORT="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP_ON_EXIT=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --test-distance)
            TEST_DISTANCE_ONLY=true
            shift
            ;;
        --check-deps)
            check_prerequisites
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Set default ports if not specified
FUNCTIONS_PORT=${FUNCTIONS_PORT:-$(find_available_port $DEFAULT_FUNCTIONS_PORT)}
LOGIC_APPS_PORT=${LOGIC_APPS_PORT:-$(find_available_port $DEFAULT_LOGIC_APPS_PORT)}

# Main execution
echo -e "${BLUE}=== Azure Functions & Logic Apps Local Testing ===${NC}"
echo -e "Functions Port: $FUNCTIONS_PORT"
echo -e "Logic Apps Port: $LOGIC_APPS_PORT"
echo ""

# Check prerequisites
check_prerequisites

# Cleanup any existing processes
cleanup_ports "$FUNCTIONS_PORT" "$LOGIC_APPS_PORT"

# Start services
start_functions

if [ "${TEST_DISTANCE_ONLY:-false}" = "true" ]; then
    # Wait a moment for the function to start
    sleep 5
    test_distance_function
    exit $?
fi

start_logic_apps

# Keep the script running
echo -e "\n${GREEN}✓ Services started successfully!${NC}"
echo -e "${BLUE}Press Ctrl+C to stop all services and cleanup${NC}"
echo ""
echo "Function endpoints:"
echo "  Health check: http://localhost:$FUNCTIONS_PORT/api/health"
echo "  Distance API: http://localhost:$FUNCTIONS_PORT/api/distance"
echo ""

# Wait for user interrupt
while true; do
    sleep 1
done
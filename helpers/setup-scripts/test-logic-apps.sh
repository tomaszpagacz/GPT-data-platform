#!/bin/bash

# Function to display usage instructions
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Test Logic Apps workflows"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment to test (dev, sit, prod)"
    echo "  -r, --resource-group  Azure resource group name"
    echo "  -h, --help           Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo "Error: Environment and resource group are required"
    show_usage
    exit 1
fi

# Set default values based on environment
case $ENVIRONMENT in
    dev)
        PREFIX="dev"
        ;;
    sit)
        PREFIX="sit"
        ;;
    prod)
        PREFIX="prod"
        ;;
    *)
        echo "Error: Invalid environment. Must be dev, sit, or prod"
        exit 1
        ;;
esac

echo "Testing Logic Apps in $ENVIRONMENT environment..."

# Get Logic Apps workflow URLs and keys
echo "Retrieving Logic Apps information..."
HELLO_WORLD_URL=$(az logic workflow show --name "${PREFIX}-hello-world" --resource-group "$RESOURCE_GROUP" --query "accessEndpoint" -o tsv)
TRAVEL_ASSISTANT_URL=$(az logic workflow show --name "${PREFIX}-travel-assistant" --resource-group "$RESOURCE_GROUP" --query "accessEndpoint" -o tsv)

if [ -z "$HELLO_WORLD_URL" ] || [ -z "$TRAVEL_ASSISTANT_URL" ]; then
    echo "Error: Could not retrieve Logic Apps URLs"
    exit 1
fi

# Test Hello World Logic App
echo -e "\nTesting Hello World Logic App..."
curl -X POST "$HELLO_WORLD_URL" \
     -H "Content-Type: application/json" \
     -d '{"name": "Test User"}' \
     | jq

# Get the function key for Location Intelligence
FUNC_URL=$(az functionapp show --name "${PREFIX}-location-intelligence" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" -o tsv)
FUNC_KEY=$(az functionapp function keys list --name "${PREFIX}-location-intelligence" --resource-group "$RESOURCE_GROUP" --function-name "CalculateDistance" --query "default" -o tsv)

# Test Travel Assistant Logic App
echo -e "\nTesting Travel Assistant Logic App..."
curl -X POST "$TRAVEL_ASSISTANT_URL" \
     -H "Content-Type: application/json" \
     -d "{
         \"address\": \"350 5th Ave, New York, NY 10118\",
         \"targetLanguage\": \"es\",
         \"sourceLanguage\": \"en\",
         \"currentLocation\": {
             \"latitude\": 40.7484,
             \"longitude\": -73.9857
         },
         \"travelMode\": \"driving\"
     }" \
     | jq

# Function to check run status
check_run_status() {
    local workflow_name=$1
    local run_id=$2
    
    az logic workflow run show \
        --name "$workflow_name" \
        --resource-group "$RESOURCE_GROUP" \
        --run-name "$run_id" \
        --query "status" \
        -o tsv
}

# List recent runs for both Logic Apps
echo -e "\nRecent Hello World runs:"
az logic workflow run list \
    --name "${PREFIX}-hello-world" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{RunId:name, Status:status, StartTime:startTime}" \
    -o table

echo -e "\nRecent Travel Assistant runs:"
az logic workflow run list \
    --name "${PREFIX}-travel-assistant" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{RunId:name, Status:status, StartTime:startTime}" \
    -o table
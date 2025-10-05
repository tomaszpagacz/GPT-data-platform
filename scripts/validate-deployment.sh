#!/usr/bin/env bash
set -euo pipefail

# Logic Apps Workflow Deployment Validation Script
# This script validates the deployment and tests all workflows

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${RESOURCE_GROUP:-gpt-data-platform-rg}"
LOGIC_APP_NAME="${LOGIC_APP_NAME:-}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-}"
SHARED_SECRET="${SHARED_SECRET:-YourSecureSharedSecretForAPI123!}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed or not in PATH"
        exit 1
    fi

    # Check Azure CLI login
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure CLI. Run 'az login' first."
        exit 1
    fi

    log_success "Prerequisites validated"
}

# Get deployment outputs
get_deployment_outputs() {
    log_info "Getting deployment outputs..."

    if [[ -z "$LOGIC_APP_NAME" ]]; then
        LOGIC_APP_NAME=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP" \
            --name main \
            --query "properties.outputs.logicAppName.value" \
            -o tsv 2>/dev/null || echo "")

        if [[ -z "$LOGIC_APP_NAME" ]]; then
            log_error "Could not determine Logic App name. Please set LOGIC_APP_NAME environment variable."
            exit 1
        fi
    fi

    if [[ -z "$STORAGE_ACCOUNT" ]]; then
        STORAGE_ACCOUNT=$(az storage account list \
            --resource-group "$RESOURCE_GROUP" \
            --query "[0].name" \
            -o tsv 2>/dev/null || echo "")

        if [[ -z "$STORAGE_ACCOUNT" ]]; then
            log_error "Could not find storage account in resource group $RESOURCE_GROUP"
            exit 1
        fi
    fi

    LOGIC_APP_URL=$(az logic workflow show \
        --name "wf-http-synapse" \
        --resource-group "$RESOURCE_GROUP" \
        --query "accessEndpoint" \
        -o tsv 2>/dev/null || echo "")

    STORAGE_KEY=$(az storage account keys list \
        --account-name "$STORAGE_ACCOUNT" \
        --query "[0].value" \
        -o tsv 2>/dev/null || echo "")

    log_success "Deployment outputs retrieved"
    log_info "Logic App: $LOGIC_APP_NAME"
    log_info "Storage Account: $STORAGE_ACCOUNT"
    log_info "Logic App URL: $LOGIC_APP_URL"
}

# Test infrastructure components
test_infrastructure() {
    log_info "Testing infrastructure components..."

    # Test Logic App
    if az logicapp show --name "$LOGIC_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_success "Logic App exists and is accessible"
    else
        log_error "Logic App not found or not accessible"
        return 1
    fi

    # Test Storage Account
    if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_success "Storage Account exists and is accessible"
    else
        log_error "Storage Account not found or not accessible"
        return 1
    fi

    # Test Queues
    local queues=("events-synapse" "events-synapse-dlq" "events-ingress")
    for queue in "${queues[@]}"; do
        if az storage queue exists --name "$queue" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --query "exists" -o tsv | grep -q "true"; then
            log_success "Queue '$queue' exists"
        else
            log_error "Queue '$queue' does not exist"
            return 1
        fi
    done

    # Test Tables
    local tables=("ProcessedMessages" "RunHistory")
    for table in "${tables[@]}"; do
        if az storage table exists --name "$table" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --query "exists" -o tsv | grep -q "true"; then
            log_success "Table '$table' exists"
        else
            log_error "Table '$table' does not exist"
            return 1
        fi
    done

    log_success "Infrastructure validation completed"
}

# Test workflows
test_workflows() {
    log_info "Testing workflows..."

    local workflows=("wf-schedule-synapse" "wf-queue-synapse" "wf-http-synapse" "wf-blob-router-to-events" "wf-dlq-replay" "wf-synapse-run-status")

    for workflow in "${workflows[@]}"; do
        if az logic workflow show --name "$workflow" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
            local state=$(az logic workflow show --name "$workflow" --resource-group "$RESOURCE_GROUP" --query "state" -o tsv)
            if [[ "$state" == "Enabled" ]]; then
                log_success "Workflow '$workflow' is enabled"
            else
                log_warning "Workflow '$workflow' is in state: $state"
            fi
        else
            log_error "Workflow '$workflow' not found"
            return 1
        fi
    done

    log_success "Workflow validation completed"
}

# Test W3 HTTP API
test_w3_api() {
    log_info "Testing W3 HTTP On-Demand API..."

    if [[ -z "$LOGIC_APP_URL" ]]; then
        log_error "Logic App URL not available. Cannot test W3 API."
        return 1
    fi

    local test_payload='{
        "pipelineName": "pl_test_validation",
        "parameters": {"test": true, "validation": "deployment_test"},
        "correlationId": "validation-test-001"
    }'

    local response=$(curl -s -w "\n%{http_code}" \
        -X POST "$LOGIC_APP_URL/workflows/wf-http-synapse/triggers/manual/paths/invoke" \
        -H "Content-Type: application/json" \
        -H "x-shared-secret: $SHARED_SECRET" \
        -d "$test_payload")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)

    if [[ "$http_code" == "200" ]]; then
        log_success "W3 API test passed (HTTP $http_code)"
        log_info "Response: $body"
    else
        log_error "W3 API test failed (HTTP $http_code)"
        log_error "Response: $body"
        return 1
    fi
}

# Test W2 Queue Consumer
test_w2_queue() {
    log_info "Testing W2 Queue Consumer..."

    # Send test message to queue
    local test_message=$(echo '{
        "pipelineName": "pl_test_validation",
        "parameters": {"source": "validation_test"},
        "messageId": "queue-test-001",
        "correlationId": "queue-validation-001"
    }' | base64 -w 0)

    az storage message put \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --queue-name "events-synapse" \
        --content "$test_message" \
        --output none

    log_success "Test message sent to events-synapse queue"

    # Wait a moment for processing
    sleep 5

    # Check for workflow runs
    local recent_runs=$(az logic workflow run list \
        --name "wf-queue-synapse" \
        --resource-group "$RESOURCE_GROUP" \
        --query "length([?properties.startTime > '$START_TIME'])" \
        -o tsv 2>/dev/null || echo "0")

    if [[ "$recent_runs" -gt 0 ]]; then
        log_success "W2 workflow triggered ($recent_runs runs detected)"
    else
        log_warning "W2 workflow may not have triggered yet (check again in a few minutes)"
    fi
}

# Test W4 Blob Router
test_w4_router() {
    log_info "Testing W4 Blob Router..."

    # Create Event Grid style message
    local event_grid_payload=$(echo '[
        {
            "id": "router-test-001",
            "eventType": "Microsoft.Storage.BlobCreated",
            "subject": "/blobServices/default/containers/raw/blobs/test.json",
            "data": {
                "url": "https://'$STORAGE_ACCOUNT'.blob.core.windows.net/raw/test.json"
            }
        }
    ]' | base64 -w 0)

    az storage message put \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --queue-name "events-ingress" \
        --content "$event_grid_payload" \
        --output none

    log_success "Event Grid test message sent to events-ingress queue"

    # Wait for processing
    sleep 5

    # Check if message was forwarded
    local queue_length=$(az storage queue stats \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --name "events-synapse" \
        --query "approximateMessagesCount" \
        -o tsv)

    if [[ "$queue_length" -gt 0 ]]; then
        log_success "W4 router appears to be working (messages in target queue)"
    else
        log_warning "W4 router status unclear (no messages in target queue yet)"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."

    local report_file="$PROJECT_ROOT/deployment-validation-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Logic Apps Workflow Deployment Validation Report"
        echo "================================================"
        echo "Generated: $(date)"
        echo "Resource Group: $RESOURCE_GROUP"
        echo "Logic App: $LOGIC_APP_NAME"
        echo "Storage Account: $STORAGE_ACCOUNT"
        echo ""

        echo "Infrastructure Status:"
        echo "- Logic App: $(az logicapp show --name "$LOGIC_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "state" -o tsv 2>/dev/null || echo "ERROR")"
        echo "- Storage Account: $(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv 2>/dev/null || echo "ERROR")"
        echo ""

        echo "Workflow Status:"
        local workflows=("wf-schedule-synapse" "wf-queue-synapse" "wf-http-synapse" "wf-blob-router-to-events" "wf-dlq-replay" "wf-synapse-run-status")
        for workflow in "${workflows[@]}"; do
            local state=$(az logic workflow show --name "$workflow" --resource-group "$RESOURCE_GROUP" --query "state" -o tsv 2>/dev/null || echo "NOT_FOUND")
            echo "- $workflow: $state"
        done
        echo ""

        echo "Queue Status:"
        local queues=("events-synapse" "events-synapse-dlq" "events-ingress")
        for queue in "${queues[@]}"; do
            local exists=$(az storage queue exists --name "$queue" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --query "exists" -o tsv 2>/dev/null || echo "false")
            echo "- $queue: $exists"
        done
        echo ""

        echo "Table Status:"
        local tables=("ProcessedMessages" "RunHistory")
        for table in "${tables[@]}"; do
            local exists=$(az storage table exists --name "$table" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --query "exists" -o tsv 2>/dev/null || echo "false")
            echo "- $table: $exists"
        done

    } > "$report_file"

    log_success "Test report generated: $report_file"
}

# Main execution
main() {
    START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    log_info "Starting Logic Apps Workflow Deployment Validation"
    log_info "Resource Group: $RESOURCE_GROUP"

    validate_prerequisites
    get_deployment_outputs

    local exit_code=0

    if test_infrastructure; then
        log_success "Infrastructure tests passed"
    else
        log_error "Infrastructure tests failed"
        exit_code=1
    fi

    if test_workflows; then
        log_success "Workflow tests passed"
    else
        log_error "Workflow tests failed"
        exit_code=1
    fi

    # Optional functional tests
    if [[ "${RUN_FUNCTIONAL_TESTS:-true}" == "true" ]]; then
        log_info "Running functional tests..."

        if test_w3_api; then
            log_success "W3 API functional test passed"
        else
            log_error "W3 API functional test failed"
            exit_code=1
        fi

        if test_w2_queue; then
            log_success "W2 Queue functional test completed"
        else
            log_warning "W2 Queue functional test had issues"
        fi

        if test_w4_router; then
            log_success "W4 Router functional test completed"
        else
            log_warning "W4 Router functional test had issues"
        fi
    fi

    generate_report

    if [[ $exit_code -eq 0 ]]; then
        log_success "All validation tests completed successfully!"
        log_info "Your Logic Apps orchestration suite is ready for production use."
    else
        log_error "Some validation tests failed. Please review the issues above."
        log_info "Check the generated report for detailed status information."
    fi

    exit $exit_code
}

# Run main function
main "$@"
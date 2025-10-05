# Logic Apps Development Guide

> **Last Updated:** 2025-01-15
> **Audience:** Developer
> **Prerequisites:** Azure CLI, Visual Studio Code, Azure Logic Apps extension, Azurite

## Overview

This comprehensive guide covers developing Azure Logic Apps for the GPT Data Platform using both visual designer and code-first approaches. It includes best practices, deployment strategies, and integration patterns for enterprise workflow automation.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Development Approaches](#development-approaches)
- [Project Structure](#project-structure)
- [Best Practices](#best-practices)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

## Prerequisites

### Required Tools

1. **Development Environment:**
   - [Visual Studio Code](https://code.visualstudio.com/)
   - [Azure Logic Apps Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-logicapps)
   - [Azure Account Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azure-account)
   - [Azurite Storage Emulator](https://github.com/Azure/Azurite)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

2. **VS Code Extensions:**
   ```bash
   code --install-extension ms-azuretools.vscode-logicapps
   code --install-extension ms-azuretools.vscode-azurelogicapps
   code --install-extension ms-vscode.azure-account
   code --install-extension ms-vscode.vscode-json
   ```

## Development Approaches

### 1. Visual Designer (Portal)

1. **Access the Designer**
   - Navigate to Azure Portal
   - Create/Open Logic App
   - Use the visual designer interface

2. **Export/Import**
   - Export workflow as ARM template
   - Store in source control
   - Import using ARM deployment

3. **Best Practices**
   - Use parameters for configuration
   - Document workflow in comments
   - Use consistent naming conventions

### 2. Code-First Development

1. Create a new Logic App project:
   ```bash
   mkdir src/logic-apps/my-workflow
   cd src/logic-apps/my-workflow
   ```

2. Initialize project structure:
   ```
   my-workflow/
   ├── workflow.json
   ├── connections.json
   ├── parameters.json
   └── host.json
   ```

3. Define workflow in `workflow.json`:
   ```json
   {
       "definition": {
           "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
           "actions": {},
           "triggers": {},
           "contentVersion": "1.0.0.0",
           "outputs": {}
       }
   }
   ```

## Local Development and Testing

We provide a comprehensive local testing environment that doesn't require any Azure resources.

### Prerequisites

1. Local development tools:
   - Node.js and npm
   - Azurite (Storage Emulator)
   - Azure Functions Core Tools
   - jq (for JSON processing)

2. Install dependencies:
   ```bash
   ./helpers/setup-scripts/install-dependencies.sh
   ```

### Running Local Tests

1. Start the local test environment:
   ```bash
   ./helpers/setup-scripts/test-logic-apps-local.sh
   ```

This script will:
- Start Azurite storage emulator
- Create local settings files
- Start Location Intelligence Function locally
- Start both Logic Apps locally
- Run test cases against local endpoints

### Local Endpoints

When running locally, the services are available at:
- Hello World Logic App: http://localhost:8081
- Travel Assistant Logic App: http://localhost:8082
- Location Intelligence Function: http://localhost:7071

### Manual Local Testing

Test Hello World:
```bash
curl -X POST "http://localhost:8081/api/workflow-trigger" \
     -H "Content-Type: application/json" \
     -d '{"name": "Local Test User"}'
```

Test Travel Assistant:
```bash
curl -X POST "http://localhost:8082/api/workflow-trigger" \
     -H "Content-Type: application/json" \
     -d '{
         "address": "350 5th Ave, New York, NY 10118",
         "targetLanguage": "es",
         "sourceLanguage": "en",
         "currentLocation": {
             "latitude": 40.7484,
             "longitude": -73.9857
         },
         "travelMode": "driving"
     }'
```

### Local Settings

Each Logic App has its own `local.settings.json`:

Hello World:
```json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "WORKFLOWS_SUBSCRIPTION_ID": "00000000-0000-0000-0000-000000000000",
        "WORKFLOWS_RESOURCE_GROUP_NAME": "local-dev",
        "WORKFLOWS_LOCATION_NAME": "local"
    }
}
```

Travel Assistant:
```json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "WORKFLOWS_SUBSCRIPTION_ID": "00000000-0000-0000-0000-000000000000",
        "WORKFLOWS_RESOURCE_GROUP_NAME": "local-dev",
        "WORKFLOWS_LOCATION_NAME": "local",
        "LocationIntelligenceFunctionUrl": "http://localhost:7071",
        "LocationIntelligenceFunctionKey": "local-dev-key"
    }
}
```

## Project Structure

```
src/logic-apps/
├── my-workflow/
│   ├── workflow.json     # Main workflow definition
│   ├── connections.json  # API connections
│   ├── parameters.json   # Parameter values
│   └── host.json        # Runtime configuration
└── shared/
    └── connections/      # Shared API connections
```

## Best Practices

1. **Source Control**
   - Store workflow definitions in source control
   - Use parameters for environment-specific values
   - Include documentation with each workflow

## Testing

### Using the Test Script

We provide a test script to validate Logic Apps functionality across environments:

```bash
./helpers/setup-scripts/test-logic-apps.sh -e <environment> -r <resource-group>
```

Options:
- `-e, --environment`: Target environment (dev, sit, prod)
- `-r, --resource-group`: Azure resource group name
- `-h, --help`: Show help message

Example:
```bash
./helpers/setup-scripts/test-logic-apps.sh -e dev -r my-resource-group
```

### Available Test Cases

1. **Hello World Logic App**
   ```json
   {
       "name": "Test User"
   }
   ```
   Expected response:
   ```json
   {
       "message": "Hello, Test User!",
       "timestamp": "2025-10-04T10:00:00.000Z"
   }
   ```

2. **Travel Assistant Logic App**
   ```json
   {
       "address": "350 5th Ave, New York, NY 10118",
       "targetLanguage": "es",
       "sourceLanguage": "en",
       "currentLocation": {
           "latitude": 40.7484,
           "longitude": -73.9857
       },
       "travelMode": "driving"
   }
   ```
   Expected response:
   ```json
   {
       "destination": {
           "originalAddress": "350 5th Ave, New York, NY 10118",
           "translatedAddress": "350 5ta Avenida, Nueva York, NY 10118",
           "location": {
               "latitude": 40.7484,
               "longitude": -73.9857
           },
           "additionalInfo": {
               "pointOfInterest": "Empire State Building",
               "neighborhood": "Midtown"
           }
       },
       "route": {
           "summary": {
               "distance": "0.5 km",
               "duration": "10 minutos"
           },
           "instructions": [
               "Diríjase al norte por la 5ta Avenida",
               "Gire a la derecha en la Calle 34",
               "Ha llegado a su destino"
           ]
       }
   }
   ```

### Manual Testing

You can also test Logic Apps manually using curl:

```bash
# Get Logic App URL
LOGIC_APP_URL=$(az logic workflow show --name "my-workflow" --resource-group "my-rg" --query "accessEndpoint" -o tsv)

# Test endpoint
curl -X POST "$LOGIC_APP_URL" \
     -H "Content-Type: application/json" \
     -d '{...}'
```

### Monitoring Test Results

View run history:
```bash
# List recent runs
az logic workflow run list \
    --name <workflow-name> \
    --resource-group <resource-group> \
    --query "[].{RunId:name, Status:status, StartTime:startTime}" \
    -o table

# Get details of a specific run
az logic workflow run show \
    --name <workflow-name> \
    --resource-group <resource-group> \
    --run-name <run-id>
```

### Troubleshooting Tests

Common issues and solutions:

1. **Authentication Errors**
   - Check Azure CLI login status
   - Verify resource permissions
   - Validate function keys

2. **404 Not Found**
   - Verify Logic App URLs
   - Check if Logic Apps are running
   - Verify API versions

3. **500 Internal Server Error**
   - Check run history for details
   - Verify dependent services
   - Review application logs

4. **Invalid Parameters**
   - Validate JSON payload schema
   - Check coordinate formats
   - Verify language codes

2. **Error Handling**
   ```json
   {
       "actions": {
           "Scope": {
               "type": "Scope",
               "actions": {},
               "runAfter": {},
               "catch": [
                   {
                       "if": {
                           "equals": ["@result('Scope')", "Failed"]
                       },
                       "actions": {
                           "Handle_Error": {}
                       }
                   }
               ]
           }
       }
   }
   ```

3. **Parameters**
   - Use parameters for:
     - Connection strings
     - URLs
     - Environment-specific values
   - Store sensitive values in Key Vault

4. **Monitoring**
   - Enable diagnostic logs
   - Set up alerts
   - Use correlation IDs

## Common Patterns

1. **HTTP Webhook Pattern**
   ```json
   {
       "triggers": {
           "manual": {
               "type": "Request",
               "kind": "Http",
               "inputs": {
                   "schema": {
                       "type": "object",
                       "properties": {
                           "name": {
                               "type": "string"
                           }
                       }
                   }
               }
           }
       }
   }
   ```

2. **Service Bus Integration**
   ```json
   {
       "triggers": {
           "serviceBusTrigger": {
               "type": "serviceBus",
               "inputs": {
                   "topicName": "mytopic",
                   "subscriptionName": "mysub"
               }
           }
       }
   }
   ```

## Deployment

1. Using Azure CLI:
   ```bash
   az logicapp deployment create \
     --resource-group <resource-group> \
     --name <logic-app-name> \
     --template-file template.json \
     --parameters parameters.json
   ```

2. Using ARM Templates:
   ```bash
   az deployment group create \
     --resource-group <resource-group> \
     --template-file template.json \
     --parameters parameters.json
   ```

## Testing

1. **Local Testing**
   - Use Postman for HTTP triggers
   - Set up local environment variables
   - Test with sample payloads

2. **Integration Testing**
   - Create test environments
   - Use mock services
   - Validate workflow outputs

## Security

1. **Authentication**
   - Use Managed Identity
   - Store secrets in Key Vault
   - Implement RBAC properly

2. **Network Security**
   - Use Private Endpoints
   - Configure firewalls
   - Restrict IP ranges

## Sample Code

Check our Hello World example in `src/logic-apps/hello-world/` for a working implementation following these best practices.

## Workflow Orchestration Suite

This platform includes a comprehensive set of 6 Logic App workflows that provide complete data pipeline orchestration capabilities. These workflows work together to create a robust, event-driven data processing platform.

### Workflow Overview

| Workflow | Purpose | Trigger | Key Features |
|----------|---------|---------|--------------|
| **W1 - Scheduled Synapse** | Daily batch processing | Recurrence (4:00 AM) | Distributed locking, jitter |
| **W2 - Queue Consumer** | Event-driven processing | Queue messages | Deduplication, run tracking |
| **W3 - HTTP On-Demand** | API-triggered execution | HTTP POST | Shared-secret auth, schema validation |
| **W4 - Blob Router** | Event Grid normalization | Queue messages | EG payload mapping, canonical format |
| **W5 - DLQ Replay** | Error recovery | HTTP POST | Retry logic, poison queues |
| **W6 - Status Poller** | Completion monitoring | HTTP POST | Polling, webhook notifications |

### W1: Scheduled Synapse Pipeline (`wf-schedule-synapse.workflow.json`)

**Purpose:** Executes Synapse pipelines on a scheduled basis with distributed locking to prevent duplicate runs.

**Trigger:** Daily at 4:00 AM with configurable jitter (0-30 seconds).

**Configuration:**
```json
{
  "pipelineName": "pl_ingest_daily",
  "pipelineParameters": {
    "RunDate": "@utcNow('yyyy-MM-dd')"
  },
  "lockBlobUrl": "@appsetting('SCHEDULE_LOCK_BLOB_URL')",
  "maxSkewSeconds": 30
}
```

**Required App Settings:**
- `SCHEDULE_LOCK_BLOB_URL`: SAS URL to blob for distributed locking
- `SYNAPSE_WORKSPACE`: Target Synapse workspace name

**Usage:** Automatically runs daily. No manual intervention required.

---

### W2: Queue Consumer (`wf-queue-synapse.workflow.json`)

**Purpose:** Processes events from Azure Queue Storage, executes Synapse pipelines, and tracks run history with deduplication.

**Trigger:** Azure Queues API connection polling `EVENT_QUEUE_NAME`.

**Message Format:**
```json
{
  "pipelineName": "pl_ingest_raw",
  "parameters": {
    "Path": "https://storage.blob.core.windows.net/raw/file.json",
    "pathPrefix": "/blobServices/default/containers/raw/blobs/file.json"
  },
  "messageId": "unique-message-identifier",
  "correlationId": "optional-tracking-id"
}
```

**Required App Settings:**
- `EVENT_QUEUE_NAME`: Source queue (default: "events-synapse")
- `TABLE_DEDUPE`: Deduplication table (default: "ProcessedMessages")
- `TABLE_RUNS`: Run tracking table (default: "RunHistory")

**Features:**
- Message deduplication using Azure Tables
- Pipeline run tracking with correlation IDs
- Automatic retry with exponential backoff
- Safe property access with coalesce functions

---

### W3: HTTP On-Demand API (`wf-http-synapse.workflow.json`)

**Purpose:** Provides secure HTTP API for on-demand Synapse pipeline execution with shared-secret authentication.

**API Endpoint:**
```http
POST /workflows/wf-http-synapse/triggers/manual/paths/invoke
Headers: x-shared-secret: <your-shared-secret>
Content-Type: application/json

{
  "pipelineName": "pl_your_pipeline",
  "parameters": { "param1": "value1" },
  "correlationId": "optional-tracking-id"
}
```

**Response:**
```json
{
  "pipelineName": "pl_your_pipeline",
  "runId": "pipeline-run-id",
  "correlationId": "tracking-id",
  "status": "Pipeline execution started",
  "timestamp": "2025-10-05T10:30:00Z"
}
```

**Required App Settings:**
- `ONDEMAND_SHARED_SECRET`: Shared secret for authentication

**Security:** Validates shared secret in request headers. Returns 401 for unauthorized requests.

---

### W4: Blob Router (`wf-blob-router-to-events.workflow.json`)

**Purpose:** Normalizes Event Grid BlobCreated events and forwards them to the main processing queue.

**Trigger:** Azure Queues API connection polling `INGRESS_QUEUE_NAME`.

**Event Grid → Canonical Mapping:**
```json
// Input: Event Grid BlobCreated event
{
  "id": "event-id",
  "eventType": "Microsoft.Storage.BlobCreated",
  "subject": "/blobServices/default/containers/raw/blobs/file.json",
  "data": {
    "url": "https://storage.blob.core.windows.net/raw/file.json"
  }
}

// Output: Canonical message format
{
  "pipelineName": "pl_ingest_raw",
  "parameters": {
    "Path": "https://storage.blob.core.windows.net/raw/file.json",
    "pathPrefix": "/blobServices/default/containers/raw/blobs/file.json",
    "EventType": "Microsoft.Storage.BlobCreated"
  },
  "messageId": "event-id"
}
```

**Required App Settings:**
- `INGRESS_QUEUE_NAME`: Event Grid destination queue
- `EVENT_QUEUE_NAME`: Main processing queue

**Usage:** Automatically processes Event Grid events. No manual intervention required.

---

### W5: DLQ Replay (`wf-dlq-replay.workflow.json`)

**Purpose:** Recovers failed messages from dead-letter queues with configurable retry logic and poison queue handling.

**API Endpoint:**
```http
POST /workflows/wf-dlq-replay/triggers/manual/paths/invoke
```

**Configuration Parameters:**
```json
{
  "mode": "requeue", // "requeue" or "direct"
  "maxMessages": 50,
  "maxRetries": 5,
  "eventQueue": "@appsetting('EVENT_QUEUE_NAME')",
  "dlqName": "@appsetting('DLQ_NAME')",
  "poisonQueue": "@coalesce(appsetting('POISON_QUEUE_NAME'),'events-synapse-poison')"
}
```

**Processing Logic:**
1. Pull messages from DLQ with visibility timeout
2. Check retry count against maxRetries
3. Route to poison queue if exceeded
4. Increment retry count and reprocess
5. Delete from DLQ after processing

**Required App Settings:**
- `DLQ_NAME`: Dead-letter queue (default: "events-synapse-dlq")
- `EVENT_QUEUE_NAME`: Main processing queue
- `POISON_QUEUE_NAME`: Poison queue (optional, defaults to "events-synapse-poison")

---

### W6: Status Poller (`wf-synapse-run-status.workflow.json`)

**Purpose:** Monitors Synapse pipeline runs until completion and notifies webhooks with final status.

**API Endpoint:**
```http
POST /workflows/wf-synapse-run-status/triggers/request/paths/invoke
Content-Type: application/json

{
  "runId": "your-pipeline-run-id"
}
```

**Response:**
```json
{
  "status": "Succeeded"
}
```

**Webhook Notification:**
```http
POST <STATUS_WEBHOOK_URL>
Content-Type: application/json

{
  "runId": "pipeline-run-id",
  "status": "Succeeded|Failed|Cancelled",
  "timestamp": "2025-10-05T10:30:00Z"
}
```

**Configuration:**
```json
{
  "pollSeconds": 15,    // Polling interval
  "maxMinutes": 120     // Maximum polling time
}
```

**Required App Settings:**
- `STATUS_WEBHOOK_URL`: Webhook endpoint for notifications

**Features:**
- Bounded polling with timeout protection
- Terminal state detection (Succeeded/Failed/Cancelled)
- Asynchronous webhook notifications
- Synchronous API response

## Workflow Configuration

### Required App Settings

All workflows require these base settings:

```json
{
  "WORKFLOWS_SUBSCRIPTION_ID": "your-subscription-id",
  "WORKFLOWS_RESOURCE_GROUP_NAME": "your-resource-group",
  "SYNAPSE_WORKSPACE": "your-synapse-workspace"
}
```

### Queue Configuration

```json
{
  "EVENT_QUEUE_NAME": "events-synapse",
  "DLQ_NAME": "events-synapse-dlq",
  "INGRESS_QUEUE_NAME": "events-ingress",
  "POISON_QUEUE_NAME": "events-synapse-poison"
}
```

### Table Configuration

```json
{
  "TABLE_DEDUPE": "ProcessedMessages",
  "TABLE_RUNS": "RunHistory"
}
```

### Security Settings

```json
{
  "ONDEMAND_SHARED_SECRET": "your-secure-shared-secret",
  "SCHEDULE_LOCK_BLOB_URL": "https://storage.blob.core.windows.net/locks/schedule.lock?sv=...",
  "STATUS_WEBHOOK_URL": "https://your-webhook-endpoint.com/notify"
}
```

## Deployment and Testing

### Deploying Workflows

Use the provided deployment script:

```bash
# Deploy all workflows
./scripts/logicapps/deploy-workflows.sh

# Deploy specific workflow
az logicapp deployment source config-zip \
  --name "your-logic-app" \
  --resource-group "your-rg" \
  --subscription "your-sub" \
  --src "src/logic-apps/workflows/wf-queue-synapse.workflow.json"
```

### Testing Workflows

1. **W1 Scheduled:** Monitor Synapse pipeline runs at 4:00 AM daily
2. **W2 Queue Consumer:** Send test messages to `EVENT_QUEUE_NAME`
3. **W3 HTTP API:** Use curl with shared secret header
4. **W4 Blob Router:** Send Event Grid events to `INGRESS_QUEUE_NAME`
5. **W5 DLQ Replay:** Trigger manually when DLQ has messages
6. **W6 Status Poller:** Provide runId from any pipeline execution

### Monitoring

```bash
# Check workflow runs
az logic workflow run list \
  --name "wf-queue-synapse" \
  --resource-group "your-rg" \
  --query "[].{RunId:name, Status:status, StartTime:startTime}" \
  -o table

# Get run details
az logic workflow run show \
  --name "wf-queue-synapse" \
  --resource-group "your-rg" \
  --run-name "run-id"
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify Managed Service Identity is enabled
   - Check Synapse workspace permissions
   - Validate shared secrets

2. **Queue Connection Issues**
   - Confirm Azure Queues connection is configured
   - Verify queue names exist
   - Check connection permissions

3. **Pipeline Execution Errors**
   - Validate pipeline names exist in Synapse
   - Check parameter schemas
   - Review Synapse activity logs

4. **Webhook Failures**
   - Verify webhook URL is accessible
   - Check webhook authentication requirements
   - Monitor webhook response codes

### Debug Mode

Enable verbose logging by setting:

```json
{
  "WorkflowRuntime.LogLevel": "Verbose"
}
```

## Integration Examples

### Complete Data Flow

1. **Blob Upload** → Event Grid → W4 → Queue Message
2. **W2 Consumer** → Deduplication → Synapse Pipeline
3. **W6 Poller** → Status Monitoring → Webhook Notification
4. **Failed Messages** → DLQ → W5 Replay → Recovery

### External Orchestrator Integration

```bash
# Trigger on-demand pipeline
curl -X POST "https://logic-app-url/workflows/wf-http-synapse/triggers/manual/paths/invoke" \
  -H "x-shared-secret: your-secret" \
  -H "Content-Type: application/json" \
  -d '{"pipelineName": "pl_custom_pipeline", "parameters": {"env": "prod"}}'

# Monitor completion
curl -X POST "https://logic-app-url/workflows/wf-synapse-run-status/triggers/request/paths/invoke" \
  -H "Content-Type: application/json" \
  -d '{"runId": "returned-run-id"}'
```

This orchestration suite provides enterprise-grade data pipeline automation with comprehensive error handling, monitoring, and recovery capabilities.

## Related Documentation

- [Platform Architecture](architecture.md) - Understanding the overall system design
- [Azure Functions Development](functions-development.md) - Function development best practices
- [Eventing Infrastructure](eventing-infrastructure.md) - Event processing setup
- [Deployment Troubleshooting](deployment-troubleshooting.md) - Common deployment issues
- [RBAC Implementation](rbac-implementation-guide.md) - Access control setup

## Next Steps

After completing Logic Apps development:

1. Review [Eventing Infrastructure](eventing-infrastructure.md) for event-driven integration
2. Configure [API Management](api-management-deployment.md) for workflow APIs
3. Set up monitoring and alerting as described in operational documentation
4. Follow deployment procedures in the main README

## Additional Resources

- [Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Logic Apps GitHub Samples](https://github.com/Azure/logicapps)
- [Workflow Definition Language Schema](https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json)
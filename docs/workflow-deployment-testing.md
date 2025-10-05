# Logic Apps Workflow Deployment and Testing Guide

This guide provides comprehensive instructions for deploying and testing the 6-workflow orchestration suite for the GPT Data Platform.

## Prerequisites

### Required Tools
- Azure CLI (`az`) - authenticated and configured
- Azure Bicep CLI (`az bicep`)
- jq (for JSON processing)
- curl (for API testing)

### Required Permissions
- Contributor role on target subscription/resource group
- Logic Apps Standard contributor
- Synapse workspace contributor
- Storage Account contributor

## Parameter Configuration

### Core Infrastructure Parameters

Create a `parameters.json` file for your deployment:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "namePrefix": {
      "value": "gptdata"
    },
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "switzerlandnorth"
    },
    "synapseSqlAdminLogin": {
      "value": "sqladmin"
    },
    "synapseSqlAdminPassword": {
      "value": "YourSecurePassword123!"
    },
    "onDemandSharedSecret": {
      "value": "YourSecureSharedSecretForAPI123!"
    },
    "deployLogicApps": {
      "value": true
    },
    "deploySynapse": {
      "value": true
    },
    "deployStorage": {
      "value": true
    }
  }
}
```

### Environment-Specific Configurations

#### Development Environment
```json
{
  "namePrefix": "gptdatadev",
  "environment": "dev",
  "location": "switzerlandnorth",
  "allowedPublicIpRanges": ["YOUR_PUBLIC_IP/32"]
}
```

#### Production Environment
```json
{
  "namePrefix": "gptdata",
  "environment": "prod",
  "location": "switzerlandnorth",
  "allowedPublicIpRanges": []
}
```

## Infrastructure Deployment

### 1. Deploy Core Infrastructure

```bash
# Set variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="gpt-data-platform-rg"
LOCATION="switzerlandnorth"
TEMPLATE_FILE="infra/main.bicep"
PARAMETERS_FILE="parameters.json"

# Deploy infrastructure
az deployment group create \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "$PARAMETERS_FILE" \
  --mode Incremental
```

### 2. Verify Infrastructure Deployment

```bash
# Check Logic App creation
az logicapp list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, State:state}" -o table

# Check Storage Account
az storage account list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Kind:kind}" -o table

# Check Synapse Workspace
az synapse workspace list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, State:connectivityEndpoints}" -o table
```

### 3. Deploy Workflows

```bash
# Get Logic App name from deployment output
LOGIC_APP_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name main \
  --query "properties.outputs.logicAppName.value" \
  -o tsv)

# Deploy workflows
./scripts/logicapps/deploy-workflows.sh "$LOGIC_APP_NAME"
```

## Required Configuration Files

### Pipelines Configuration

Create the pipelines configuration file in your storage account:

```bash
# Upload pipelines config to storage
az storage blob upload \
  --account-name "YOUR_STORAGE_ACCOUNT" \
  --container-name "config" \
  --name "pipelines.dev.json" \
  --file "config/pipelines.dev.json"
```

Example `pipelines.dev.json`:
```json
{
  "routes": {
    "blob:raw": "pl_ingest_raw",
    "blob:processed": "pl_process_data"
  },
  "defaultPipeline": "pl_ingest_raw"
}
```

### Queue and Table Setup

The infrastructure deployment automatically creates:
- `events-synapse` (main processing queue)
- `events-synapse-dlq` (dead-letter queue)
- `events-ingress` (Event Grid destination queue)
- `ProcessedMessages` (deduplication table)
- `RunHistory` (run tracking table)

## Workflow Testing

### Test Data Setup

Create test queues and send sample messages:

```bash
# Get storage account name and key
STORAGE_ACCOUNT=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
STORAGE_KEY=$(az storage account keys list --account-name "$STORAGE_ACCOUNT" --query "[0].value" -o tsv)

# Send test message to main queue
az storage message put \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-synapse" \
  --content "eyJwaXBlbGluZU5hbWUiOiJwbF9pbmdlc3RfcmF3IiwicGFyYW1ldGVycyI6eyJQYXRoIjoiaHR0cHM6Ly9zdG9yYWdlLmJsb2IuY29yZS53aW5kb3dzLm5ldC9yYXcvZmlsZS5qc29uIn0sIm1lc3NhZ2VJZCI6InRlc3QtMTIzIn0="

# Send test message to ingress queue (Event Grid format)
az storage message put \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-ingress" \
  --content "W3siZGF0YSI6eyJ1cmwiOiJodHRwczovL3N0b3JhZ2UuYmxvYi5jb3JlLndpbmRvd3MubmV0L3Jhdy90ZXN0L2ZpbGUuanNvbiJ9LCJldmVudFR5cGUiOiJNaWNyb3NvZnQuU3RvcmFnZS5CbG9iQ3JlYXRlZCIsInN1YmplY3QiOiIvYmxvYlNlcnZpY2VzL2RlZmF1bHQvY29udGFpbmVycy9yYXcvYmxvYnMvdGVzdC9maWxlLmpzb24iLCJpZCI6InRlc3QtZXZlbnQtMTIzIn1d"
```

### Individual Workflow Testing

#### W1: Scheduled Synapse Pipeline

```bash
# Check if workflow is enabled
az logic workflow show \
  --name "wf-schedule-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --query "state"

# Manually trigger (for testing)
az logic workflow trigger create \
  --name "wf-schedule-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --trigger-name "daily_0400"
```

#### W2: Queue Consumer

```bash
# Monitor workflow runs
az logic workflow run list \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{RunId:name, Status:status, StartTime:startTime}" \
  -o table

# Check queue message count
az storage queue stats \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --name "events-synapse" \
  --query "approximateMessagesCount"
```

#### W3: HTTP On-Demand API

```bash
# Get Logic App URL
LOGIC_APP_URL=$(az logic workflow show \
  --name "wf-http-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --query "accessEndpoint" \
  -o tsv)

# Test API with shared secret
curl -X POST "$LOGIC_APP_URL/workflows/wf-http-synapse/triggers/manual/paths/invoke" \
  -H "Content-Type: application/json" \
  -H "x-shared-secret: YourSecureSharedSecretForAPI123!" \
  -d '{
    "pipelineName": "pl_ingest_raw",
    "parameters": {"test": true},
    "correlationId": "test-run-001"
  }'
```

#### W4: Blob Router

```bash
# Send Event Grid message to ingress queue
az storage message put \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-ingress" \
  --content "BASE64_ENCODED_EVENT_GRID_PAYLOAD"

# Monitor workflow runs
az logic workflow run list \
  --name "wf-blob-router-to-events" \
  --resource-group "$RESOURCE_GROUP"
```

#### W5: DLQ Replay

```bash
# Trigger DLQ replay
curl -X POST "$LOGIC_APP_URL/workflows/wf-dlq-replay/triggers/manual/paths/invoke" \
  -H "Content-Type: application/json"

# Check poison queue for failed messages
az storage message peek \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-synapse-poison" \
  --num-messages 10
```

#### W6: Status Poller

```bash
# Monitor pipeline completion (replace RUN_ID with actual run ID)
curl -X POST "$LOGIC_APP_URL/workflows/wf-synapse-run-status/triggers/request/paths/invoke" \
  -H "Content-Type: application/json" \
  -d '{"runId": "YOUR_PIPELINE_RUN_ID"}'
```

## Monitoring and Troubleshooting

### Enable Diagnostic Logs

```bash
# Enable Logic App diagnostics
az monitor diagnostic-settings create \
  --name "logic-app-diagnostics" \
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$LOGIC_APP_NAME" \
  --logs '[{"category": "WorkflowRuntime", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]' \
  --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/YOUR_LOG_WORKSPACE"
```

### Common Issues and Solutions

#### 1. Workflow Deployment Failures

**Issue:** Workflows fail to deploy
```bash
# Check deployment status
az logicapp deployment list-publishing-profiles \
  --name "$LOGIC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP"
```

**Solution:** Ensure workflows are in the correct directory structure and Logic App has proper permissions.

#### 2. Authentication Errors

**Issue:** MSI authentication fails
```bash
# Check managed identity
az logicapp identity show \
  --name "$LOGIC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP"
```

**Solution:** Ensure Logic App has Contributor role on Synapse workspace and Storage account.

#### 3. Queue Connection Issues

**Issue:** Queue triggers not firing
```bash
# Test connection
az logicapp connection list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='azurequeues']"
```

**Solution:** Recreate Azure Queues connection in Logic App.

#### 4. Pipeline Execution Errors

**Issue:** Synapse pipelines fail
```bash
# Check Synapse pipeline runs
az synapse pipeline-run list \
  --workspace-name "YOUR_SYNAPSE_WORKSPACE" \
  --resource-group "$RESOURCE_GROUP"
```

**Solution:** Verify pipeline names and parameters in configuration.

### Performance Monitoring

```bash
# Monitor workflow performance
az monitor metrics list \
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$LOGIC_APP_NAME" \
  --metric "RunsCompleted" \
  --aggregation "Count" \
  --interval "PT1H"
```

### Log Analysis

```bash
# Get workflow run logs
az logic workflow run action list \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --run-name "RUN_ID" \
  --query "[].{Action:displayName, Status:status, StartTime:startTime, EndTime:endTime}"
```

## Automated Testing

### Create Test Suite

```bash
#!/bin/bash
# test-workflows.sh

LOGIC_APP_URL=$(az logic workflow show --name "wf-http-synapse" --resource-group "$RESOURCE_GROUP" --query "accessEndpoint" -o tsv)
SHARED_SECRET="YourSecureSharedSecretForAPI123!"

echo "Testing W3 HTTP On-Demand API..."
response=$(curl -s -X POST "$LOGIC_APP_URL/workflows/wf-http-synapse/triggers/manual/paths/invoke" \
  -H "Content-Type: application/json" \
  -H "x-shared-secret: $SHARED_SECRET" \
  -d '{"pipelineName": "pl_test", "correlationId": "test-001"}')

if [[ $response == *"Pipeline execution started"* ]]; then
  echo "✅ W3 API test passed"
else
  echo "❌ W3 API test failed: $response"
fi

echo "Testing W6 Status Poller..."
# Add more tests...
```

### CI/CD Integration

Add to your pipeline:

```yaml
- task: AzureCLI@2
  displayName: 'Test Logic Apps Workflows'
  inputs:
    azureSubscription: 'your-service-connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      ./test-workflows.sh
```

## Security Validation

### Shared Secret Rotation

```bash
# Update shared secret
NEW_SECRET="NewSecureSecret456!"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "infra/main.bicep" \
  --parameters onDemandSharedSecret="$NEW_SECRET" \
  --mode Incremental

# Update dependent systems
echo "Update webhook endpoints and API clients with new secret: $NEW_SECRET"
```

### Access Control Validation

```bash
# Check Logic App permissions
az role assignment list \
  --assignee "$(az logicapp identity show --name "$LOGIC_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "principalId" -o tsv)" \
  --query "[].{Role:roleDefinitionName, Scope:scope}"
```

## Backup and Recovery

### Workflow Backup

```bash
# Export workflows
az logic workflow export \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --output-directory "./backup"
```

### Disaster Recovery

```bash
# Redeploy from backup
az logicapp deployment source config-zip \
  --name "$LOGIC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --src "./backup/workflows.zip"
```

This comprehensive guide ensures successful deployment and operation of your Logic Apps orchestration suite. Regular testing and monitoring will help maintain system reliability and performance.
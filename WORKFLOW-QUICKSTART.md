# Logic Apps Workflow Suite - Quick Start Guide

## 🎯 Overview

Your comprehensive Logic Apps orchestration suite is now complete with 6 workflows providing enterprise-grade data pipeline automation. This guide gets you from zero to production in minutes.

## 📋 Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Contributor permissions on target subscription/resource group
- Basic knowledge of Azure resource deployment

## 🚀 Quick Deployment

### 1. Configure Parameters

```bash
cd infra
cp parameters.sample.json parameters.json
# Edit parameters.json with your values
```

**Required parameters to customize:**
- `namePrefix`: 3-11 character prefix (e.g., "gptdata")
- `environment`: Environment suffix (e.g., "dev", "prod")
- `synapseSqlAdminLogin`: SQL admin username
- `synapseSqlAdminPassword`: Secure SQL password
- `onDemandSharedSecret`: API authentication secret

### 2. Deploy Infrastructure

```bash
# Set your subscription
export SUBSCRIPTION_ID="your-subscription-id"
export RESOURCE_GROUP="gpt-data-platform-rg"
export LOCATION="switzerlandnorth"

# Deploy everything
az deployment group create \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --template-file main.bicep \
  --parameters @parameters.json
```

### 3. Deploy Workflows

```bash
# Get Logic App name from deployment
LOGIC_APP_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name main \
  --query "properties.outputs.logicAppName.value" -o tsv)

# Deploy all workflows
./scripts/logicapps/deploy-workflows.sh "$LOGIC_APP_NAME"
```

### 4. Upload Configuration

Create and upload the pipelines configuration:

```bash
# Create config file
cat > pipelines.dev.json << 'EOF'
{
  "routes": {
    "blob:raw": "pl_ingest_raw",
    "blob:processed": "pl_process_data"
  },
  "defaultPipeline": "pl_ingest_raw"
}
EOF

# Upload to storage
STORAGE_ACCOUNT=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "config" \
  --name "pipelines.dev.json" \
  --file "pipelines.dev.json"
```

### 5. Validate Deployment

```bash
# Run comprehensive validation
export RESOURCE_GROUP="gpt-data-platform-rg"
export SHARED_SECRET="YourSecureSharedSecretForAPI123!"  # From parameters.json

./scripts/validate-deployment.sh
```

## 🧪 Testing Your Workflows

### W1: Scheduled Pipeline (Automatic)
- Runs daily at 4:00 AM
- Check Synapse pipeline runs for execution

### W2: Queue Consumer
```bash
# Send test message
STORAGE_ACCOUNT=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
STORAGE_KEY=$(az storage account keys list --account-name "$STORAGE_ACCOUNT" --query "[0].value" -o tsv)

echo '{"pipelineName":"pl_ingest_raw","parameters":{"test":true},"messageId":"test-001"}' | \
base64 -w 0 | \
xargs -I {} az storage message put \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-synapse" \
  --content "{}"
```

### W3: HTTP On-Demand API
```bash
# Get Logic App URL
LOGIC_APP_URL=$(az logic workflow show \
  --name "wf-http-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --query "accessEndpoint" -o tsv)

# Test API
curl -X POST "$LOGIC_APP_URL/workflows/wf-http-synapse/triggers/manual/paths/invoke" \
  -H "x-shared-secret: YourSecureSharedSecretForAPI123!" \
  -H "Content-Type: application/json" \
  -d '{"pipelineName": "pl_ingest_raw", "correlationId": "api-test-001"}'
```

### W4: Blob Router
```bash
# Send Event Grid style message
echo '[{"data":{"url":"https://storage.blob.core.windows.net/raw/test.json"},"eventType":"Microsoft.Storage.BlobCreated","subject":"/blobServices/default/containers/raw/blobs/test.json","id":"eg-test-001"}]' | \
base64 -w 0 | \
xargs -I {} az storage message put \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --queue-name "events-ingress" \
  --content "{}"
```

### W5: DLQ Replay
```bash
# Trigger DLQ processing
curl -X POST "$LOGIC_APP_URL/workflows/wf-dlq-replay/triggers/manual/paths/invoke"
```

### W6: Status Poller
```bash
# Monitor pipeline completion (replace RUN_ID)
curl -X POST "$LOGIC_APP_URL/workflows/wf-synapse-run-status/triggers/request/paths/invoke" \
  -H "Content-Type: application/json" \
  -d '{"runId": "your-pipeline-run-id"}'
```

## 📊 Monitoring

### Check Workflow Health
```bash
# List recent runs
az logic workflow run list \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Status:status, Start:startTime}" \
  -o table
```

### Monitor Queues
```bash
# Check queue depths
az storage queue stats \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --name "events-synapse" \
  --query "approximateMessagesCount"
```

## 🔧 Configuration Reference

### App Settings (Auto-configured)
- `WORKFLOWS_SUBSCRIPTION_ID`: Azure subscription
- `WORKFLOWS_RESOURCE_GROUP_NAME`: Resource group
- `SYNAPSE_WORKSPACE`: Synapse workspace name
- `EVENT_QUEUE_NAME`: Main processing queue
- `DLQ_NAME`: Dead-letter queue
- `INGRESS_QUEUE_NAME`: Event Grid destination
- `ONDEMAND_SHARED_SECRET`: API authentication
- `STATUS_WEBHOOK_URL`: Completion webhook (optional)

### Environment Variables for Testing
```bash
export SUBSCRIPTION_ID="your-subscription-id"
export RESOURCE_GROUP="gpt-data-platform-rg"
export LOGIC_APP_NAME="your-logic-app-name"
export STORAGE_ACCOUNT="your-storage-account"
export SHARED_SECRET="your-shared-secret"
```

## 🚨 Troubleshooting

### Common Issues

1. **Workflow not triggering**
   - Check Logic App state: `az logicapp show --name "$LOGIC_APP_NAME"`
   - Verify connections in Azure Portal

2. **Authentication failures**
   - Ensure Managed Service Identity is enabled
   - Check role assignments on Synapse and Storage

3. **Queue messages not processing**
   - Verify queue names match configuration
   - Check Azure Queues connection status

4. **API returns 401**
   - Verify `x-shared-secret` header matches `ONDEMAND_SHARED_SECRET`

### Debug Commands
```bash
# Get workflow run details
az logic workflow run show \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --run-name "run-id"

# Check Logic App logs
az logic workflow run action list \
  --name "wf-queue-synapse" \
  --resource-group "$RESOURCE_GROUP" \
  --run-name "run-id"
```

## 📚 Documentation

- **Workflow Guide**: `docs/logic-apps-development.md`
- **Deployment Guide**: `docs/workflow-deployment-testing.md`
- **Validation Script**: `scripts/validate-deployment.sh`

## 🎉 Success Checklist

- [ ] Infrastructure deployed successfully
- [ ] All 6 workflows deployed and enabled
- [ ] Queues and tables created
- [ ] Configuration files uploaded
- [ ] Validation script passes
- [ ] Test messages processed successfully
- [ ] API endpoints responding correctly

**Your enterprise Logic Apps orchestration platform is now live! 🚀**
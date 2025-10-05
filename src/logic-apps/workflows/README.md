# Logic Apps Workflows

This directory contains Azure Logic Apps workflow definitions that implement the event-driven data processing pipelines.

## Workflow Files

### `wf-schedule-synapse.workflow.json`
**Purpose**: Scheduled Synapse pipeline execution with distributed locking

**Key Features:**
- **Daily Scheduling**: Runs at 4:00 AM UTC daily
- **Jitter Prevention**: Random delay (0-30 seconds) to avoid thundering herd
- **Leader Election**: Blob lease-based distributed locking prevents duplicate execution
- **Pipeline Execution**: Calls Synapse pipeline with date parameters
- **Managed Identity**: Uses MSI for secure Azure resource access

**Parameters:**
- `pipelineName`: Target Synapse pipeline (default: "pl_ingest_daily")
- `pipelineParameters`: Runtime parameters including RunDate
- `lockBlobUrl`: Storage blob URL for distributed locking
- `maxSkewSeconds`: Maximum jitter delay in seconds

**Flow:**
1. **Trigger**: Daily recurrence at 4:00 AM
2. **Jitter**: Random wait to distribute load
3. **Lock Acquisition**: Attempt blob lease for 120 seconds
4. **Pipeline Execution**: Call Synapse REST API with MSI auth
5. **Completion**: Automatic cleanup on success/failure

### `wf-queue-synapse.workflow.json`
**Purpose**: Event-driven Synapse pipeline execution from storage queues

**Key Features:**
- **Queue Triggering**: Processes messages from Azure Storage Queues
- **Message Deduplication**: Checks processed message table to prevent duplicates
- **Config-Driven Routing**: Routes messages to pipelines based on blob path patterns
- **Idempotent Processing**: Safe retry handling with correlation IDs
- **Dead Letter Handling**: Failed messages routed to DLQ for analysis
- **Exponential Retry**: Robust error handling with backoff strategy

**Parameters:**
- `pipelinesConfig`: JSON configuration for pipeline routing rules
- `dlqName`: Dead letter queue for failed messages
- `dedupeTable`: Table for tracking processed messages
- `runsTable`: Table for storing run history and correlation

**Flow:**
1. **Trigger**: New message arrives in storage queue
2. **Decode**: Base64 decode and parse message content
3. **Deduplication**: Check if message already processed
4. **Pipeline Selection**: Route based on blob path or explicit pipeline name
5. **Execution**: Call Synapse pipeline with message parameters
6. **Mark Processed**: Record successful processing for idempotency

## Deployment

Workflows are deployed as part of the Logic App Standard infrastructure using Bicep templates. The workflow files are referenced during deployment and automatically configured with appropriate connections and settings.

## Configuration

Workflow behavior is controlled through:
- **App Settings**: Environment-specific configuration
- **Pipeline Configs**: Route-to-pipeline mapping (`config/pipelines.*.json`)
- **Connection Strings**: Managed API connections for Azure services

## Monitoring

Workflow execution is monitored through:
- **Logic Apps Diagnostics**: Sent to Log Analytics workspace
- **KQL Queries**: Custom queries for failure analysis
- **Alerts**: Configurable alerts on failure spikes and queue backlog
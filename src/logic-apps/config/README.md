# Pipeline Configuration

This directory contains environment-specific pipeline routing configurations for Logic Apps workflows.

## Configuration Files

### `pipelines.dev.json`
Development environment configuration with flexible routing for testing and development workflows.

### `pipelines.sit.json`
System Integration Testing environment with additional test routes for comprehensive validation.

### `pipelines.prod.json`
Production environment with conservative routing and emergency handling capabilities.

## Configuration Structure

```json
{
  "defaultPipeline": "pl_event_ingest_prod",
  "routes": {
    "blob:raw/": "pl_ingest_raw_prod",
    "blob:curated/": "pl_ingest_curated_prod",
    "type:daily-batch": "pl_ingest_daily_prod",
    "type:emergency": "pl_emergency_prod"
  }
}
```

### Route Matching
- **Prefix matching**: Routes starting with `blob:` match blob storage events by container path
- **Type matching**: Routes starting with `type:` match event types for scheduled or triggered workflows
- **Default fallback**: Events without specific routes use the `defaultPipeline`

### Environment-Specific Routing
- **DEV**: Flexible routing for development and testing
- **SIT**: Additional test routes for integration validation
- **PROD**: Conservative routing with emergency handling

## Usage in Logic Apps

These configurations are loaded by Logic Apps workflows to determine:
- Which pipeline to execute for incoming events
- How to route different types of data processing requests
- Environment-specific behavior and routing rules
# Cost Optimization Guide

This guide explains how to control and customize the cost optimization features in the platform across different environments.

## Overview

The cost optimization system automatically manages resources to minimize costs while maintaining required functionality. It includes:

- Pausing Synapse SQL pools when idle
- Scaling down App Service Plans in non-production
- Managing Event Hubs capacity
- Deallocating development VMs
- Optimizing AKS cluster sizes
- Managing SHIR (Self-hosted Integration Runtime) resources

## Configuration

### Location of Configuration

The main configuration file is located at:
```
/infra/pipeline/cost-optimization-config.yml
```

### How to Modify Settings

1. **Environment-Specific Settings**
   
   Navigate to the appropriate environment section in `cost-optimization-config.yml`:
   ```yaml
   environments:
     dev:
       synapseSqlPoolsPause: true
       synapseShirOptimize: false
       # ... other settings
   ```

2. **Override in Pipeline**
   
   For temporary overrides, modify the pipeline variables:
   ```yaml
   variables:
     - name: synapseSqlPoolsPause
       value: false  # Temporarily disable SQL pool pausing
   ```

### Common Scenarios

1. **Keeping SHIR Running for Development**
   ```yaml
   environments:
     dev:
       synapseShirOptimize: false  # Keeps SHIR running
   ```

2. **Maintaining Active SQL Pools**
   ```yaml
   environments:
     dev:
       synapseSqlPoolsPause: false  # Keeps SQL pools active
   ```

3. **Keeping Test VMs Running**
   ```yaml
   environments:
     sit:
       vmDeallocate: false  # Keeps VMs running
   ```

## Parameters Reference

### Global Parameters

- `costOptimizationEnabled`: Master switch for all optimizations
- `businessHours`: Time window when optimizations should not run
- `maintenanceWindow`: Preferred time for optimization tasks

### Resource-Specific Parameters

1. **Synapse Analytics**
   - `synapseSqlPoolsPause`: Controls automatic pausing of SQL pools
   - `synapseShirOptimize`: Controls SHIR optimization
   - `synapseSqlPoolIdleTime`: Minutes before pausing idle pools

2. **Compute Resources**
   - `appServiceScaleDown`: Controls App Service Plan scaling
   - `vmDeallocate`: Controls VM deallocation
   - `aksScaleDown`: Controls AKS cluster scaling
   - `appServiceMinInstances`: Minimum instances to maintain
   - `aksMinNodes`: Minimum AKS nodes

3. **Event Processing**
   - `eventHubsScaleDown`: Controls Event Hubs scaling
   - `eventHubsMinThroughput`: Minimum throughput units

4. **Data Management**
   - `logRetentionDays`: Days to retain logs
   - `backupRetentionDays`: Days to retain backups

## Best Practices

1. **Development Environment**
   - Keep `synapseShirOptimize: false` if actively developing integrations
   - Enable `synapseSqlPoolsPause` to save costs
   - Use `vmDeallocate: true` unless running long-term tests

2. **SIT Environment**
   - Consider keeping resources running during testing phases
   - Adjust `businessHours` to match testing schedules
   - Monitor resource usage patterns

3. **Production Environment**
   - Minimize automatic optimization
   - Focus on monitoring rather than automatic scaling
   - Maintain consistent performance

## Troubleshooting

If resources are being unexpectedly optimized:

1. Check the environment-specific settings
2. Verify the `businessHours` and `maintenanceWindow` settings
3. Review the pipeline logs for optimization actions
4. Temporarily disable specific optimizations if needed

## Adding New Parameters

To add new optimization parameters:

1. Add the parameter to `cost-optimization-config.yml`
2. Update the optimization script
3. Add the parameter to the pipeline variables
4. Document the new parameter in this guide

## Example Configuration

Complete example for a development environment:

```yaml
environments:
  dev:
    synapseSqlPoolsPause: true      # Pause SQL pools when idle
    synapseShirOptimize: false      # Keep SHIR running for development
    appServiceScaleDown: true       # Scale down App Services
    vmDeallocate: true             # Deallocate unused VMs
    aksScaleDown: true             # Scale down AKS
    eventHubsScaleDown: true       # Scale down Event Hubs
    logRetentionDays: 7            # Weekly log rotation
    backupRetentionDays: 7         # Weekly backup rotation
```

## Support

For issues or questions about cost optimization:

1. Check this documentation first
2. Review the pipeline logs
3. Contact the platform team for additional support
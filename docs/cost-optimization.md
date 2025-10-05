# Azure Data Platform - Cost Optimization Guide

## Overview

This guide provides comprehensive cost optimization strategies for the Azure Data Platform, combining **deployment-time cost control** with **runtime optimization** to minimize expenses while maintaining functionality.

### Cost Optimization Approach

1. **Deployment-Time Optimization**: Choose which expensive resources to deploy using cost switches
2. **Runtime Optimization**: Automatically scale down or pause deployed resources
3. **Resource Decommissioning**: Safely remove resources with data preservation

---

## 📊 Cost Impact Summary

| **Resource** | **Monthly Cost** | **Purpose** | **Dev Recommendation** |
|-------------|------------------|-------------|------------------------|
| **Microsoft Fabric** | $525+ (F2 minimum) | Unified analytics platform | ❌ Skip in dev |
| **Azure Kubernetes Service** | $420+ (3 nodes) | Container orchestration | ❌ Use Container Instances |
| **Azure Machine Learning** | $200+ (compute instances) | ML workspaces | ✅ Keep for ML dev |
| **Microsoft Purview** | $400+ (4 capacity units) | Data governance | ❌ Skip in dev |
| **Synapse Dedicated SQL** | $1,200+ (DW100c) | High-performance analytics | ❌ Use serverless SQL |
| **Self-Hosted IR VM** | $140+ (Standard_D2s_v3) | On-premises connectivity | ❌ Skip in dev |
| **Logic Apps Standard** | $200+ (base plan) | Workflow orchestration | ✅ Keep for development |
| **Container Instances** | Variable (pay-per-use) | Lightweight containers | ✅ Use instead of AKS |

**Total Potential Savings in Dev: ~$2,685/month**

---

## 🛠️ Quick Start Guide

### Step 1: Generate Cost-Optimized Parameters

Generate deployment parameters based on your environment:

```bash
# Generate parameters for development (saves ~$2,685/month)
./scripts/generate-cost-params.sh dev

# Generate parameters for production (full deployment)
./scripts/generate-cost-params.sh prod

# Generate ARM template parameters
./scripts/generate-cost-params.sh --format arm sit
```

### Step 2: Deploy with Cost Optimization

Use the generated parameter files for deployment:

```bash
# Deploy with cost-optimized parameters
az deployment group create \
  --resource-group rg-dataplatform-dev \
  --template-file infra/main.bicep \
  --parameters @infra/params/cost-optimized-dev.bicepparam \
  --parameters namePrefix=mycompany environment=dev \
  --parameters synapseSqlAdminLogin=sqladmin \
  --parameters synapseSqlAdminPassword='YourSecurePassword123!'
```

### Step 3: Apply Runtime Optimizations

After deployment, run runtime optimizations:

```bash
# Pause/scale down existing resources
./infra/pipeline/optimize-costs.sh <subscription-id> <resource-group> <environment>

# Example for development environment
./infra/pipeline/optimize-costs.sh \
  12345678-1234-1234-1234-123456789012 \
  rg-dataplatform-dev \
  dev
```

---

## 📋 Configuration Management

### Main Configuration File
**Location**: `/infra/pipeline/cost-optimization-config.yml`

This file controls both deployment-time resource selection and runtime optimization behavior.

### Deployment-Time Flags

Configure which expensive resources to deploy:

```yaml
deploymentFlags:
  # Microsoft Fabric (F2 = $525/month minimum)
  deployFabric:
    dev: false      # Skip Fabric in dev - use local Power BI for testing
    sit: false      # Skip in system integration testing
    uat: true       # Deploy for user acceptance testing
    prod: true      # Deploy in production
  
  # Azure Kubernetes Service (~$420/month for 3 nodes)
  deployAKS:
    dev: false      # Use Container Instances instead for dev
    sit: true       # Need for integration testing
    uat: true       # Deploy for user testing
    prod: true      # Deploy in production
```

### Runtime Optimization Settings

Configure runtime behavior for deployed resources:

```yaml
environments:
  dev:
    # Synapse Analytics Controls
    synapseSqlPoolsPause: true      # Control automatic pausing of SQL pools
    synapseShirOptimize: false      # Keep false if you need SHIR for development
    
    # Compute Resources
    appServiceScaleDown: true       # Scale down App Service Plans to minimum SKU
    vmDeallocate: true             # Deallocate development VMs when not in use
    aksScaleDown: true             # Scale down AKS node pools to minimum
    
    # Event Processing
    eventHubsScaleDown: true       # Scale down Event Hubs to Standard tier
    
    # Retention Periods (in days)
    logRetentionDays: 7            # Shorter retention for dev logs
    backupRetentionDays: 7         # Shorter retention for dev backups
```

---

## 🔧 Available Tools and Scripts

### 1. Cost Parameter Generator
**Location**: `./scripts/generate-cost-params.sh`

Generate deployment parameters based on cost optimization configuration:

```bash
# Basic usage
./scripts/generate-cost-params.sh <environment>

# Options
./scripts/generate-cost-params.sh --help
./scripts/generate-cost-params.sh --format arm dev
./scripts/generate-cost-params.sh --no-comments prod
```

**Output**: Creates `infra/params/cost-optimized-{env}.bicepparam`

### 2. Runtime Cost Optimizer
**Location**: `./infra/pipeline/optimize-costs.sh`

Automatically pause/scale down expensive resources:

```bash
# Runtime optimization
./infra/pipeline/optimize-costs.sh <subscription-id> <resource-group> <environment>

# Features:
# - Pause Synapse SQL pools
# - Scale down App Service plans
# - Scale down Event Hub namespaces
# - Deallocate development VMs
# - Scale down AKS clusters
```

### 3. Resource Decommissioning Tool
**Location**: `./scripts/decommission-resources.sh`

Safely remove expensive resources while preserving data:

```bash
# Dry run (see what would be deleted)
./scripts/decommission-resources.sh --dry-run <subscription-id> <resource-group> <environment>

# Safe removal with data preservation
./scripts/decommission-resources.sh <subscription-id> <resource-group> <environment>

# Force removal without prompts
./scripts/decommission-resources.sh --force <subscription-id> <resource-group> <environment>
```

---

## 💡 Common Scenarios and Best Practices

### Scenario 1: Keeping SHIR Running for Development

```yaml
environments:
  dev:
    synapseShirOptimize: false  # Keeps SHIR running for integration work
```

**When to use**: Active development of on-premises data integrations

### Scenario 2: Maintaining Active SQL Pools for Testing

```yaml
environments:
  dev:
    synapseSqlPoolsPause: false  # Keeps SQL pools active
```

**When to use**: Performance testing or continuous query workloads

### Scenario 3: Testing Expensive Resources Temporarily

```bash
# 1. Generate parameters with specific resource enabled
./scripts/generate-cost-params.sh dev
# Edit the generated file to set deployFabric = true

# 2. Deploy with the expensive resource
az deployment group create \
  --resource-group rg-dataplatform-dev \
  --template-file infra/main.bicep \
  --parameters @infra/params/cost-optimized-dev.bicepparam \
  --parameters deployFabric=true

# 3. Test functionality
# ... your testing ...

# 4. Remove expensive resource when done
./scripts/decommission-resources.sh \
  <subscription-id> rg-dataplatform-dev dev
```

### Scenario 4: Environment-Specific Settings

**Development Environment**:
- Keep `synapseShirOptimize: false` if actively developing integrations
- Enable `synapseSqlPoolsPause` to save costs
- Use `vmDeallocate: true` unless running long-term tests
- Disable expensive resources: Fabric, AKS, Purview

**SIT Environment**:
- Consider keeping resources running during testing phases
- Adjust `businessHours` to match testing schedules
- Monitor resource usage patterns
- Enable AKS for integration testing

**Production Environment**:
- Minimize automatic optimization
- Focus on monitoring rather than automatic scaling
- Maintain consistent performance
- Deploy all required resources

---

## 📈 Parameters Reference

### Deployment-Time Parameters (in main.bicep)

- `deployFabric`: Deploy Microsoft Fabric capacity
- `deployAKS`: Deploy Azure Kubernetes Service
- `deployMachineLearning`: Deploy Azure Machine Learning workspace
- `deployPurview`: Deploy Microsoft Purview for data governance
- `deploySynapseDedicatedSQL`: Deploy Synapse dedicated SQL pools
- `deploySHIR`: Deploy Self-Hosted Integration Runtime VM
- `deployContainerInstances`: Deploy Azure Container Instances
- `deployLogicApps`: Deploy Logic Apps Standard plan
- `deployCognitiveServices`: Deploy Cognitive Services
- `deployAzureMaps`: Deploy Azure Maps

### Runtime Optimization Parameters

**Global Parameters**:
- `costOptimizationEnabled`: Master switch for all optimizations
- `businessHours`: Time window when optimizations should not run
- `maintenanceWindow`: Preferred time for optimization tasks

**Resource-Specific Parameters**:

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

---

## 🔍 Monitoring and Troubleshooting

### Cost Monitoring Setup

1. **Track Key Metrics**:
   - Monthly spend by resource type
   - Cost per environment comparison
   - Optimization savings achieved
   - Resource utilization trends

2. **Set Up Cost Alerts**:
```bash
# Development environment budget
az consumption budget create \
  --budget-name "DataPlatform-Dev-Monthly" \
  --amount 5000 \
  --time-grain Monthly \
  --resource-group rg-dataplatform-dev
```

3. **Apply Cost Allocation Tags**:
```yaml
tags:
  Environment: dev/sit/uat/prod
  Project: gpt-data-platform
  CostCenter: IT-DataPlatform
  Owner: data-team@company.com
```

### Troubleshooting Common Issues

1. **Resources Being Unexpectedly Optimized**:
   - Check environment-specific settings in `cost-optimization-config.yml`
   - Verify `businessHours` and `maintenanceWindow` settings
   - Review pipeline logs for optimization actions
   - Temporarily disable specific optimizations if needed

2. **Deployment Fails Due to Missing Dependencies**:
   - Check conditional deployment logic in main.bicep
   - Use dependency mapping in decommission script
   - Verify parameter file syntax

3. **Cost Savings Lower Than Expected**:
   - Review which resources are still running in Azure portal
   - Use decommission script for more aggressive cost reduction
   - Check if runtime optimizations are actually working

4. **Cannot Restore After Decommissioning**:
   - Check backup directory for configuration files
   - Manually recreate resources using backup configurations
   - Use the restore functionality in decommission script

---

## 📊 Cost Optimization by Environment

### Development Environment Template
```yaml
# Recommended settings for dev environment
deploymentFlags:
  deployFabric: false              # Save $525/month
  deployAKS: false                 # Save $420/month
  deployPurview: false             # Save $400/month
  deploySynapseDedicatedSQL: false # Save $1,200/month
  deploySHIR: false               # Save $140/month
  deployMachineLearning: true      # Keep for ML development
  deployLogicApps: true           # Keep for workflow development
  deployContainerInstances: true  # Use instead of AKS

environments:
  dev:
    synapseSqlPoolsPause: true      # Pause SQL pools when idle
    synapseShirOptimize: false      # Keep SHIR running if needed
    appServiceScaleDown: true       # Scale down App Services
    vmDeallocate: true             # Deallocate unused VMs
    aksScaleDown: true             # Scale down AKS (if deployed)
    eventHubsScaleDown: true       # Scale down Event Hubs
    logRetentionDays: 7            # Weekly log rotation
    backupRetentionDays: 7         # Weekly backup rotation
```

**Total Savings**: ~$2,685/month

---

## 🆘 Support and Recovery

### Data Protection

All cost optimization tools include safety mechanisms:
- Automatic configuration backups before resource deletion
- Dependency checking to prevent cascading failures
- Dry-run mode for all operations
- Recovery options from backups

### Recovery Procedures

**Restore from Backup**:
```bash
# List available backups
ls -la scripts/decommission-backups/

# Restore specific backup
./scripts/decommission-resources.sh \
  --restore backup-20251005-031123 \
  <subscription-id> <resource-group> <environment>
```

**Redeploy with Full Configuration**:
```bash
# Generate full production parameters
./scripts/generate-cost-params.sh prod

# Deploy with all resources enabled
az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters @infra/params/cost-optimized-prod.bicepparam
```

### Getting Help

1. Check this documentation first
2. Review the pipeline logs for optimization actions
3. Use dry-run mode to understand what would be changed
4. Contact the platform team for complex cost optimization issues

---

## 🚀 Adding New Optimization Parameters

To extend the cost optimization system:

1. **Add Parameter to Configuration**:
   ```yaml
   # In cost-optimization-config.yml
   deploymentFlags:
     deployNewService:
       dev: false
       prod: true
   ```

2. **Update main.bicep**:
   ```bicep
   @description('Deploy new expensive service')
   param deployNewService bool = true
   
   module newService 'modules/newService.bicep' = if (deployNewService) {
     // module configuration
   }
   ```

3. **Update Parameter Generator**:
   Add logic to `generate-cost-params.sh` to handle the new parameter

4. **Update Documentation**:
   Document the new parameter and its cost impact

---

*This guide provides comprehensive cost optimization for the Azure Data Platform. For technical implementation details, refer to the main README.md or contact the platform team.*
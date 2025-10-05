# Deployment Troubleshooting Guide

> **Last Updated:** 2025-01-15
> **Audience:** Developer, Operator
> **Prerequisites:** Azure CLI installed, basic understanding of Azure services

## Overview

This guide provides solutions for common deployment issues encountered when deploying the GPT Data Platform infrastructure. It covers troubleshooting techniques, diagnostic commands, and preventive measures for successful deployments.

## Table of Contents

- [Common Deployment Issues and Solutions](#common-deployment-issues-and-solutions)
- [Diagnostic Tools](#diagnostic-tools)
- [Preventive Measures](#preventive-measures)
- [Emergency Procedures](#emergency-procedures)
- [Related Documentation](#related-documentation)

## Common Deployment Issues and Solutions

### 1. Resource Provider Registration Failures

**Symptoms:**
- Deployment fails with "Resource Provider not registered"
- Error mentions "Microsoft.XYZ provider not registered"

**Solutions:**
1. Run the prerequisites check script:
   ```bash
   ./check-prerequisites.sh
   ```
2. Manually register the provider:
   ```bash
   az provider register --namespace Microsoft.XYZ
   ```
3. Wait for registration (can take up to 15 minutes)

### 2. Name Conflicts

**Symptoms:**
- "The storage account name is already taken"
- "The Key Vault name is not available"

**Solutions:**
1. Verify name availability:
   ```bash
   az storage account check-name --name <storage-name>
   az keyvault check-name --name <keyvault-name>
   ```
2. Update the namePrefix parameter in your deployment
3. Run validation before deployment:
   ```bash
   az deployment sub validate -f main.bicep
   ```

### 3. Network Configuration Issues

**Symptoms:**
- Private endpoint connection failures
- VNet peering issues
- NSG blocking required traffic

**Solutions:**
1. Verify subnet delegation settings
2. Check NSG rules:
   ```bash
   az network nsg rule list --nsg-name <nsg-name> -g <resource-group>
   ```
3. Validate private endpoint DNS resolution
4. Ensure service endpoints are enabled where required

### 4. Permission Issues

**Symptoms:**
- "Forbidden" or "Unauthorized" errors
- "Insufficient privileges" messages
- Key Vault access denied

**Solutions:**
1. Verify service principal permissions:
   ```bash
   az role assignment list --assignee <service-principal-id>
   ```
2. Check required roles:
   - Network Contributor
   - Storage Account Contributor
   - Key Vault Administrator
   - Synapse Administrator
3. Validate managed identity configurations

### 5. Quota Limits

**Symptoms:**
- "Quota limit exceeded"
- Resource creation failures with capacity errors

**Solutions:**
1. Check current usage:
   ```bash
   az vm list-usage --location <location>
   ```
2. Request quota increase if needed
3. Consider cleaning up unused resources

### 6. Deployment Timing Out

**Symptoms:**
- Deployment exceeds timeout limit
- Long-running operations fail

**Solutions:**
1. Monitor deployment progress:
   ```bash
   ./monitor-deployment.sh <deployment-name>
   ```
2. Check resource dependencies
3. Consider breaking deployment into smaller chunks

## Rollback Procedures

### When to Rollback
- Failed deployments
- Incorrect configuration
- Security concerns
- Performance issues

### Rollback Steps
1. Stop ongoing deployment if any:
   ```bash
   az deployment sub cancel --name <deployment-name>
   ```

2. Initialize rollback:
   ```bash
   ./rollback-deployment.sh <deployment-name> <resource-group> <subscription-id> <environment>
   ```

3. Verify rollback completion:
   - Check rollback logs
   - Verify resource deletion
   - Validate environment state

### Post-Rollback Actions
1. Review rollback logs
2. Update deployment parameters if needed
3. Re-run prerequisites check
4. Attempt redeployment if appropriate

## Monitoring and Diagnostics

### Deployment Monitoring
1. Use the monitoring script:
   ```bash
   ./monitor-deployment.sh <deployment-name>
   ```

2. Check resource health:
   ```bash
   az resource show --ids <resource-id> --query "properties.provisioningState"
   ```

3. Review metrics and logs:
   - Check deployment_summary.md
   - Review metrics_*.json
   - Analyze monitoring logs

### Diagnostic Tools
1. Azure Resource Explorer (resources.azure.com)
2. Azure Monitor metrics
3. Resource-specific logs
4. Network Watcher for connectivity issues

## Modern Platform Component Issues

### Azure Kubernetes Service (AKS)

**Common Issues:**
- Node pool creation failures
- RBAC configuration problems
- Network plugin issues

**Solutions:**
```bash
# Check cluster status
az aks show --resource-group <rg> --name <cluster-name>

# Get cluster credentials
az aks get-credentials --resource-group <rg> --name <cluster-name>

# Check node status
kubectl get nodes

# Verify RBAC
kubectl auth can-i --list
```

### Azure Machine Learning

**Common Issues:**
- Compute instance startup failures
- Workspace connectivity issues
- Model deployment problems

**Solutions:**
```bash
# Check workspace status
az ml workspace show --name <workspace-name> --resource-group <rg>

# List compute instances
az ml compute list --workspace-name <workspace-name> --resource-group <rg>

# Check endpoint status
az ml online-endpoint list --workspace-name <workspace-name> --resource-group <rg>
```

### Microsoft Purview

**Common Issues:**
- Data source scanning failures
- Private endpoint connectivity
- Classification rule problems

**Solutions:**
```bash
# Check Purview account status
az purview account show --name <account-name> --resource-group <rg>

# Verify connectivity
az network private-endpoint list --resource-group <rg>
```

### Microsoft Fabric

**Common Issues:**
- Capacity allocation problems
- OneLake access issues
- Workspace creation failures

**Solutions:**
```bash
# Check Fabric capacity
az fabric capacity show --name <capacity-name> --resource-group <rg>

# Monitor capacity metrics
az monitor metrics list --resource <capacity-id>
```

### Container Instances

**Common Issues:**
- Container startup failures
- Image pull problems
- Resource allocation issues

**Solutions:**
```bash
# Check container group status
az container show --resource-group <rg> --name <container-group>

# View container logs
az container logs --resource-group <rg> --name <container-group>

# Check events
az container exec --resource-group <rg> --name <container-group> --exec-command "sh"
```

## Best Practices

### Pre-Deployment
1. Run prerequisites check
2. Validate resource names
3. Verify service principal permissions
4. Check quota limits
5. Review network configurations

### During Deployment
1. Monitor progress actively
2. Watch for warning signs
3. Keep deployment logs
4. Monitor resource health

### Post-Deployment
1. Verify all resources
2. Check connectivity
3. Validate security settings
4. Document any issues
5. Update runbooks if needed

## Getting Help

### Internal Resources
- Review deployment logs
- Check monitoring outputs
- Consult architecture documentation

### External Resources
- Azure Status Page
- Azure Documentation
- Support Tickets
- Stack Overflow

### Escalation Path
1. Review troubleshooting guide
2. Check recent deployments
3. Consult team leads
4. Open support ticket
5. Emergency rollback if needed

## Related Documentation

- [Modern Platform Implementation](modern-platform-implementation-guide.md) - Complete deployment procedures
- [Platform Architecture](architecture.md) - Understanding system components
- [Security Assessment](security-assessment.md) - Security configuration and compliance
- [RBAC Implementation](rbac-implementation-guide.md) - Access control setup
- [Cost Optimization](cost-optimization.md) - Cost management during deployment

## Next Steps

After resolving deployment issues:

1. Document the resolution for future reference
2. Update deployment runbooks if needed
3. Review [Cost Optimization](cost-optimization.md) for resource efficiency
4. Set up monitoring and alerting for the deployed environment
5. Complete post-deployment validation procedures
# Deployment Troubleshooting Guide

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
# Azure Synapse Analytics CI/CD Deployment Guide

This guide outlines the modern approach for deploying Azure Synapse Analytics workspaces across development, SIT, and production environments using Git integration and automated pipelines.

## 📋 Overview

Azure Synapse Analytics supports native Git integration, allowing you to:
- Connect Synapse workspaces directly to Git repositories
- Publish artifacts to a `workspace_publish` branch
- Deploy artifacts between environments using automated pipelines
- Maintain version control and audit trails for all changes

## 🏗️ Architecture

### Git Integration Setup
```
Synapse Studio (Development)
        ↓
workspace_publish Branch (Artifacts)
        ↓
CI/CD Pipeline (Promotion)
        ↓
SIT ←→ Production Workspaces
```

### Environment Flow
1. **Development**: Synapse Studio connected to `workspace_publish` branch
2. **SIT**: Automated deployment from `workspace_publish` branch
3. **Production**: Automated deployment from approved `workspace_publish` branch

## 🚀 Deployment Pipeline

### Pipeline Features

- **Git-Triggered**: Automatically triggers on changes to `workspace_publish` branch
- **Environment-Specific**: Deploys to dev, sit, or prod environments
- **Multiple Modes**: Incremental, full, or validation-only deployments
- **Cleanup Options**: Remove obsolete resources from target environments
- **Approval Gates**: Manual approval required for SIT and production deployments

### Pipeline Parameters

| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `targetEnvironment` | Target deployment environment | dev, sit, prod | dev |
| `deploymentMode` | Type of deployment to perform | incremental, full, validate | incremental |
| `cleanupObsolete` | Remove resources not in source | true, false | false |
| `skipPreDeploymentValidation` | Skip validation checks | true, false | false |

## 📦 Deployment Modes

### Incremental Deployment
- Deploys only changed artifacts
- Faster deployment time
- Preserves existing resources
- Recommended for regular updates

### Full Deployment
- Deploys all artifacts from source
- Overwrites existing resources
- Slower but ensures consistency
- Use for major changes or initial deployments

### Validation Only
- Validates artifacts without deployment
- Checks for syntax errors and dependencies
- Useful for pre-deployment checks

## 🧹 Resource Cleanup

### Cleanup Functionality
The pipeline supports automatic cleanup of resources that exist in target environments but are no longer present in the development workspace.

**When to Enable Cleanup:**
- After removing pipelines, datasets, or linked services from development
- During major refactoring or workspace restructuring
- When promoting clean, simplified environments

**Cleanup Behavior:**
- Removes pipelines not present in source
- Removes datasets not present in source
- Removes linked services not present in source
- Preserves data and external dependencies

### Manual Cleanup Override
```yaml
# In pipeline parameters
cleanupObsolete: true  # Enable automatic cleanup
```

## 🔐 Security Considerations

### Authentication
- Uses Azure DevOps service connections
- Managed Identity for Synapse workspace access
- Key Vault integration for secrets

### Permissions Required
- **Source Workspace**: Synapse Contributor role
- **Target Workspace**: Synapse Contributor role
- **Resource Group**: Contributor role
- **Key Vault**: Secrets User role

## 📋 Pre-Deployment Checklist

### Development Environment
- [ ] Synapse workspace connected to Git
- [ ] Artifacts published to `workspace_publish` branch
- [ ] All linked services use parameterized connections
- [ ] Sensitive data stored in Key Vault
- [ ] Pipelines tested and validated

### Target Environment
- [ ] Target Synapse workspace exists
- [ ] Required permissions configured
- [ ] Key Vault access configured
- [ ] Network connectivity verified

## 🚦 Approval Workflow

### SIT Environment
- Automatic pipeline trigger on `workspace_publish` changes
- Manual approval required before deployment
- Checklist validation by data engineering team

### Production Environment
- Deployment from approved `workspace_publish` branch
- Automated deployment (no manual approval)
- Rollback capability available

## 📊 Monitoring & Validation

### Post-Deployment Validation
- Workspace connectivity verification
- Linked service connection testing
- Pipeline execution capability
- Dataset accessibility validation

### Monitoring
- Pipeline execution logs
- Synapse workspace metrics
- Error notifications and alerts

## 🔄 Rollback Strategy

### Automatic Rollback
- Pipeline supports rollback to previous deployment
- Previous ARM templates preserved
- Quick restoration capability

### Manual Rollback
- Export current state before deployment
- Restore from backup ARM templates
- Selective resource restoration

## 📝 Usage Examples

### Deploy to SIT with Cleanup
```bash
az pipelines run \
  --name "Synapse-CICD-Pipeline" \
  --parameters targetEnvironment=sit cleanupObsolete=true
```

### Full Production Deployment
```bash
az pipelines run \
  --name "Synapse-CICD-Pipeline" \
  --parameters targetEnvironment=prod deploymentMode=full
```

### Validation Only
```bash
az pipelines run \
  --name "Synapse-CICD-Pipeline" \
  --parameters targetEnvironment=sit deploymentMode=validate
```

## 🐛 Troubleshooting

### Common Issues

**Pipeline Fails with Permission Error**
- Verify service connection has correct permissions
- Check managed identity configuration
- Validate Key Vault access policies

**Linked Service Connection Fails**
- Verify parameterized connection strings
- Check Key Vault secret references
- Validate network connectivity

**Cleanup Removes Required Resources**
- Review cleanup scope before enabling
- Test cleanup in non-production first
- Use selective cleanup approaches

### Logs and Diagnostics
- Pipeline logs available in Azure DevOps
- Synapse workspace activity logs
- ARM deployment operation details

## 📚 Additional Resources

- [Azure Synapse CI/CD Documentation](https://docs.microsoft.com/en-us/azure/synapse-analytics/cicd/overview)
- [Synapse Workspace Deployment Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/synapse-workspace-deployment)
- [Git Integration in Synapse](https://docs.microsoft.com/en-us/azure/synapse-analytics/cicd/source-control)
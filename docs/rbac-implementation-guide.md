# RBAC Assignment Implementation Guide

## Overview

The platform now includes comprehensive RBAC (Role-Based Access Control) assignments for all modern platform components. These assignments are implemented through the `rbacAssignments.bicep` module and automatically configure appropriate permissions for managed identities and security groups.

## Security Groups Setup

Before deploying the infrastructure, you need to create the following Azure AD security groups and obtain their Object IDs:

### Required Security Groups

| Group Name | Purpose | Recommended Azure AD Group Name |
|------------|---------|--------------------------------|
| Platform Admins | Full administrative access to all resources | `grp-gptdata-platform-admins` |
| Platform Operators | Infrastructure management and operations | `grp-gptdata-platform-operators` |
| Platform Developers | Development and testing access | `grp-gptdata-platform-developers` |
| Platform Readers | Read-only access across all resources | `grp-gptdata-platform-readers` |
| ML Engineers | Machine Learning workspace management | `grp-gptdata-ml-engineers` |
| Data Analysts | Microsoft Fabric and analytics access | `grp-gptdata-data-analysts` |
| Data Scientists | ML model development and experimentation | `grp-gptdata-data-scientists` |
| Data Engineers | Synapse and data pipeline management | `grp-gptdata-data-engineers` |
| Data Governance Team | Purview data catalog management | `grp-gptdata-data-governance` |

### Creating Security Groups

Use Azure CLI to create the groups:

```bash
# Create security groups
az ad group create --display-name "grp-gptdata-platform-admins" --mail-nickname "gptdata-platform-admins"
az ad group create --display-name "grp-gptdata-platform-operators" --mail-nickname "gptdata-platform-operators"
az ad group create --display-name "grp-gptdata-platform-developers" --mail-nickname "gptdata-platform-developers"
az ad group create --display-name "grp-gptdata-platform-readers" --mail-nickname "gptdata-platform-readers"
az ad group create --display-name "grp-gptdata-ml-engineers" --mail-nickname "gptdata-ml-engineers"
az ad group create --display-name "grp-gptdata-data-analysts" --mail-nickname "gptdata-data-analysts"
az ad group create --display-name "grp-gptdata-data-scientists" --mail-nickname "gptdata-data-scientists"
az ad group create --display-name "grp-gptdata-data-engineers" --mail-nickname "gptdata-data-engineers"
az ad group create --display-name "grp-gptdata-data-governance" --mail-nickname "gptdata-data-governance"

# Get Object IDs for parameter file
az ad group show --group "grp-gptdata-platform-admins" --query id -o tsv
az ad group show --group "grp-gptdata-platform-operators" --query id -o tsv
az ad group show --group "grp-gptdata-platform-developers" --query id -o tsv
az ad group show --group "grp-gptdata-platform-readers" --query id -o tsv
az ad group show --group "grp-gptdata-ml-engineers" --query id -o tsv
az ad group show --group "grp-gptdata-data-analysts" --query id -o tsv
az ad group show --group "grp-gptdata-data-scientists" --query id -o tsv
az ad group show --group "grp-gptdata-data-engineers" --query id -o tsv
az ad group show --group "grp-gptdata-data-governance" --query id -o tsv
```

## Parameter File Configuration

Update your parameter files (e.g., `infra/params/dev.main.parameters.json`) with the security group Object IDs:

```json
{
  "securityGroups": {
    "value": {
      "platformAdmins": "your-platform-admins-object-id",
      "platformOperators": "your-platform-operators-object-id",
      "platformDevelopers": "your-platform-developers-object-id",
      "platformReaders": "your-platform-readers-object-id",
      "mlEngineers": "your-ml-engineers-object-id",
      "dataAnalysts": "your-data-analysts-object-id",
      "dataScientists": "your-data-scientists-object-id",
      "dataEngineers": "your-data-engineers-object-id",
      "dataGovernanceTeam": "your-data-governance-object-id"
    }
  }
}
```

**Note**: Leave any Object ID as an empty string (`""`) to skip role assignments for that group.

## Automated Role Assignments

The RBAC module automatically assigns the following roles:

### Storage Account
- **Platform Operators**: Storage Blob Data Owner
- **AKS Managed Identity**: Storage Blob Data Contributor
- **ML Workspace Managed Identity**: Storage Blob Data Contributor
- **Purview Managed Identity**: Storage Blob Data Reader
- **Fabric Managed Identity**: Storage Blob Data Reader
- **Container Instances Managed Identity**: Storage Blob Data Reader

### Key Vault
- **Platform Operators**: Key Vault Administrator
- **Functions Managed Identity**: Key Vault Secrets User
- **Logic Apps Managed Identity**: Key Vault Secrets User
- **AKS Managed Identity**: Key Vault Secrets User
- **ML Workspace Managed Identity**: Key Vault Secrets User
- **Container Instances Managed Identity**: Key Vault Secrets User

### Azure Kubernetes Service (AKS)
- **Platform Operators**: AKS Cluster Admin
- **Platform Developers**: AKS Cluster User

### Azure Machine Learning
- **ML Engineers**: AzureML Data Scientist
- **Data Scientists**: AzureML Data Scientist

### Microsoft Purview
- **Data Governance Team**: Purview Data Curator
- **Platform Readers**: Purview Data Reader

### Microsoft Fabric
- **Platform Operators**: Fabric Capacity Admin
- **Data Analysts**: Fabric Capacity Contributor

### Synapse Analytics
- **Platform Operators**: Synapse Contributor
- **Data Engineers**: Synapse Contributor
- **Purview Managed Identity**: Synapse Contributor
- **Fabric Managed Identity**: Synapse SQL User

## Deployment

Deploy with RBAC assignments:

```bash
# Deploy main infrastructure with RBAC
az deployment sub create \
  --location "Switzerland North" \
  --template-file infra/main.bicep \
  --parameters @infra/params/dev.main.parameters.json \
  --name "gptdata-platform-with-rbac"
```

## Validation

After deployment, verify role assignments:

```bash
# Check storage account role assignments
az role assignment list --scope "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Storage/storageAccounts/{storage-name}"

# Check Key Vault role assignments
az role assignment list --scope "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"

# Check AKS role assignments
az role assignment list --scope "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.ContainerService/managedClusters/{aks-name}"

# View RBAC assignment status from deployment output
az deployment sub show --name "gptdata-platform-with-rbac" --query properties.outputs.rbacAssignmentStatus.value
```

## Role Assignment Matrix

| Resource | Security Group | Managed Identity | Role |
|----------|----------------|------------------|------|
| Storage Account | Platform Operators | - | Storage Blob Data Owner |
| Storage Account | - | AKS | Storage Blob Data Contributor |
| Storage Account | - | ML Workspace | Storage Blob Data Contributor |
| Storage Account | - | Purview | Storage Blob Data Reader |
| Storage Account | - | Fabric | Storage Blob Data Reader |
| Storage Account | - | Container Instances | Storage Blob Data Reader |
| Key Vault | Platform Operators | - | Key Vault Administrator |
| Key Vault | - | Functions | Key Vault Secrets User |
| Key Vault | - | Logic Apps | Key Vault Secrets User |
| Key Vault | - | AKS | Key Vault Secrets User |
| Key Vault | - | ML Workspace | Key Vault Secrets User |
| Key Vault | - | Container Instances | Key Vault Secrets User |
| AKS Cluster | Platform Operators | - | AKS Cluster Admin |
| AKS Cluster | Platform Developers | - | AKS Cluster User |
| ML Workspace | ML Engineers | - | AzureML Data Scientist |
| ML Workspace | Data Scientists | - | AzureML Data Scientist |
| Purview Account | Data Governance Team | - | Purview Data Curator |
| Purview Account | Platform Readers | - | Purview Data Reader |
| Fabric Capacity | Platform Operators | - | Fabric Capacity Admin |
| Fabric Capacity | Data Analysts | - | Fabric Capacity Contributor |
| Synapse Workspace | Platform Operators | - | Synapse Contributor |
| Synapse Workspace | Data Engineers | - | Synapse Contributor |
| Synapse Workspace | - | Purview | Synapse Contributor |
| Synapse Workspace | - | Fabric | Synapse SQL User |

## Security Considerations

1. **Principle of Least Privilege**: Each managed identity and security group receives only the minimum permissions required for their function.

2. **Group Management**: Regularly review group memberships and remove inactive users.

3. **Monitoring**: Use Azure Monitor to track role assignments and access patterns.

4. **Emergency Access**: Ensure Platform Admins group has emergency access procedures.

5. **Conditional Access**: Consider implementing conditional access policies for sensitive groups.

## Troubleshooting

### Common Issues

1. **"Principal not found" errors**: Verify security group Object IDs are correct and groups exist.

2. **Permission denied**: Ensure the deployment identity has sufficient permissions to assign roles.

3. **Role assignment conflicts**: Check for existing conflicting role assignments that may need to be removed.

### Diagnostic Commands

```bash
# Check if security group exists
az ad group show --group "object-id"

# List all role assignments for a resource
az role assignment list --scope "resource-id"

# Check deployment permissions
az role assignment list --assignee "deployment-identity-object-id" --all
```
# RBAC and Managed Identities Management Guide

This guide outlines the RBAC (Role-Based Access Control) and Managed Identities implementation for the Data Platform project.

> **Note**: For comprehensive RBAC deployment instructions, see the [RBAC Implementation Guide](rbac-implementation-guide.md).

## Automated RBAC Implementation

The platform includes an automated RBAC assignment module (`infra/modules/rbacAssignments.bicep`) that configures all necessary permissions for managed identities and security groups. This ensures consistent security across all platform components.

## Security Groups Structure

### Administrator Groups
- **Platform-Admins**: Full access to all resources
  - Role: Owner
  - Access: All environments (restricted in prod)
  - Group Name: `grp-platform-admins`

- **Platform-Operators**: Infrastructure management
  - Role: Contributor
  - Access: All environments
  - Group Name: `grp-platform-operators`

### Developer Groups
- **Platform-Developers**: Development and testing
  - Role: Contributor
  - Access: Dev and SIT environments
  - Group Name: `grp-platform-developers`

- **Platform-Readers**: Read-only access
  - Role: Reader
  - Access: All environments
  - Group Name: `grp-platform-readers`

## Managed Identities

### System-Assigned Managed Identities
Used for core platform services:
- Key Vault access
- Storage Account access
- Event Grid publishing

### User-Assigned Managed Identities
1. **Functions Runtime**
   - Name Pattern: `id-user-{env}-functions`
   - Permissions:
     - Key Vault Secrets User
     - Cognitive Services User
     - Azure Maps Data Reader

2. **Logic Apps Runtime**
   - Name Pattern: `id-user-{env}-logicapp`
   - Permissions:
     - Functions Contributor
     - Key Vault Secrets User

3. **AKS Cluster**
   - Name Pattern: `id-user-{env}-aks`
   - Permissions:
     - Azure Kubernetes Service Cluster User
     - Key Vault Secrets User
     - Storage Blob Data Contributor

4. **Machine Learning Workspace**
   - Name Pattern: `id-user-{env}-ml`
   - Permissions:
     - AzureML Data Scientist
     - Key Vault Secrets User
     - Storage Blob Data Contributor

5. **Microsoft Purview**
   - Name Pattern: `id-user-{env}-purview`
   - Permissions:
     - Purview Data Reader
     - Storage Blob Data Reader
     - Synapse Contributor

6. **Microsoft Fabric**
   - Name Pattern: `id-user-{env}-fabric`
   - Permissions:
     - Fabric Capacity Contributor
     - Storage Blob Data Reader
     - Synapse SQL User

7. **Container Instances**
   - Name Pattern: `id-user-{env}-containers`
   - Permissions:
     - Key Vault Secrets User
     - Storage Blob Data Reader

## Role Assignments

### Core Platform Roles
```plaintext
Resource                    Role                           Assigned To
------------------------------------------------------------------------
Resource Group             Owner                          Platform-Admins
Resource Group             Contributor                    Platform-Operators
Resource Group             Contributor                    Platform-Developers
Resource Group             Reader                         Platform-Readers
Key Vault                  Key Vault Administrator        Platform-Operators
Key Vault                  Key Vault Secrets User         Functions MI
Key Vault                  Key Vault Secrets User         Logic Apps MI
Key Vault                  Key Vault Secrets User         AKS MI
Key Vault                  Key Vault Secrets User         ML MI
Storage Account            Storage Blob Data Owner        Platform-Operators
Storage Account            Storage Blob Data Contributor  AKS MI
Storage Account            Storage Blob Data Contributor  ML MI
Storage Account            Storage Blob Data Reader       Purview MI
Storage Account            Storage Blob Data Reader       Fabric MI
Storage Account            Storage Blob Data Reader       Container MI
Cognitive Services         Cognitive Services User        Functions MI
Azure Maps                 Azure Maps Data Reader         Functions MI
AKS Cluster                Azure Kubernetes Service Admin Platform-Operators
AKS Cluster                Azure Kubernetes Service User  Developers
ML Workspace               AzureML Data Scientist         ML Engineers
Purview Account            Purview Data Curator           Data Stewards
Purview Account            Purview Data Reader            All Users
Fabric Capacity            Fabric Capacity Admin          Platform-Operators
Fabric Capacity            Fabric Capacity Contributor    Data Analysts
```

### Modern Platform Specific Roles

#### Azure Kubernetes Service
- **Azure Kubernetes Service Cluster Admin**: Full cluster management
- **Azure Kubernetes Service Cluster User**: Deploy and manage workloads
- **Azure Kubernetes Service RBAC Reader**: Read-only access to cluster resources

#### Azure Machine Learning
- **AzureML Data Scientist**: Create experiments, train models
- **AzureML Compute Operator**: Manage compute instances and clusters
- **AzureML Model Operator**: Deploy and manage models

#### Microsoft Purview
- **Purview Data Curator**: Full data catalog management
- **Purview Data Reader**: Read access to data catalog
- **Purview Data Source Administrator**: Register and scan data sources

#### Microsoft Fabric
- **Fabric Capacity Admin**: Manage Fabric capacity settings
- **Fabric Capacity Contributor**: Create workspaces and items
- **Fabric Capacity Reader**: View capacity metrics and usage

## Environment-Specific Rules

### Development (dev)
- All security groups active
- Full access for Platform-Admins
- Developer group has Contributor access

### System Integration Testing (sit)
- Restricted admin access
- Developer group has Contributor access
- No direct Key Vault secret access

### Production (prod)
- No direct admin access
- No developer access
- All changes through CI/CD
- Strict RBAC enforcement

## Implementation

### 1. Infrastructure Deployment
```bash
# Deploy Managed Identities
az deployment group create \
  --resource-group rg-dataplatform-dev \
  --template-file infra/modules/identities/managedIdentities.bicep \
  --parameters @infra/params/dev.identities.parameters.json

# Deploy RBAC assignments
az deployment group create \
  --resource-group rg-dataplatform-dev \
  --template-file infra/modules/identities/rbac.bicep \
  --parameters @infra/params/dev.identities.parameters.json
```

### 2. Security Group Management
```bash
# Create security groups
./scripts/identity-management/manage-identities.sh create-group \
  --name "grp-platform-admins" \
  --description "Platform Administrators"

# Assign roles
./scripts/identity-management/manage-identities.sh assign-role \
  --resource-group "rg-dataplatform-dev" \
  --role "Owner" \
  --principal-id "<group-id>"
```

### 3. Environment Synchronization
```bash
# Sync RBAC from dev to sit
./scripts/identity-management/manage-identities.sh sync-env \
  --source-env dev \
  --target-env sit
```

## Audit and Compliance

### Regular Auditing
Run monthly RBAC audits:
```bash
./scripts/identity-management/manage-identities.sh audit \
  --resource-group "rg-dataplatform-prod"
```

### Compliance Requirements
1. Regular review of role assignments
2. Audit logging enabled
3. Just-in-Time access for admin tasks
4. Documentation of all changes

## Best Practices

1. **Least Privilege**
   - Assign minimum required permissions
   - Use custom roles when needed
   - Regular access review

2. **Managed Identities**
   - Prefer over service principals
   - Use user-assigned for shared resources
   - Implement proper rotation

3. **Security Groups**
   - Use groups over individual assignments
   - Maintain clear naming convention
   - Document group purposes

4. **Environment Separation**
   - Strict production controls
   - Different access levels per environment
   - Clear promotion path

5. **Automation**
   - Use Infrastructure as Code
   - Automate role assignments
   - Regular compliance checks

## Troubleshooting

### Common Issues

1. **Access Denied**
   ```bash
   # Check current assignments
   ./scripts/identity-management/manage-identities.sh list-roles \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Missing Permissions**
   ```bash
   # Verify managed identity status
   ./scripts/identity-management/manage-identities.sh list-mi \
     --resource-group "rg-dataplatform-dev"
   ```

3. **Role Assignment Failures**
   - Check principal ID exists
   - Verify scope is correct
   - Confirm role definition is valid

## Security Contacts

- **Platform Security Team**: platform-security@company.com
- **Identity Management**: identity-team@company.com
- **Emergency Access**: security-emergency@company.com
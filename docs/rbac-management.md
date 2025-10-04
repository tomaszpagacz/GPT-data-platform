# RBAC and Managed Identities Management Guide

This guide outlines the RBAC (Role-Based Access Control) and Managed Identities implementation for the Data Platform project.

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
Storage Account            Storage Blob Data Owner        Platform-Operators
Cognitive Services         Cognitive Services User        Functions MI
Azure Maps                 Azure Maps Data Reader         Functions MI
```

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
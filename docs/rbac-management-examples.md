y# RBAC Management Guide for Administrators and Developers

This guide provides practical examples and instructions for managing RBAC in the Data Platform project.

## Quick Start

### 1. Initialize RBAC for a New Environment

```bash
# Initialize dev environment
./scripts/identity-management/manage-rbac.sh init -e dev

# Initialize sit environment
./scripts/identity-management/manage-rbac.sh init -e sit
```

### 2. List Current Assignments

```bash
# List all assignments in dev
./scripts/identity-management/manage-rbac.sh list -e dev
```

## Common Tasks

### Adding New Team Members

1. Add to Platform Admins:
```bash
./scripts/identity-management/manage-rbac.sh assign \
  -g "platform-admins-dev" \
  -r "Owner" \
  -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
```

2. Add to Development Team:
```bash
./scripts/identity-management/manage-rbac.sh assign \
  -g "platform-developers-dev" \
  -r "Contributor" \
  -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
```

3. Add Data Contributor:
```bash
./scripts/identity-management/manage-rbac.sh assign \
  -g "data-contributors-dev" \
  -r "Storage Blob Data Contributor" \
  -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.Storage/storageAccounts/{storage-name}"
```

### Managing Key Vault Access

1. Grant Secret Management:
```bash
./scripts/identity-management/manage-rbac.sh assign \
  -g "platform-admins-dev" \
  -r "Key Vault Administrator" \
  -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.KeyVault/vaults/{kv-name}"
```

2. Grant Secret Read Access:
```bash
./scripts/identity-management/manage-rbac.sh assign \
  -g "platform-developers-dev" \
  -r "Key Vault Secrets User" \
  -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.KeyVault/vaults/{kv-name}"
```

## Environment Management

### Synchronizing Environments

1. Basic Sync (with safety checks):
```bash
./scripts/identity-management/manage-rbac.sh sync -e dev
# Will prompt for target environment
```

2. Audit Before Sync:
```bash
# Check current state
./scripts/identity-management/manage-rbac.sh audit -e dev
./scripts/identity-management/manage-rbac.sh audit -e sit

# Perform sync
./scripts/identity-management/manage-rbac.sh sync -e dev
```

### Production Safeguards

1. Review Production Access:
```bash
./scripts/identity-management/manage-rbac.sh list -e prod
```

2. Generate Audit Report:
```bash
./scripts/identity-management/manage-rbac.sh audit -e prod
```

## Role Definitions

### Standard Roles

1. **Platform Administrator**
   - Owner at resource group level
   - Key Vault Administrator
   ```bash
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "platform-admins-dev" \
     -r "Owner" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
   ```

2. **Developer**
   - Contributor at resource group level
   - Key Vault Secrets User
   ```bash
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "platform-developers-dev" \
     -r "Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
   ```

3. **Data Contributor**
   - Storage Blob Data Contributor
   - Synapse SQL Admin
   ```bash
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "data-contributors-dev" \
     -r "Storage Blob Data Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
   ```

### Service-Specific Roles

1. **Azure Functions**
   ```bash
   # Grant Key Vault access
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "{function-managed-identity}" \
     -r "Key Vault Secrets User" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.KeyVault/vaults/{kv-name}"

   # Grant Storage access
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "{function-managed-identity}" \
     -r "Storage Blob Data Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.Storage/storageAccounts/{storage-name}"
   ```

2. **Logic Apps**
   ```bash
   # Grant Function access
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "{logicapp-managed-identity}" \
     -r "Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev/providers/Microsoft.Web/sites/{function-name}"
   ```

## Best Practices

1. **Regular Auditing**
   ```bash
   # Monthly audit
   for env in dev sit prod; do
     ./scripts/identity-management/manage-rbac.sh audit -e $env
   done
   ```

2. **Access Review**
   ```bash
   # List all assignments
   ./scripts/identity-management/manage-rbac.sh list -e dev

   # Remove unnecessary access
   ./scripts/identity-management/manage-rbac.sh revoke \
     -g "user-or-group-id" \
     -r "role-name" \
     -s "resource-scope"
   ```

3. **Environment Promotion**
   ```bash
   # Review current state
   ./scripts/identity-management/manage-rbac.sh list -e dev
   
   # Sync to SIT
   ./scripts/identity-management/manage-rbac.sh sync -e dev
   # Enter 'sit' when prompted
   
   # Verify SIT state
   ./scripts/identity-management/manage-rbac.sh list -e sit
   ```

## Troubleshooting

### Common Issues

1. **Access Denied**
   ```bash
   # Check current assignments
   ./scripts/identity-management/manage-rbac.sh list -e dev

   # Verify group membership
   az ad group member list --group "platform-developers-dev"
   ```

2. **Missing Permissions**
   ```bash
   # Generate audit report
   ./scripts/identity-management/manage-rbac.sh audit -e dev

   # Check specific scope
   az role assignment list --scope "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev" -o table
   ```

### Emergency Access

1. **Grant Temporary Access**
   ```bash
   # Grant temporary contributor access
   ./scripts/identity-management/manage-rbac.sh assign \
     -g "user-id" \
     -r "Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev" \
     --end-date "2025-12-31"
   ```

2. **Remove Emergency Access**
   ```bash
   ./scripts/identity-management/manage-rbac.sh revoke \
     -g "user-id" \
     -r "Contributor" \
     -s "/subscriptions/{sub-id}/resourceGroups/rg-dataplatform-dev"
   ```

## Compliance and Reporting

1. **Generate Reports**
   ```bash
   # Full audit across environments
   for env in dev sit prod; do
     ./scripts/identity-management/manage-rbac.sh audit -e $env
   done
   ```

2. **Review Changes**
   ```bash
   # Compare with previous audit
   diff rbac-audit-dev-20251003.csv rbac-audit-dev-20251004.csv
   ```

Remember to always follow the principle of least privilege and regularly review access patterns. Use the audit functionality to maintain compliance and security standards.
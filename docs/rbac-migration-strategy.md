# RBAC Migration Strategy

## Current State Analysis

The repository contains existing RBAC-related files that need to be handled during the migration to the new comprehensive RBAC system:

### Existing RBAC Files

| File Path | Purpose | Status | Action Required |
|-----------|---------|--------|-----------------|
| `infra/modules/identities/rbac.bicep` | Legacy generic RBAC module | 🔄 Replace | **Deprecate & Replace** |
| `infra/modules/identities/rbac.json` | Compiled ARM template | 🗑️ Build artifact | **Remove** |
| `infra/build_output/infra/modules/identities/rbac.json` | Build artifact | 🗑️ Build artifact | **Remove** |
| `infra/params/rbac-assignments.parameters.json` | Legacy parameter file | 🔄 Replace | **Migrate & Archive** |
| `scripts/identity-management/manage-rbac.sh` | Manual RBAC management script | ⚠️ Legacy tool | **Archive & Document** |

### Current RBAC System Limitations

The existing RBAC implementation has several limitations compared to the new system:

1. **Generic Approach**: The old `identities/rbac.bicep` is a generic role assignment module that requires manual configuration
2. **No Resource-Specific Logic**: Doesn't understand the specific needs of different Azure services
3. **Manual Parameter Management**: Requires complex parameter files with hardcoded role assignments
4. **No Modern Service Support**: Doesn't include roles for AKS, ML, Purview, Fabric, Container Instances
5. **Limited Validation**: No built-in validation of role compatibility with resources

## Migration Strategy

### Phase 1: Preserve Legacy (✅ Completed)
- New comprehensive RBAC module (`rbacAssignments.bicep`) implemented
- New system runs alongside existing files without conflicts
- No existing deployments are affected

### Phase 2: Migration Path

#### 2.1. Update Parameter Files
The existing parameter structure needs to be migrated:

**Old Format** (`rbac-assignments.parameters.json`):
```json
{
  "roleAssignments": {
    "value": [
      {
        "name": "platform-admins-owner",
        "principalId": "${PLATFORM_ADMINS_GROUP_ID}",
        "roleDefinition": "owner",
        "principalType": "Group"
      }
    ]
  }
}
```

**New Format** (integrated in `main.parameters.json`):
```json
{
  "securityGroups": {
    "value": {
      "platformAdmins": "actual-object-id",
      "platformOperators": "actual-object-id"
    }
  }
}
```

#### 2.2. Script Migration
The `manage-rbac.sh` script should be replaced with Azure CLI commands that work with the new system:

**Old Approach**: Manual role assignment via script
**New Approach**: Declarative RBAC via Bicep deployment

### Phase 3: Deprecation Timeline

#### Immediate Actions (✅ Completed)
- [x] New RBAC system implemented and tested
- [x] Documentation updated with migration instructions
- [x] Example parameter files provided

#### Short Term (Next Sprint)
- [ ] Update deployment pipelines to use new RBAC system
- [ ] Migrate existing parameter files to new format
- [ ] Create migration validation script

#### Medium Term (1-2 Sprints)
- [ ] Archive legacy RBAC files to `legacy/` directory
- [ ] Update all deployment documentation
- [ ] Remove references to old RBAC system

#### Long Term (3+ Sprints)
- [ ] Remove legacy files entirely (after validation)
- [ ] Clean up build artifacts
- [ ] Update training materials

## Recommended Actions

### 1. Immediate (Safe Migration)

Create a migration script to preserve existing assignments:

```bash
#!/bin/bash
# migration-rbac.sh

echo "Migrating RBAC configuration..."

# Step 1: Backup existing assignments
az role assignment list --output json > rbac-backup-$(date +%Y%m%d).json

# Step 2: Deploy new RBAC system
az deployment sub create \
  --location "Switzerland North" \
  --template-file infra/main.bicep \
  --parameters @infra/params/dev.main.parameters.json

# Step 3: Validate assignments
az deployment sub show --name "deployment-name" \
  --query properties.outputs.rbacAssignmentStatus.value
```

### 2. Archive Legacy Files

Move existing files to preserve history:

```bash
# Create legacy directory
mkdir -p infra/legacy/modules/identities
mkdir -p infra/legacy/params
mkdir -p scripts/legacy

# Move legacy files
mv infra/modules/identities/rbac.bicep infra/legacy/modules/identities/
mv infra/modules/identities/rbac.json infra/legacy/modules/identities/
mv infra/params/rbac-assignments.parameters.json infra/legacy/params/
mv scripts/identity-management/manage-rbac.sh scripts/legacy/
```

### 3. Update Documentation

Update deployment guides to reference the new system:

- [x] RBAC Implementation Guide created
- [ ] Update existing deployment documentation
- [ ] Add migration notes to README files

## Validation Steps

After migration, validate the new system:

### 1. Deployment Validation
```bash
# Deploy with new RBAC system
az deployment sub create \
  --template-file infra/main.bicep \
  --parameters @infra/params/dev.main.parameters.json

# Check RBAC assignment status
az deployment sub show --name "deployment-name" \
  --query properties.outputs.rbacAssignmentStatus.value
```

### 2. Permission Validation
```bash
# Test storage access
az storage blob list --account-name "storage-account-name" --container-name "raw"

# Test Key Vault access
az keyvault secret list --vault-name "key-vault-name"

# Test AKS access
kubectl get nodes
```

### 3. Functional Testing
- [ ] Functions can access Key Vault secrets
- [ ] Logic Apps can invoke Functions
- [ ] AKS can pull container images from storage
- [ ] ML workspace can access training data
- [ ] Purview can scan data sources
- [ ] Fabric can connect to Synapse

## Risk Mitigation

### 1. Rollback Plan
- Keep existing role assignments until new system is validated
- Maintain backup of current RBAC state
- Implement gradual migration per resource type

### 2. Testing Strategy
- Deploy to development environment first
- Validate all service integrations
- Performance test with real workloads
- Security validation with penetration testing

### 3. Communication Plan
- Notify all stakeholders of migration timeline
- Provide training on new RBAC system
- Document troubleshooting procedures
- Establish support channels during migration

## Benefits of New System

### 1. Automated & Consistent
- No manual role assignment needed
- Consistent permissions across environments
- Reduced human error

### 2. Comprehensive Coverage
- All modern Azure services supported
- Service-specific role optimization
- Future-proof architecture

### 3. Maintainable
- Single source of truth for RBAC
- Clear documentation and examples
- Easy to audit and validate

### 4. Secure
- Principle of least privilege enforced
- No over-privileged assignments
- Built-in security validation

## Conclusion

The new RBAC system provides significant improvements over the legacy implementation. The migration should be performed gradually with proper validation at each step. The legacy files should be archived rather than deleted to preserve institutional knowledge and enable rollback if needed.

**Next Steps:**
1. Review and approve this migration strategy
2. Schedule migration timeline
3. Begin with development environment migration
4. Gradually roll out to higher environments
5. Archive legacy files after successful validation
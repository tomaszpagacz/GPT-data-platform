# Parameter Configuration Guide

## Security Groups Configuration

The `securityGroups` parameter in parameter files accepts Azure AD Security Group Object IDs for RBAC assignments.

### How to Find Security Group Object IDs

1. Go to **Azure Portal** > **Azure Active Directory** > **Groups**
2. Select the desired security group
3. In the **Overview** tab, copy the **Object ID**

### Available Security Group Roles

- `platformAdmins`: Full administrative access to all platform resources
- `platformOperators`: Operational access for monitoring and maintenance
- `platformDevelopers`: Development and deployment access
- `platformReaders`: Read-only access to platform resources
- `mlEngineers`: Access to Machine Learning workspaces and resources
- `dataAnalysts`: Access to analytics and reporting tools
- `dataScientists`: Advanced analytics and data science access
- `dataEngineers`: Data processing and pipeline access
- `dataGovernanceTeam`: Data governance and compliance access

### Configuration

Replace empty strings (`""`) with actual Object IDs:

```json
"securityGroups": {
  "value": {
    "platformAdmins": "12345678-1234-1234-1234-123456789012",
    "platformOperators": "87654321-4321-4321-4321-210987654321",
    // ... other groups
  }
}
```

Leave as empty strings to skip RBAC assignments for specific roles.
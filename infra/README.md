# Key Vault Secrets Management

This directory contains templates and parameters for managing secrets across different environments (dev, sit, prod).

## Quick Start

### Adding a New Secret

1. Add the secret to all environment parameter files with a dummy value:
   ```bash
   # Edit these files:
   infra/params/dev.keyvaultsecrets.parameters.json
   infra/params/sit.keyvaultsecrets.parameters.json
   infra/params/prod.keyvaultsecrets.parameters.json
   ```

2. Add the actual secret to Azure DevOps/GitHub:
   - Go to Azure DevOps Pipeline Library
   - Select the appropriate variable group (dev/sit/prod)
   - Add your secret with the same name as in parameters file

### Updating Existing Secrets

1. Use Azure CLI:
   ```bash
   # Development environment (direct update)
   az keyvault secret set --vault-name "prefix-dev-kv" --name "YourSecretName" --value "YourSecretValue"

   # SIT/PROD environments (via pipeline)
   # Update the secret in Azure DevOps/GitHub variable groups and run the pipeline
   ```

## Structure

```plaintext
infra/
├── modules/
│   ├── keyVault.bicep          # Key Vault infrastructure
│   └── keyVaultSecrets.bicep   # Secret management
├── params/
│   ├── dev.keyvaultsecrets.parameters.json    # Development
│   ├── sit.keyvaultsecrets.parameters.json    # SIT
│   └── prod.keyvaultsecrets.parameters.json   # Production
```

## Common Tasks

### 1. Adding Application Secrets

```json
// Add to params/[env].keyvaultsecrets.parameters.json
{
  "parameters": {
    "secrets": {
      "value": {
        "YourApp-ApiKey": "dummy-api-key-replaced-by-pipeline",
        "YourApp-ConnectionString": "dummy-connection-replaced-by-pipeline"
      }
    }
  }
}
```

### 2. Rotating Secrets

1. Update the secret in Azure DevOps/GitHub variable groups
2. Run the deployment pipeline
3. Update your application configuration if needed

### 3. Secret Naming Conventions

Follow these patterns for consistent secret management:
- Database Credentials: `[ServiceName]-[Database]-[User]`
- API Keys: `[ServiceName]-ApiKey`
- Connection Strings: `[ServiceName]-ConnectionString`
- Certificates: `[ServiceName]-[CertName]-[Type]`

Examples:
```json
{
  "Synapse-SqlAdmin-Password": "dummy-password",
  "EventGrid-ApiKey": "dummy-key",
  "Storage-ConnectionString": "dummy-connection"
}
```

## Security Guidelines

1. Never commit real secret values to source control
2. Use pipeline variables for actual values
3. Follow least privilege access:
   - Dev: Full access for developers
   - SIT: Read access for developers
   - Prod: No direct access, pipeline-only

## Troubleshooting

Common issues and solutions:

1. Secret Deployment Failures
   ```bash
   # Verify Key Vault access
   az keyvault show --name "prefix-dev-kv"
   
   # Check your permissions
   az role assignment list --assignee "[your-email]" --scope "[key-vault-id]"
   ```

2. Pipeline Variable Issues
   - Ensure variable group is linked to pipeline
   - Check variable name matches parameter file
   - Verify pipeline has access to variable group

## Development Workflow

1. Local Development:
   ```bash
   # Deploy with dummy values for testing
   az deployment group create \
     --resource-group rg-data-platform-dev \
     --template-file infra/modules/keyVaultSecrets.bicep \
     --parameters infra/params/dev.keyvaultsecrets.parameters.json
   ```

2. Pipeline Deployment:
   - Push changes to parameter files
   - Pipeline automatically replaces dummy values
   - Secrets deployed to appropriate environment
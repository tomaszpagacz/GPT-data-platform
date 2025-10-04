@description('Name of the Key Vault where secrets will be stored.')
param keyVaultName string

@description('Environment name (dev, sit, prod).')
@allowed([
  'dev'
  'sit'
  'prod'
])
param environment string

@description('''
Optional secrets to create in Key Vault. Structure: { secretName: secretValue }
Example:
{
  "Synapse-SqlAdmin-Password": "dummy-password",
  "Storage-DataLake-Key": "dummy-key"
}

Best Practices for Secret Names:
- Use service prefix: "ServiceName-SecretType"
- Common types: Password, Key, ConnectionString, ApiKey
- Use hyphens (-) for separators
- Be consistent with casing

Example secret names:
- Synapse-SqlAdmin-Password
- Storage-DataLake-Key
- EventGrid-Topic-Key
- Functions-StorageKey
''')
@secure()
param secrets object = {}

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' existing = {
  name: keyVaultName
}

// Create secrets based on provided values
resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = [for secretName in items(secrets): {
  parent: keyVault
  name: secretName.key
  properties: {
    value: secretName.value
    contentType: environment // Tag secret with environment for tracking
    attributes: {
      enabled: true
    }
  }
}]

@description('Returns the Key Vault ID for reference')
output keyVaultId string = keyVault.id

@description('Returns a list of created secret names')
output createdSecrets array = [for secret in items(secrets): secret.key]
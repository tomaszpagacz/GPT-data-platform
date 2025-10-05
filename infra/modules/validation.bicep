targetScope = 'subscription'

@description('Validates input parameters for the infrastructure deployment')
param namePrefix string
param environment string

// Validate name lengths
var storageNameLength = length('${namePrefix}${environment}dls')
var funcStorageNameLength = length('${namePrefix}${environment}funcsa')
var keyVaultNameLength = length('${namePrefix}-${environment}-kv')

// Storage accounts must be between 3 and 24 characters
var storageNameValid = and(
  storageNameLength <= 24,
  storageNameLength >= 3
)
var funcStorageNameValid = and(
  funcStorageNameLength <= 24,
  funcStorageNameLength >= 3
)

// Key Vault names must be between 3 and 24 characters
var keyVaultNameValid = and(
  keyVaultNameLength <= 24,
  keyVaultNameLength >= 3
)

// Validate name patterns
var validNamePattern = '^[a-zA-Z0-9-]*$'
var namePatternValid = match(namePrefix, validNamePattern)
var envPatternValid = match(environment, validNamePattern)

// Output validation results
output validationPassed bool = and(
  storageNameValid,
  funcStorageNameValid,
  keyVaultNameValid,
  namePatternValid,
  envPatternValid
)

output validationErrors array = [for item in [
  {
    check: 'Storage Account Name Length'
    valid: storageNameValid
    value: storageNameLength
    message: 'Storage account name must be between 3 and 24 characters'
  }
  {
    check: 'Function Storage Name Length'
    valid: funcStorageNameValid
    value: funcStorageNameLength
    message: 'Function storage account name must be between 3 and 24 characters'
  }
  {
    check: 'Key Vault Name Length'
    valid: keyVaultNameValid
    value: keyVaultNameLength
    message: 'Key Vault name must be between 3 and 24 characters'
  }
  {
    check: 'Name Prefix Pattern'
    valid: namePatternValid
    value: namePrefix
    message: 'Name prefix must contain only alphanumeric characters and hyphens'
  }
  {
    check: 'Environment Name Pattern'
    valid: envPatternValid
    value: environment
    message: 'Environment name must contain only alphanumeric characters and hyphens'
  }
]: if (!item.valid) { 
  item
}]
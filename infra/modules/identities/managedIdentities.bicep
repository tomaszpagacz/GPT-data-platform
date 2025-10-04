@description('Location for the resources.')
param location string = resourceGroup().location

@description('Environment name (dev, sit, prod)')
@allowed([
  'dev'
  'sit'
  'prod'
])
param environment string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Array of user-assigned managed identities to create')
param userAssignedIdentities array = []

// Resource naming
var naming = {
  systemMI: 'id-system-${environment}'
  userMI: 'id-user-${environment}'
}

// Create system-assigned managed identity for the platform
resource systemAssignedMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: naming.systemMI
  location: location
  tags: union({
    environment: environment
    managedBy: 'bicep'
  }, tags)
}

// Create user-assigned managed identities based on input array
resource userAssignedMIs 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for identity in userAssignedIdentities: {
  name: '${naming.userMI}-${identity.name}'
  location: location
  tags: union({
    environment: environment
    managedBy: 'bicep'
    purpose: identity.?purpose ?? 'unknown'
    application: identity.?application ?? 'undefined'
  }, tags)
}]

// Output the managed identity details
output systemAssignedMIId string = systemAssignedMI.id
output systemAssignedMIPrincipalId string = systemAssignedMI.properties.principalId
output userAssignedMIIds array = [for (identity, i) in userAssignedIdentities: {
  name: identity.name
  id: userAssignedMIs[i].id
  principalId: userAssignedMIs[i].properties.principalId
}]
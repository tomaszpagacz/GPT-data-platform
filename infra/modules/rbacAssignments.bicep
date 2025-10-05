@description('Storage Account resource ID for RBAC assignments')
param storageAccountId string

@description('Key Vault resource ID for RBAC assignments')
param keyVaultId string

@description('Synapse Workspace resource ID for RBAC assignments')
param synapseWorkspaceId string

@description('AKS Cluster resource ID for RBAC assignments')
param aksClusterId string

@description('Machine Learning Workspace resource ID for RBAC assignments')
param mlWorkspaceId string

@description('Purview Account resource ID for RBAC assignments')
param purviewAccountId string

@description('Fabric Capacity resource ID for RBAC assignments')
param fabricCapacityId string

@description('Whether AKS is deployed')
param deployAKS bool = false

@description('Whether Machine Learning is deployed')
param deployMachineLearning bool = false

@description('Whether Purview is deployed')
param deployPurview bool = false

@description('Whether Fabric is deployed')
param deployFabric bool = false

@description('Managed Identity Principal IDs')
param managedIdentities object

@description('Security Group Object IDs')
param securityGroups object

// Get existing resource references for RBAC scope
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: last(split(synapseWorkspaceId, '/'))
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' existing = if (deployAKS) {
  name: last(split(aksClusterId, '/'))
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' existing = if (deployMachineLearning) {
  name: last(split(mlWorkspaceId, '/'))
}

resource purviewAccount 'Microsoft.Purview/accounts@2021-12-01' existing = if (deployPurview) {
  name: last(split(purviewAccountId, '/'))
}

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' existing = if (deployFabric) {
  name: last(split(fabricCapacityId, '/'))
}

// Built-in Azure Role Definitions
var roles = {
  storageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageBlobDataReader: 'e9dba6fb-3d52-4bd0-9de6-3d48f1a77c50'
  keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  keyVaultCryptoOfficer: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  azureKubernetesServiceContributorRole: 'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8'
  azureKubernetesServiceClusterAdminRole: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
  azureMLDataScientist: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  azureMLComputeOperator: 'e503ece1-11d0-4e8e-8e2c-e5c5e8b8ced1'
  purviewDataCurator: '8a3c2885-9b38-4fd2-9d99-91d02d8c0800'
  purviewDataReader: '05d8164f-58ad-4a58-8034-b3e2dedddbf5'
  fabricAdministrator: '1d9b5dd5-7f00-479c-a9a0-b2ea2ca8bfe2'
  fabricCapacityAdmin: '4c7c8a82-6af6-4b8b-90c3-e7b5c9e3d8e9'
  synapseAdministrator: '6e4bf58d-b8f4-4cc5-8ff6-b44e0b568dcc'
  synapseContributor: '7af0c69a-a548-47d6-aea3-d00e69bd83aa'
  synapseComputeOperator: 'b9e6b3ad-d08a-4a29-aea7-78e2dd4e1b90'
}

// ===========================================
// STORAGE ACCOUNT RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Storage Blob Data Owner
resource storageOwnerOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: storageAccount
  name: guid(storageAccountId, securityGroups.platformOperators, 'StorageBlobDataOwner')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataOwner)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Storage Blob Data Contributor
resource storageContributorDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: storageAccount
  name: guid(storageAccountId, securityGroups.dataEngineers, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// Function App - Storage Blob Data Contributor
resource storageContributorFunctions 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.functions)) {
  scope: storageAccount
  name: guid(storageAccountId, managedIdentities.functions, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: managedIdentities.functions
    principalType: 'ServicePrincipal'
  }
}

// Logic Apps - Storage Blob Data Contributor
resource storageContributorLogicApps 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.logicApps)) {
  scope: storageAccount
  name: guid(storageAccountId, managedIdentities.logicApps, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: managedIdentities.logicApps
    principalType: 'ServicePrincipal'
  }
}

// AKS - Storage Blob Data Contributor
resource storageContributorAKS 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.aks)) {
  scope: storageAccount
  name: guid(storageAccountId, managedIdentities.aks, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: managedIdentities.aks
    principalType: 'ServicePrincipal'
  }
}

// Purview - Storage Blob Data Reader
resource storageReaderPurview 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.purview)) {
  scope: storageAccount
  name: guid(storageAccountId, managedIdentities.purview, 'StorageBlobDataReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataReader)
    principalId: managedIdentities.purview
    principalType: 'ServicePrincipal'
  }
}

// ===========================================
// KEY VAULT RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Key Vault Secrets Officer
resource keyVaultSecretsOfficerOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: keyVault
  name: guid(keyVaultId, securityGroups.platformOperators, 'KeyVaultSecretsOfficer')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsOfficer)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Function App - Key Vault Secrets User
resource keyVaultSecretsUserFunctions 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.functions)) {
  scope: keyVault
  name: guid(keyVaultId, managedIdentities.functions, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: managedIdentities.functions
    principalType: 'ServicePrincipal'
  }
}

// Logic Apps - Key Vault Secrets User
resource keyVaultSecretsUserLogicApps 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.logicApps)) {
  scope: keyVault
  name: guid(keyVaultId, managedIdentities.logicApps, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: managedIdentities.logicApps
    principalType: 'ServicePrincipal'
  }
}

// ML Workspace - Key Vault Crypto Officer
resource keyVaultCryptoOfficerML 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.ml)) {
  scope: keyVault
  name: guid(keyVaultId, managedIdentities.ml, 'KeyVaultCryptoOfficer')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultCryptoOfficer)
    principalId: managedIdentities.ml
    principalType: 'ServicePrincipal'
  }
}

// AKS - Key Vault Secrets User
resource keyVaultSecretsUserAKS 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.aks)) {
  scope: keyVault
  name: guid(keyVaultId, managedIdentities.aks, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: managedIdentities.aks
    principalType: 'ServicePrincipal'
  }
}

// Purview - Key Vault Secrets User
resource keyVaultSecretsUserPurview 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.purview)) {
  scope: keyVault
  name: guid(keyVaultId, managedIdentities.purview, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: managedIdentities.purview
    principalType: 'ServicePrincipal'
  }
}

// ===========================================
// AKS RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Azure Kubernetes Service Cluster Admin Role
resource aksClusterAdminOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: aksCluster
  name: guid(aksClusterId, securityGroups.platformOperators, 'AzureKubernetesServiceClusterAdminRole')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureKubernetesServiceClusterAdminRole)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Azure Kubernetes Service Contributor Role
resource aksContributorDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: aksCluster
  name: guid(aksClusterId, securityGroups.dataEngineers, 'AzureKubernetesServiceContributorRole')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureKubernetesServiceContributorRole)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// ===========================================
// MACHINE LEARNING RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Azure ML Data Scientist
resource mlDataScientistOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: mlWorkspace
  name: guid(mlWorkspaceId, securityGroups.platformOperators, 'AzureMLDataScientist')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureMLDataScientist)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Azure ML Compute Operator
resource mlComputeOperatorDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: mlWorkspace
  name: guid(mlWorkspaceId, securityGroups.dataEngineers, 'AzureMLComputeOperator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureMLComputeOperator)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// ===========================================
// PURVIEW RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Purview Data Curator
resource purviewDataCuratorOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: purviewAccount
  name: guid(purviewAccountId, securityGroups.platformOperators, 'PurviewDataCurator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.purviewDataCurator)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Purview Data Reader
resource purviewDataReaderDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: purviewAccount
  name: guid(purviewAccountId, securityGroups.dataEngineers, 'PurviewDataReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.purviewDataReader)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// ===========================================
// FABRIC RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Fabric Administrator
resource fabricAdministratorOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: fabricCapacity
  name: guid(fabricCapacityId, securityGroups.platformOperators, 'FabricAdministrator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.fabricAdministrator)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Fabric Capacity Admin
resource fabricCapacityAdminDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: fabricCapacity
  name: guid(fabricCapacityId, securityGroups.dataEngineers, 'FabricCapacityAdmin')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.fabricCapacityAdmin)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// ===========================================
// SYNAPSE RBAC ASSIGNMENTS
// ===========================================

// Platform Operators - Synapse Administrator
resource synapseAdministratorOperators 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.platformOperators)) {
  scope: synapseWorkspace
  name: guid(synapseWorkspaceId, securityGroups.platformOperators, 'SynapseAdministrator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.synapseAdministrator)
    principalId: securityGroups.platformOperators
    principalType: 'Group'
  }
}

// Data Engineers - Synapse Contributor
resource synapseContributorDataEngineers 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(securityGroups.dataEngineers)) {
  scope: synapseWorkspace
  name: guid(synapseWorkspaceId, securityGroups.dataEngineers, 'SynapseContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.synapseContributor)
    principalId: securityGroups.dataEngineers
    principalType: 'Group'
  }
}

// Function App - Synapse Compute Operator
resource synapseComputeOperatorFunctions 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.functions)) {
  scope: synapseWorkspace
  name: guid(synapseWorkspaceId, managedIdentities.functions, 'SynapseComputeOperator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.synapseComputeOperator)
    principalId: managedIdentities.functions
    principalType: 'ServicePrincipal'
  }
}

// ML Workspace - Synapse Contributor
resource synapseContributorML 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentities.ml)) {
  scope: synapseWorkspace
  name: guid(synapseWorkspaceId, managedIdentities.ml, 'SynapseContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.synapseContributor)
    principalId: managedIdentities.ml
    principalType: 'ServicePrincipal'
  }
}

// ===========================================
// OUTPUTS
// ===========================================

output rbacAssignmentsSummary object = {
  storageAccount: {
    platformOperators: storageOwnerOperators.name
    functions: storageContributorFunctions.name
    logicApps: storageContributorLogicApps.name
    aks: storageContributorAKS.name
    purview: storageReaderPurview.name
  }
  keyVault: {
    platformOperators: keyVaultSecretsOfficerOperators.name
    functions: keyVaultSecretsUserFunctions.name
    logicApps: keyVaultSecretsUserLogicApps.name
    ml: keyVaultCryptoOfficerML.name
    aks: keyVaultSecretsUserAKS.name
    purview: keyVaultSecretsUserPurview.name
  }
  aksCluster: {
    platformOperators: aksClusterAdminOperators.name
    dataEngineers: aksContributorDataEngineers.name
  }
  mlWorkspace: {
    platformOperators: mlDataScientistOperators.name
    dataEngineers: mlComputeOperatorDataEngineers.name
  }
  purviewAccount: {
    platformOperators: purviewDataCuratorOperators.name
    dataEngineers: purviewDataReaderDataEngineers.name
  }
  fabricCapacity: {
    platformOperators: fabricAdministratorOperators.name
    dataEngineers: fabricCapacityAdminDataEngineers.name
  }
  synapseWorkspace: {
    platformOperators: synapseAdministratorOperators.name
    dataEngineers: synapseContributorDataEngineers.name
    functions: synapseComputeOperatorFunctions.name
    ml: synapseContributorML.name
  }
}

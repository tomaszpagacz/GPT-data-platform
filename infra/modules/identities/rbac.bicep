@description('Array of role assignments to create')
param roleAssignments array

@description('Environment name (dev, sit, prod)')
@allowed([
  'dev'
  'sit'
  'prod'
])
param environment string

@description('Role assignments to skip in specific environments')
param environmentExclusions object = {
  dev: []
  sit: []
  prod: []
}

// Local Variables
var excludedAssignments = contains(environmentExclusions, environment) ? environmentExclusions[environment] : []

// Role Definitions
var roleDefinitions = {
  owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  storageAccountContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  storageBlobDataOwner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  storageBlobDataContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  keyVaultAdministrator: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
  keyVaultSecretsUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  cognitiveServicesUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  azureMapsDataReader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '423170ca-a8f6-4b0f-8487-9e4eb8f49bfa')
  logicAppContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '87a39d53-fc1b-424a-814c-f7e04687dc9e')
}

// Create role assignments
resource rbacAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in roleAssignments: if (!contains(excludedAssignments, assignment.name)) {
  name: guid(resourceGroup().id, assignment.principalId, assignment.roleDefinitionId)
  properties: {
    principalId: assignment.principalId
    roleDefinitionId: contains(roleDefinitions, assignment.roleDefinition) ? roleDefinitions[assignment.roleDefinition] : assignment.roleDefinition
    description: contains(assignment, 'description') ? assignment.description : 'Role assignment created by Bicep'
    principalType: contains(assignment, 'principalType') ? assignment.principalType : 'ServicePrincipal'
  }
}]

output assignedRoles array = [for (assignment, i) in roleAssignments: !contains(excludedAssignments, assignment.name) ? {
  name: assignment.name
  principalId: assignment.principalId
  roleDefinition: assignment.roleDefinition
  assignmentId: rbacAssignments[i].id
} : null]
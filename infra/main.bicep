@description('Azure region for all resources. Defaults to Switzerland North to satisfy data residency requirements.')
param location string = 'switzerlandnorth'

@description('Location used for the Azure Maps account (Azure Maps is a global resource). Leave empty to use global location parameter.')
param azureMapsLocation string = 'global'

@description('Location for Azure Machine Learning workspace. Leave empty to use global location parameter.')
param machineLearningLocation string = ''

@description('Location for Azure Kubernetes Service. Leave empty to use global location parameter.')
param aksLocation string = ''

@description('Location for Microsoft Fabric capacity. Leave empty to use global location parameter.')
param fabricLocation string = ''

@description('Location for Microsoft Purview account. Leave empty to use global location parameter.')
param purviewLocation string = ''

@description('Location for Azure Container Instances. Leave empty to use global location parameter.')
param containerInstancesLocation string = ''

@description('Location for Cognitive Services. Leave empty to use global location parameter.')
param cognitiveServicesLocation string = ''

@description('Prefix used for resource names. Should be 3-11 characters to comply with Azure naming rules.')
param namePrefix string

@description('Environment name suffix appended to select resources (e.g., dev, test, prod).')
param environment string

@description('Default tags applied to every resource deployed by this template.')
param tags object = {
  project: 'gpt-data-platform'
}

@description('CIDR block for the data platform virtual network.')
param vnetAddressSpace string = '10.10.0.0/21'

@description('CIDR allocations for the core subnets used by the platform.')
param subnetAddressPrefixes object = {
  functionApps: '10.10.0.0/26'
  integration: '10.10.0.64/26'
  privateEndpoints: '10.10.0.128/26'
  selfHostedIntegrationRuntime: '10.10.0.192/27'
  apim: '10.10.0.224/27'
}

@description('Name of the primary data lake filesystem created within the storage account.')
param dataLakeFilesystem string = 'raw'

// Resource naming module
module resourceNaming 'modules/naming.bicep' = {
  name: 'naming'
  params: {
    namePrefix: namePrefix
    environment: environment
  }
}

@description('Logic App Standard SKU. For VNet integration, a minimum of Standard is recommended.')
@allowed([
  'Standard'
])
param logicAppSku string = 'Standard'

@description('Azure Functions plan SKU for compute workloads that require VNet integration.')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionPlanSku string = 'EP1'

@description('Administrator login for the Synapse dedicated SQL pool (metadata operations only).')
param synapseSqlAdminLogin string

@secure()
@description('Administrator password for the Synapse dedicated SQL pool.')
param synapseSqlAdminPassword string

@description('Name of the Event Grid topic used to trigger orchestration workloads.')
param ingestionEventTopicName string = '${namePrefix}${environment}egtopic'

@description('Optional IP ranges permitted to access publicly exposed endpoints (e.g., Function App SCM). Leave empty to block public ingress.')
param allowedPublicIpRanges array = []

@description('Security Group Object IDs for RBAC assignments. Leave empty to skip group-based assignments.')
param securityGroups object = {
  platformAdmins: ''
  platformOperators: ''
  platformDevelopers: ''
  platformReaders: ''
  mlEngineers: ''
  dataAnalysts: ''
  dataScientists: ''
  dataEngineers: ''
  dataGovernanceTeam: ''
}

// ======================================
// COST OPTIMIZATION DEPLOYMENT FLAGS
// ======================================
// These parameters control which expensive resources get deployed
// Set to false to skip deployment of costly 24/7 charging resources

@description('Deploy Microsoft Fabric capacity. Charges continuously based on capacity units (F2=$525/month minimum).')
param deployFabric bool = true

@description('Deploy Azure Kubernetes Service. Charges for node VMs 24/7 (~$420/month minimum for 3 nodes).')
param deployAKS bool = true

@description('Deploy Azure Machine Learning workspace with compute. ML compute instances charge continuously.')
param deployMachineLearning bool = true

@description('Deploy Microsoft Purview for data governance. Charges for capacity units continuously (~$400/month minimum).')
param deployPurview bool = true

@description('Deploy Synapse dedicated SQL pools. Dedicated pools charge continuously unlike serverless (~$1200/month for DW100c).')
param deploySynapseDedicatedSQL bool = false

@description('Deploy Self-Hosted Integration Runtime VM. VM charges 24/7 when running (~$140/month for Standard_D2s_v3).')
param deploySHIR bool = false

@description('Deploy Azure Container Instances. ACI charges for allocated CPU/memory continuously.')
param deployContainerInstances bool = true

@description('Deploy Logic Apps Standard plan. Standard plan charges for allocated capacity (~$200/month base).')
param deployLogicApps bool = true

@description('Deploy Cognitive Services. Some tiers have minimum monthly charges.')
param deployCognitiveServices bool = true

@description('Deploy Azure Maps. Standard pricing tier has monthly minimums.')
param deployAzureMaps bool = true

var privateDnsZoneSuffixes = [
  'blob.${az.environment().suffixes.storage}'
  'dfs.${az.environment().suffixes.storage}'
  'queue.${az.environment().suffixes.storage}'
  'table.${az.environment().suffixes.storage}'
  'file.${az.environment().suffixes.storage}'
  'web.${az.environment().suffixes.storage}'
  'blob'
  'queue'
  'table'
  'file'
  'web'
  'vault.${az.environment().suffixes.keyvaultDns}'
  'vault'
  'privatelink.${az.environment().suffixes.sqlServerHostname}'
  'privatelink.database.windows.net'
  'privatelink.dfs.${az.environment().suffixes.storage}'
  'privatelink.blob.${az.environment().suffixes.storage}'
  'privatelink.queue.${az.environment().suffixes.storage}'
  'privatelink.table.${az.environment().suffixes.storage}'
  'privatelink.file.${az.environment().suffixes.storage}'
  'privatelink.web.${az.environment().suffixes.storage}'
  'privatelink.vault.${az.environment().suffixes.keyvaultDns}'
  'privatelink.eventgrid.${az.environment().suffixes.eventGridTopicHostname}'
  'privatelink.servicebus.windows.net'
  'privatelink.azurewebsites.net'
  'privatelink.blob.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.web.core.windows.net'
  'privatelink.vault.core.windows.net'
  'privatelink.eventgrid.azure.net'
  'privatelink.management.azure.com'
]

// Location override logic - use specific location if provided, otherwise use global location
var actualAzureMapsLocation = empty(azureMapsLocation) ? location : azureMapsLocation
var actualMachineLearningLocation = empty(machineLearningLocation) ? location : machineLearningLocation
var actualAksLocation = empty(aksLocation) ? location : aksLocation
var actualFabricLocation = empty(fabricLocation) ? location : fabricLocation
var actualPurviewLocation = empty(purviewLocation) ? location : purviewLocation
var actualContainerInstancesLocation = empty(containerInstancesLocation) ? location : containerInstancesLocation
var actualCognitiveServicesLocation = empty(cognitiveServicesLocation) ? location : cognitiveServicesLocation

module logging 'modules/monitoring.bicep' = {
  name: 'logging'
  params: {
    name: resourceNaming.outputs.naming.logAnalytics
    location: location
    tags: tags
  }
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    name: resourceNaming.outputs.naming.vnet
    location: location
    tags: tags
    addressSpace: vnetAddressSpace
    subnetAddressPrefixes: subnetAddressPrefixes
  }
}

module privateDns 'modules/privateDns.bicep' = {
  name: 'privateDns'
  params: {
    zoneSuffixes: privateDnsZoneSuffixes
    vnetId: networking.outputs.vnetId
    tags: tags
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    name: resourceNaming.outputs.naming.keyVault
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    allowedPublicIpRanges: allowedPublicIpRanges
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: resourceNaming.outputs.naming.storage
    location: location
    tags: tags
    filesystemName: dataLakeFilesystem
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module functionStorage 'modules/storage.bicep' = {
  name: 'functionStorage'
  params: {
    name: resourceNaming.outputs.naming.functionStorage
    location: location
    tags: union(tags, { purpose: 'functions' })
    isHnsEnabled: false
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module appHosting 'modules/appHosting.bicep' = {
  name: 'appHosting'
  params: {
    location: location
    tags: tags
    functionPlanName: resourceNaming.outputs.naming.functionPlan
    functionAppName: resourceNaming.outputs.naming.functionApp
    functionPlanSku: functionPlanSku
    functionSubnetId: networking.outputs.functionSubnetId
    functionStorageAccountId: functionStorage.outputs.storageAccountId
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    allowedIpRanges: allowedPublicIpRanges
  }
}

module logicApp 'modules/logicApp.bicep' = if (deployLogicApps) {
  name: 'logicApp'
  params: {
    name: resourceNaming.outputs.naming.logicApp
    location: location
    tags: tags
    sku: logicAppSku
    integrationSubnetId: networking.outputs.integrationSubnetId
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    storageAccountId: functionStorage.outputs.storageAccountId
  }
}

module eventing 'modules/eventing.bicep' = {
  name: 'eventing'
  params: {
    eventGridTopicName: resourceNaming.outputs.naming.eventGridTopic
    eventHubNamespaceName: resourceNaming.outputs.naming.eventHubNamespace
    eventHubSku: 'Standard'
    eventHubThroughputUnits: 1
    messageRetentionDays: 7
    storageEventHubName: '${resourceNaming.outputs.naming.prefix}-storage-events'
    location: location
    tags: tags
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module synapse 'modules/synapse.bicep' = {
  name: 'synapse'
  params: {
    name: resourceNaming.outputs.naming.synapse
    location: location
    tags: tags
    defaultDataLakeStorageAccountResourceId: storage.outputs.storageAccountId
    defaultDataLakeFilesystem: dataLakeFilesystem
    managedResourceGroupName: '${namePrefix}-${environment}-synapse-rg'
    sqlAdministratorLogin: synapseSqlAdminLogin
    sqlAdministratorPassword: synapseSqlAdminPassword
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    managedPrivateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module azureMaps 'modules/azureMaps.bicep' = if (deployAzureMaps) {
  name: 'azureMaps'
  params: {
    name: resourceNaming.outputs.naming.azureMaps
    location: actualAzureMapsLocation
    tags: tags
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
  }
}

module cognitiveServices 'modules/cognitiveServices.bicep' = if (deployCognitiveServices) {
  name: 'cognitiveServices'
  params: {
    name: resourceNaming.outputs.naming.cognitiveServices
    location: actualCognitiveServicesLocation
    tags: tags
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
  }
}

// Modern Platform Services
module purview 'modules/purview.bicep' = if (deployPurview) {
  name: 'purview'
  params: {
    name: resourceNaming.outputs.naming.purview
    location: actualPurviewLocation
    tags: tags
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module machineLearning 'modules/machineLearning.bicep' = if (deployMachineLearning) {
  name: 'machineLearning'
  params: {
    name: resourceNaming.outputs.naming.machineLearning
    location: actualMachineLearningLocation
    tags: tags
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    applicationInsightsId: ''  // Will need to create App Insights
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module kubernetes 'modules/kubernetes.bicep' = if (deployAKS) {
  name: 'kubernetes'
  params: {
    name: resourceNaming.outputs.naming.kubernetes
    location: actualAksLocation
    tags: tags
    subnetId: networking.outputs.functionSubnetId  // Reuse existing subnet
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
  }
}

module fabric 'modules/fabric.bicep' = if (deployFabric) {
  name: 'fabric'
  params: {
    name: resourceNaming.outputs.naming.fabric
    location: actualFabricLocation
    tags: tags
    administrators: ['admin@company.com']  // Update with actual admin emails
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
  }
}

module containerInstances 'modules/containerInstances.bicep' = if (deployContainerInstances) {
  name: 'containerInstances'
  params: {
    name: resourceNaming.outputs.naming.containerInstances
    location: actualContainerInstancesLocation
    tags: tags
    subnetId: networking.outputs.integrationSubnetId
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
  }
}

module comprehensiveApiGateway 'modules/comprehensiveApiGateway.bicep' = {
  name: 'comprehensiveApiGateway'
  params: {
    name: resourceNaming.outputs.naming.comprehensiveApiGateway
    location: location
    tags: tags
    publisherEmail: 'admin@company.com'  // Update with actual email
    publisherName: 'Data Platform Team'
    subnetId: networking.outputs.integrationSubnetId
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    applicationInsightsId: ''  // Will need to create App Insights
    deployApplicationInsights: false
    keyVaultId: keyVault.outputs.keyVaultId
  }
}

// RBAC Assignments for all platform resources
module rbacAssignments 'modules/rbacAssignments.bicep' = {
  name: 'rbacAssignments'
  params: {
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    synapseWorkspaceId: synapse.outputs.synapseWorkspaceId
    aksClusterId: deployAKS ? kubernetes.outputs.aksClusterId : ''
    mlWorkspaceId: deployMachineLearning ? machineLearning.outputs.mlWorkspaceId : ''
    purviewAccountId: deployPurview ? purview.outputs.purviewAccountId : ''
    fabricCapacityId: deployFabric ? fabric.outputs.fabricCapacityId : ''
    deployAKS: deployAKS
    deployMachineLearning: deployMachineLearning
    deployPurview: deployPurview
    deployFabric: deployFabric
    managedIdentities: {
      functions: appHosting.outputs.functionAppIdentityPrincipalId
      logicApps: deployLogicApps ? logicApp.outputs.logicAppIdentityPrincipalId : ''
      aks: deployAKS ? kubernetes.outputs.aksClusterIdentityPrincipalId : ''
      ml: deployMachineLearning ? machineLearning.outputs.mlWorkspaceIdentityPrincipalId : ''
      purview: deployPurview ? purview.outputs.purviewIdentityPrincipalId : ''
      fabric: '' // Fabric uses dedicated capacity, no managed identity needed for RBAC
      containers: deployContainerInstances ? containerInstances.outputs.containerGroupIdentityPrincipalId : ''
    }
    securityGroups: securityGroups
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output synapseWorkspaceName string = synapse.outputs.synapseWorkspaceName
output functionAppName string = appHosting.outputs.functionAppName
output logicAppName string = deployLogicApps ? logicApp.outputs.logicAppName : ''
output eventGridTopicEndpoint string = eventing.outputs.eventGridTopicEndpoint
output azureMapsAccountId string = deployAzureMaps ? azureMaps.outputs.mapsAccountId : ''
output cognitiveAccountId string = deployCognitiveServices ? cognitiveServices.outputs.cognitiveAccountId : ''
output cognitiveAccountEndpoint string = deployCognitiveServices ? cognitiveServices.outputs.cognitiveAccountEndpoint : ''

// Modern Platform Services Outputs (Conditional)
output purviewAccountId string = deployPurview ? purview.outputs.purviewAccountId : ''
output purviewAccountName string = deployPurview ? purview.outputs.purviewAccountName : ''
output purviewAccountEndpoint string = deployPurview ? purview.outputs.purviewAccountEndpoint : ''
output mlWorkspaceId string = deployMachineLearning ? machineLearning.outputs.mlWorkspaceId : ''
output mlWorkspaceName string = deployMachineLearning ? machineLearning.outputs.mlWorkspaceName : ''
output aksClusterId string = deployAKS ? kubernetes.outputs.aksClusterId : ''
output aksClusterName string = deployAKS ? kubernetes.outputs.aksClusterName : ''
output fabricCapacityId string = deployFabric ? fabric.outputs.fabricCapacityId : ''
output fabricCapacityName string = deployFabric ? fabric.outputs.fabricCapacityName : ''
output containerInstancesId string = deployContainerInstances ? containerInstances.outputs.containerGroupId : ''
output apiGatewayId string = comprehensiveApiGateway.outputs.apiManagementId
output apiGatewayUrl string = comprehensiveApiGateway.outputs.gatewayUrl

// RBAC Assignment Status
output rbacAssignmentStatus object = rbacAssignments.outputs.rbacAssignmentsSummary

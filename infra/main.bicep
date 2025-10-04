@description('Azure region for all resources. Defaults to Switzerland North to satisfy data residency requirements.')
param location string = 'switzerlandnorth'

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
}

@description('Name of the primary data lake filesystem created within the storage account.')
param dataLakeFilesystem string = 'raw'

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

var naming = {
  vnet: '${namePrefix}-${environment}-vnet'
  storage: toLower('${namePrefix}${environment}dls')
  synapse: '${namePrefix}-${environment}-synapse'
  keyVault: '${namePrefix}-${environment}-kv'
  functionPlan: '${namePrefix}-${environment}-asp'
  functionApp: '${namePrefix}-${environment}-func'
  functionStorage: toLower('${namePrefix}${environment}funcsa')
  logAnalytics: '${namePrefix}-${environment}-la'
  eventGridTopic: ingestionEventTopicName
  logicApp: '${namePrefix}-${environment}-logicapp'
  privateDnsZoneSuffixes: [
    'blob.core.windows.net'
    'dfs.core.windows.net'
    'queue.core.windows.net'
    'table.core.windows.net'
    'dfs.fabric.microsoft.com'
    'privatelink.azuresynapse.net'
    'privatelink.sql.azuresynapse.net'
    'privatelink.database.windows.net'
    'privatelink.servicebus.windows.net'
    'privatelink.eventgrid.azure.net'
  ]
}

module logging 'modules/monitoring.bicep' = {
  name: 'logging'
  params: {
    name: naming.logAnalytics
    location: location
    tags: tags
  }
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    name: naming.vnet
    location: location
    tags: tags
    addressSpace: vnetAddressSpace
    subnetAddressPrefixes: subnetAddressPrefixes
  }
}

module privateDns 'modules/privateDns.bicep' = {
  name: 'privateDns'
  params: {
    zoneSuffixes: naming.privateDnsZoneSuffixes
    vnetId: networking.outputs.vnetId
    tags: tags
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    name: naming.keyVault
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    allowedPublicIpRanges: allowedPublicIpRanges
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: naming.storage
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
    name: naming.functionStorage
    location: location
    tags: union(tags, { purpose: 'functions' })
    isHnsEnabled: false
    supportsNfs: false
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module appHosting 'modules/appHosting.bicep' = {
  name: 'appHosting'
  params: {
    location: location
    tags: tags
    functionPlanName: naming.functionPlan
    functionAppName: naming.functionApp
    functionPlanSku: functionPlanSku
    functionSubnetId: networking.outputs.functionSubnetId
    functionStorageAccountId: functionStorage.outputs.storageAccountId
    logAnalyticsWorkspaceId: logging.outputs.workspaceId
    allowedIpRanges: allowedPublicIpRanges
  }
}

module logicApp 'modules/logicApp.bicep' = {
  name: 'logicApp'
  params: {
    name: naming.logicApp
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
    topicName: naming.eventGridTopic
    location: location
    tags: tags
    privateEndpointSubnetId: networking.outputs.privateEndpointsSubnetId
    privateDnsZoneIds: privateDns.outputs.privateDnsZoneIds
  }
}

module synapse 'modules/synapse.bicep' = {
  name: 'synapse'
  params: {
    name: naming.synapse
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

output storageAccountId string = storage.outputs.storageAccountId
output synapseWorkspaceName string = synapse.outputs.synapseWorkspaceName
output functionAppName string = appHosting.outputs.functionAppName
output logicAppName string = logicApp.outputs.logicAppName
output eventGridTopicEndpoint string = eventing.outputs.topicEndpoint

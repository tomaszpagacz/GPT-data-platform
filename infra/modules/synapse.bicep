@description('Name of the Synapse worvar synapseWorkspaceDnsZonesFiltered = [for zoneId in synapseWorkspaceDnsZones: zoneId != null ? zoneId : null]pace.')
param name string

@description('Azure region for Synapse deployment.')
param location string

@description('Tags applied to Synapse resources.')
param tags object = {
  costOptimization: 'enabled'
  autoScaleDown: 'true'
  autoPause: 'true'
}

@description('Resource ID of the default Data Lake Storage account.')
param defaultDataLakeStorageAccountResourceId string

@description('Name of the Self-Hosted Integration Runtime')
param shirName string = ''

@description('Create Self-Hosted Integration Runtime')
param createShir bool = false

@description('Filesystem used as the primary linked service for the Synapse workspace.')
param defaultDataLakeFilesystem string

@description('Name of the managed resource group created by Synapse.')
param managedResourceGroupName string

@description('Dedicated SQL admin login name.')
param sqlAdministratorLogin string

@secure()
@description('Dedicated SQL admin login password.')
param sqlAdministratorPassword string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Subnet ID used for private endpoints associated with the workspace.')
param managedPrivateEndpointSubnetId string

@description('Private DNS zone IDs used for Synapse private endpoints.')
param privateDnsZoneIds array

var storageAccountName = last(split(defaultDataLakeStorageAccountResourceId, '/'))
var storageAccountUrl = 'https://${storageAccountName}.dfs.${az.environment().suffixes.storage}'
var synapseWorkspaceDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.azuresynapse.net') ? zoneId : null]
var synapseWorkspaceDnsZonesFiltered = [for zoneId in synapseWorkspaceDnsZones: zoneId != null ? zoneId : null]
var synapseSqlDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.sql.azuresynapse.net') ? zoneId : null]
var synapseSqlDnsZonesFiltered = [for zoneId in synapseSqlDnsZones: zoneId != null ? zoneId : null]
var sparkPools = [
  {
    name: '${name}-spark-s'
    nodeSize: 'Small'
    minNodes: 3
    maxNodes: 12
  }
  {
    name: '${name}-spark-m'
    nodeSize: 'Medium'
    minNodes: 3
    maxNodes: 20
  }
  {
    name: '${name}-spark-l'
    nodeSize: 'Large'
    minNodes: 3
    maxNodes: 40
  }
]

resource workspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedResourceGroupName: managedResourceGroupName
    defaultDataLakeStorage: {
      accountUrl: storageAccountUrl
      filesystem: defaultDataLakeFilesystem
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorPassword
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
      allowedAadTenantIdsForLinking: [
        subscription().tenantId
      ]
    }
    publicNetworkAccess: 'Disabled'
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'BuiltinSqlReqsEnded'
        enabled: true
      }
      {
        category: 'GatewayApiRequests'
        enabled: true
      }
      {
        category: 'IntegrationActivityRuns'
        enabled: true
      }
      {
        category: 'SynapseRbacOperations'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource sparkPoolsResources 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = [for pool in sparkPools: {
  parent: workspace
  name: pool.name
  location: location
  tags: tags
  properties: {
    nodeSize: pool.nodeSize
    nodeSizeFamily: 'MemoryOptimized'
    autoScale: {
      enabled: true
      minNodeCount: pool.minNodes
      maxNodeCount: pool.maxNodes
    }
    autoPause: {
      enabled: true
      delayInMinutes: 15
    }
    sparkVersion: '3.3'
  }
}]

resource workspacePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${name}-pe-dev'
  location: location
  properties: {
    subnet: {
      id: managedPrivateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-dev'
        properties: {
          privateLinkServiceId: workspace.id
          groupIds: [
            'dev'
          ]
        }
      }
    ]
  }
}

resource workspaceSqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${name}-pe-sql'
  location: location
  properties: {
    subnet: {
      id: managedPrivateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-sql'
        properties: {
          privateLinkServiceId: workspace.id
          groupIds: [
            'sql'
          ]
        }
      }
    ]
  }
}

resource workspaceSqlOnDemandPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${name}-pe-sqlondemand'
  location: location
  properties: {
    subnet: {
      id: managedPrivateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-sqlondemand'
        properties: {
          privateLinkServiceId: workspace.id
          groupIds: [
            'sqlOnDemand'
          ]
        }
      }
    ]
  }
}

resource workspaceDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(synapseWorkspaceDnsZonesFiltered)) {
  name: 'default'
  parent: workspacePrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in synapseWorkspaceDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource workspaceSqlDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(synapseSqlDnsZonesFiltered)) {
  name: 'default'
  parent: workspaceSqlPrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in synapseSqlDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource workspaceSqlOnDemandDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(synapseSqlDnsZonesFiltered)) {
  name: 'default'
  parent: workspaceSqlOnDemandPrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in synapseSqlDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// Self-Hosted Integration Runtime
resource integrationRuntime 'Microsoft.Synapse/workspaces/integrationRuntimes@2021-06-01' = if (createShir) {
  parent: workspace
  name: shirName
  properties: {
    type: 'SelfHosted'
    description: 'Self-hosted integration runtime for on-premises and cross-region data integration'
  }
}

output synapseWorkspaceName string = workspace.name
output synapseWorkspaceId string = workspace.id
output integrationRuntimeId string = createShir ? integrationRuntime.id : ''

@description('Name of the storage account to deploy.')
param name string

@description('Azure region for the storage account.')
param location string

@description('Tags applied to the storage resources.')
param tags object = {}

@description('Name of the filesystem to create when hierarchical namespace is enabled.')
param filesystemName string = ''

@description('Array of container names to create in the storage account.')
param containerNames array = []

@description('Name of the runtime container for serverless compute (Functions, Logic Apps).')
param runtimeContainerName string = 'runtime'

@description('Array of queue names to create in the storage account.')
param queueNames array = []

@description('Array of table names to create in the storage account.')
param tableNames array = []

@description('Indicates whether the storage account should enable hierarchical namespace (Data Lake Storage Gen2).')
param isHnsEnabled bool = true

@description('Subnet for deploying private endpoints.')
param privateEndpointSubnetId string

@description('Private DNS zones to link to the created private endpoints.')
param privateDnsZoneIds array

var blobEndpoint = environment().suffixes.storage
var blobDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.blob${blobEndpoint}') ? zoneId : null]
var blobDnsZoneIdsFiltered = filter(blobDnsZoneIds, id => id != null)
var dfsDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.dfs${blobEndpoint}') ? zoneId : null]
var dfsDnsZoneIdsFiltered = filter(dfsDnsZoneIds, id => id != null)
var queueDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.queue${blobEndpoint}') ? zoneId : null]
var queueDnsZoneIdsFiltered = filter(queueDnsZoneIds, id => id != null)
var tableDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.table${blobEndpoint}') ? zoneId : null]
var tableDnsZoneIdsFiltered = filter(tableDnsZoneIds, id => id != null)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    dnsEndpointType: 'Standard'
    supportsHttpsTrafficOnly: true
  }
}

var storageKeys = storageAccount.listKeys('2022-09-01')

resource fileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = if (!empty(filesystemName) && isHnsEnabled) {
  name: '${name}/default/${filesystemName}'
  properties: {
    publicAccess: 'None'
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for containerName in union(containerNames, !empty(runtimeContainerName) ? [runtimeContainerName] : []): {
  name: '${name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
}]

resource queues 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = [for queueName in queueNames: {
  name: '${name}/default/${queueName}'
}]

resource tables 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = [for tableName in tableNames: {
  name: '${name}/default/${tableName}'
}]

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${name}-pe-blob'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource dfsPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (isHnsEnabled) {
  name: '${name}-pe-dfs'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-dfs'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }
}

resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (!empty(queueNames)) {
  name: '${name}-pe-queue'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-queue'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
}

resource tablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (!empty(tableNames)) {
  name: '${name}-pe-table'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-table'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
}

resource blobZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(blobDnsZoneIdsFiltered)) {
  name: 'default'
  parent: blobPrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in blobDnsZoneIdsFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource dfsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (isHnsEnabled && !empty(dfsDnsZoneIdsFiltered)) {
  name: 'default'
  parent: dfsPrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in dfsDnsZoneIdsFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource queueZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(queueNames) && !empty(queueDnsZoneIdsFiltered)) {
  name: 'default'
  parent: queuePrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in queueDnsZoneIdsFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource tableZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(tableNames) && !empty(tableDnsZoneIdsFiltered)) {
  name: 'default'
  parent: tablePrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in tableDnsZoneIdsFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

output storageAccountId string = storageAccount.id
output storageAccountKey string = storageKeys.keys[0].value

@description('Name of the storage account to deploy.')
param name string

@description('Azure region for the storage account.')
param location string

@description('Tags applied to the storage resources.')
param tags object = {}

@description('Name of the filesystem to create when hierarchical namespace is enabled.')
param filesystemName string = ''

@description('Indicates whether the storage account should enable hierarchical namespace (Data Lake Storage Gen2).')
param isHnsEnabled bool = true

@description('Subnet for deploying private endpoints.')
param privateEndpointSubnetId string

@description('Private DNS zones to link to the created private endpoints.')
param privateDnsZoneIds array

var blobDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.blob.core.windows.net') ? zoneId : null]
var blobDnsZoneIdsFiltered = [for zoneId in blobDnsZoneIds: contains(zoneId, 'privatelink.blob.core.windows.net') ? zoneId : null]
var dfsDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.dfs.core.windows.net') ? zoneId : null]
var dfsDnsZoneIdsFiltered = [for zoneId in dfsDnsZoneIds: contains(zoneId, 'privatelink.dfs.core.windows.net') ? zoneId : null]

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

resource fileSystem 'Microsoft.Storage/storageAccounts/fileServices/containers@2022-09-01' = if (!empty(filesystemName) && isHnsEnabled) {
  name: '${name}/default/${filesystemName}'
  properties: {
    publicAccess: 'None'
  }
}

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

output storageAccountId string = storageAccount.id

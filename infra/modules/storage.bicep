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

@description('Controls NFS 3 support for the storage account.')
param supportsNfs bool = false

@description('Subnet for deploying private endpoints.')
param privateEndpointSubnetId string

@description('Private DNS zones to link to the created private endpoints.')
param privateDnsZoneIds array

var blobDnsZoneIds = [for zoneId in privateDnsZoneIds: if (endsWith(zoneId, '/privatelink.blob.core.windows.net')) zoneId]
var dfsDnsZoneIds = [for zoneId in privateDnsZoneIds: if (endsWith(zoneId, '/privatelink.dfs.core.windows.net')) zoneId]

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: isHnsEnabled
    largeFileSharesState: supportsNfs ? 'Enabled' : 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
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

resource blobZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(blobDnsZoneIds)) {
  name: 'default'
  parent: blobPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in blobDnsZoneIds: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource dfsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (isHnsEnabled && !empty(dfsDnsZoneIds)) {
  name: 'default'
  parent: dfsPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in dfsDnsZoneIds: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

output storageAccountId string = storageAccount.id

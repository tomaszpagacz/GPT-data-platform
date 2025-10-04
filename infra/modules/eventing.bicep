@description('Name of the Event Grid topic used for ingestion triggers.')
param topicName string

@description('Azure region for the Event Grid topic.')
param location string

@description('Tags applied to Event Grid resources.')
param tags object = {}

@description('Subnet used for the private endpoint connection.')
param privateEndpointSubnetId string

@description('Private DNS zones available for private endpoint associations.')
param privateDnsZoneIds array

var topicDnsZoneIds = [for zoneId in privateDnsZoneIds: if (endsWith(zoneId, '/privatelink.eventgrid.azure.net')) zoneId]

resource topic 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: topicName
  location: location
  tags: tags
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Disabled'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${topicName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${topicName}-connection'
        properties: {
          privateLinkServiceId: topic.id
          groupIds: [
            'topic'
          ]
        }
      }
    ]
  }
}

resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(topicDnsZoneIds)) {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in topicDnsZoneIds: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

output topicEndpoint string = topic.properties.endpoint
output topicResourceId string = topic.id

@description('Name of the Event Hub namespace')
param eventHubNamespaceName string

@description('Name of the Event Hub for storage monitoring')
param storageEventHubName string = 'storage-monitoring'

@description('Name of the Event Grid topic')
param eventGridTopicName string

@description('Storage account for queues/tables')
param storageAccountName string

@description('Main event queue name')
param queueName string = 'events-synapse'

@description('Dead-letter queue name')
param dlqName string = 'events-synapse-dlq'

@description('Table to store processed message ids (idempotency)')
param tableDedupe string = 'ProcessedMessages'

@description('Table to store run history / correlation')
param tableRuns string = 'RunHistory'

@description('Azure region for resources')
param location string

@description('SKU for Event Hub Namespace')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param eventHubSku string = 'Standard'

@description('Number of throughput units for Event Hub')
@minValue(1)
@maxValue(20)
param eventHubThroughputUnits int = 1

@description('Retention days for Event Hub messages')
@minValue(1)
@maxValue(7)
param messageRetentionDays int = 7

@description('Subnet used for private endpoint connections')
param privateEndpointSubnetId string

@description('Private DNS zones available for private endpoint associations')
param privateDnsZoneIds array

@description('Tags for resources')
param tags object = {}

// Event Hub Namespace
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: eventHubThroughputUnits
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
    zoneRedundant: eventHubSku == 'Premium'
    disableLocalAuth: true
  }
}

// Storage Monitoring Event Hub
resource storageEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: storageEventHubName
  properties: {
    messageRetentionInDays: messageRetentionDays
    partitionCount: 4
  }
}

// Consumer group for storage monitoring
resource storageMonitoringConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2021-11-01' = {
  parent: storageEventHub
  name: 'storage-monitoring'
  properties: {}
}

// Event Grid Topic
resource eventGridTopic 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: eventGridTopicName
  location: location
  tags: tags
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Disabled'
  }
}

// Event Hub Private Endpoint
resource eventHubPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${eventHubNamespaceName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${eventHubNamespaceName}-connection'
        properties: {
          privateLinkServiceId: eventHubNamespace.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
}

// Event Grid Private Endpoint
resource eventGridPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${eventGridTopicName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${eventGridTopicName}-connection'
        properties: {
          privateLinkServiceId: eventGridTopic.id
          groupIds: [
            'topic'
          ]
        }
      }
    ]
  }
}

// DNS Zone Groups for both Event Hub and Event Grid
resource eventHubZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'default'
  parent: eventHubPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in privateDnsZoneIds: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource eventGridZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'default'
  parent: eventGridPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in privateDnsZoneIds: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// Event Grid subscription to Event Hub
resource eventGridSubscription 'Microsoft.EventGrid/topics/eventSubscriptions@2022-06-15' = {
  parent: eventGridTopic
  name: 'storage-events'
  properties: {
    destination: {
      endpointType: 'EventHub'
      properties: {
        resourceId: storageEventHub.id
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
        'Microsoft.Storage.BlobRenamed'
        'Microsoft.Storage.DirectoryCreated'
        'Microsoft.Storage.DirectoryDeleted'
        'Microsoft.Storage.DirectoryRenamed'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

output eventHubNamespaceId string = eventHubNamespace.id
output eventHubId string = storageEventHub.id
output eventGridTopicId string = eventGridTopic.id
output eventGridTopicEndpoint string = eventGridTopic.properties.endpoint

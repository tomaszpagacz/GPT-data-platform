@description('Name of the Azure AI (Cognitive Services) account.')
param name string

@description('Azure region for the Cognitive Services account.')
param location string

@description('Tags applied to the Cognitive Services resources.')
param tags object = {}

@description('SKU name for the Cognitive Services account.')
param skuName string = 'S0'

@description('Custom subdomain used for the Cognitive Services endpoint. Must be globally unique.')
param customSubdomainName string = toLower(replace(name, '-', ''))

@description('Subnet into which the private endpoint should be deployed.')
param privateEndpointSubnetId string

@description('Private DNS zones available for private endpoint association.')
param privateDnsZoneIds array

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

var cognitiveDnsZoneIds = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.cognitiveservices.azure.com') ? zoneId : null]
var cognitiveDnsZoneIdsFiltered = [for zoneId in cognitiveDnsZoneIds: zoneId != null ? zoneId : null]

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  kind: 'CognitiveServices'
  sku: {
    name: skuName
  }
  tags: tags
  properties: {
    customSubDomainName: customSubdomainName
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    encryption: {
      keySource: 'Microsoft.CognitiveServices'
    }
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

resource cognitivePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${name}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: cognitiveAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource cognitiveZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(cognitiveDnsZoneIdsFiltered)) {
  name: 'default'
  parent: cognitivePrivateEndpoint
  properties: {
  privateDnsZoneConfigs: [for zoneId in cognitiveDnsZoneIdsFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: cognitiveAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
      {
        category: 'RequestResponse'
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

output cognitiveAccountId string = cognitiveAccount.id
output cognitiveAccountEndpoint string = cognitiveAccount.properties.endpoint

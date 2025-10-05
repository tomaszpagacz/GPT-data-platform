@description('Name of the Microsoft Purview account.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Subnet ID for private endpoints.')
param privateEndpointSubnetId string

@description('Private DNS zone IDs for Purview endpoints.')
param privateDnsZoneIds array

@description('Enable public network access.')
param publicNetworkAccess string = 'Disabled'

// Filter DNS zones for Purview
var purviewDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.purview.azure.com') ? zoneId : null]
var purviewDnsZonesFiltered = filter(purviewDnsZones, id => id != null)

var purviewPortalDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.purviewstudio.azure.com') ? zoneId : null]
var purviewPortalDnsZonesFiltered = filter(purviewPortalDnsZones, id => id != null)

// Microsoft Purview Account
resource purviewAccount 'Microsoft.Purview/accounts@2021-12-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    managedResourceGroupName: '${name}-managed-rg'
    cloudConnectors: {}
  }
}

// Private endpoint for Purview account
resource purviewPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${name}-pe-account'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-account-connection'
        properties: {
          privateLinkServiceId: purviewAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

// Private endpoint for Purview portal
resource purviewPortalPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${name}-pe-portal'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-portal-connection'
        properties: {
          privateLinkServiceId: purviewAccount.id
          groupIds: [
            'portal'
          ]
        }
      }
    ]
  }
}

// DNS zone group for account endpoint
resource purviewZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(purviewDnsZonesFiltered)) {
  name: 'default'
  parent: purviewPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in purviewDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// DNS zone group for portal endpoint
resource purviewPortalZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(purviewPortalDnsZonesFiltered)) {
  name: 'default'
  parent: purviewPortalPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in purviewPortalDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: purviewAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ScanStatusLogEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'PurviewAccountAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

output purviewAccountId string = purviewAccount.id
output purviewAccountName string = purviewAccount.name
output purviewAccountEndpoint string = purviewAccount.properties.endpoints.catalog
output purviewPortalEndpoint string = purviewAccount.properties.endpoints.guardian
output purviewIdentityPrincipalId string = purviewAccount.identity.principalId
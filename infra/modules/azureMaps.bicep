@description('Name of the Azure Maps account to deploy.')
param name string

@description('Azure location for Azure Maps. Azure Maps is a global resource; use "global" unless otherwise required.')
param location string = 'global'

@description('Tags applied to the Azure Maps account.')
param tags object = {}

@description('Log Analytics workspace for diagnostics collection.')
param logAnalyticsWorkspaceId string

@description('Flag indicating whether shared keys/local authentication should be disabled in favour of Azure AD.')
param disableLocalAuth bool = true

resource mapsAccount 'Microsoft.Maps/accounts@2023-06-01' = {
  name: name
  location: location
  kind: 'Gen2'
  sku: {
    name: 'G2'
  }
  tags: tags
  properties: {
    disableLocalAuth: disableLocalAuth
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: mapsAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output mapsAccountId string = mapsAccount.id

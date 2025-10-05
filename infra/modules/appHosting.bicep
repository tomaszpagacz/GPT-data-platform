@description('Azure region for the hosting resources.')
param location string

@description('Tags applied to hosting resources.')
param tags object = {}

@description('Name of the Elastic Premium plan for Functions.')
param functionPlanName string

@description('Name of the Function App.')
param functionAppName string

@description('SKU for the Functions Elastic Premium plan.')
param functionPlanSku string

@description('Subnet ID used for VNet integration.')
param functionSubnetId string

@description('Storage account used for Function runtime state.')
param functionStorageAccountId string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('IP ranges permitted to reach the Function App publicly.')
param allowedIpRanges array = []

var storageKeys = listKeys(functionStorageAccountId, '2022-09-01')
var functionStorageAccountName = last(split(functionStorageAccountId, '/'))

// Create the default deny all rule
var defaultDenyRule = {
  ipAddress: '0.0.0.0/0'
  action: 'Deny'
  priority: 2147483647
  name: 'Deny all'
}

// Create allow rules for specified IP ranges
var allowRules = [for (cidr, i) in allowedIpRanges: {
  ipAddress: cidr
  action: 'Allow'
  priority: 100 + i
  name: 'allow-${replace(cidr, '/', '-')}'
}]

// Combine rules based on whether there are allowed IPs
var ipRestrictions = empty(allowedIpRanges) ? array(defaultDenyRule) : allowRules

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: functionPlanName
  location: location
  tags: tags
  sku: {
    name: functionPlanSku
    tier: 'ElasticPremium'
  }
  properties: {
    reserved: true
    maximumElasticWorkerCount: 20
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: functionSubnetId
    siteConfig: {
      linuxFxVersion: 'DOTNET|6.0'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'DOTNET_VERSION'
          value: '8.0'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccountName};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccountName};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
      ipSecurityRestrictions: ipRestrictions
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${functionAppName}-logs'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
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

output functionAppName string = functionApp.name
output functionAppResourceId string = functionApp.id
output functionAppIdentityPrincipalId string = functionApp.identity.principalId

@description('Name of the Logic App Standard instance.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to Logic App resources.')
param tags object = {}

@description('Workflow Standard SKU tier (e.g., Standard).')
param sku string = 'Standard'

@description('Subnet ID used for outbound VNet integration.')
param integrationSubnetId string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Storage account backing the Logic App runtime.')
param storageAccountId string

var storageAccountName = last(split(storageAccountId, '/'))
var storageKeys = listKeys(storageAccountId, '2022-09-01')

resource logicPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  properties: {
    reserved: true
    maximumElasticWorkerCount: 10
  }
}

resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: 'workflowapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: logicPlan.id
    httpsOnly: true
    virtualNetworkSubnetId: integrationSubnetId
    siteConfig: {
      linuxFxVersion: 'DOTNET|6.0'
      appSettings: [
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'WORKFLOWS_STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'WORKFLOWS_STORAGE_ACCOUNT_ACCESS_KEY'
          value: storageKeys.keys[0].value
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      vnetRouteAllEnabled: true
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
      {
        category: 'WorkflowMetrics'
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

output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id

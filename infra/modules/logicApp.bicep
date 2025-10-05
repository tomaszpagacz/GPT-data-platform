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

@description('Name of the runtime container for Logic App content.')
param runtimeContainerName string = 'runtime'

@description('Synapse workspace name')
param synapseWorkspaceName string

@description('Key Vault name (optional)')
param keyVaultName string = ''

@description('Environment name (dev, sit, prod)')
param environment string = 'dev'

@description('Shared secret for on-demand API authentication')
@secure()
param onDemandSharedSecret string

@description('Connection name for Azure Storage Queues')
param connName string = 'azurequeues'

@description('Queue names for eventing functionality')
param queueNames array = []

@description('Table names for eventing functionality')
param tableNames array = []

var storageAccountName = last(split(storageAccountId, '/'))
var storageKeys = listKeys(storageAccountId, '2022-09-01')
var storageConnString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=core.windows.net'

resource logicPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  sku: {
    name: contains(sku, 'Premium') ? 'WS3' : 'WS1'
    tier: sku
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
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
          name: 'WORKFLOWS_TENANT_ID'
          value: subscription().tenantId
        }
        {
          name: 'SYNAPSE_WORKSPACE'
          value: synapseWorkspaceName
        }
        {
          name: 'KEYVAULT_NAME'
          value: keyVaultName
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
          name: 'WEBSITE_CONTENTSHARE'
          value: runtimeContainerName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'EVENT_QUEUE_NAMES'
          value: join(queueNames, ',')
        }
        {
          name: 'EVENT_TABLE_NAMES'
          value: join(tableNames, ',')
        }
        {
          name: 'SCHEDULE_LOCK_BLOB_URL'
          value: 'https://${storageAccountName}.blob.${az.environment().suffixes.storage}/locks/schedule-leader-lock'
        }
        {
          name: 'EVENT_QUEUE_NAME'
          value: 'events-synapse'
        }
        {
          name: 'PIPELINES_CONFIG_JSON'
          value: 'https://${storageAccountName}.blob.${az.environment().suffixes.storage}/config/pipelines.${environment}.json'
        }
        {
          name: 'DLQ_NAME'
          value: 'events-synapse-dlq'
        }
        {
          name: 'TABLE_DEDUPE'
          value: 'ProcessedMessages'
        }
        {
          name: 'TABLE_RUNS'
          value: 'RunHistory'
        }
        {
          name: 'AZURE_TABLE_ENDPOINT'
          value: 'https://${storageAccountName}.table.${az.environment().suffixes.storage}'
        }
        {
          name: 'AZURE_BLOB_ENDPOINT'
          value: 'https://${storageAccountName}.blob.${az.environment().suffixes.storage}'
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'ONDEMAND_SHARED_SECRET'
          value: onDemandSharedSecret
        }
      ]
      vnetRouteAllEnabled: true
    }
  }
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseWorkspaceName
}

resource synapseContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(logicApp.name, 'SynapseContributor')
  scope: synapseWorkspace
  properties: {
    principalId: logicApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if (keyVaultName != '') {
  name: keyVaultName
}

resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (keyVaultName != '') {
  name: guid(logicApp.name, 'KVSecretsUser')
  scope: keyVault
  properties: {
    principalId: logicApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
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

resource storageQueuesConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: connName
  location: location
  properties: {
    displayName: 'Azure Storage Queues'
    parameterValues: {
      connectionString: storageConnString
    }
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azurequeues')
    }
  }
}

resource storageTablesConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azuretables'
  location: location
  properties: {
    displayName: 'Azure Storage Tables'
    parameterValues: {
      connectionString: storageConnString
    }
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuretables')
    }
  }
}

output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id
output logicAppIdentityPrincipalId string = logicApp.identity.principalId
output storageQueuesConnectionId string = storageQueuesConnection.id
output storageTablesConnectionId string = storageTablesConnection.id

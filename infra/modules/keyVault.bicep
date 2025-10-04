@description('Name of the Key Vault instance.')
param name string

@description('Azure region for Key Vault deployment.')
param location string

@description('Tags applied to Key Vault resources.')
param tags object = {}

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('IP ranges permitted to access the Key Vault over public endpoint. Empty array blocks public network access.')
param allowedPublicIpRanges array = []

var defaultNetworkRuleAction = empty(allowedPublicIpRanges) ? 'Deny' : 'Allow'

resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId()
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    enabledForTemplateDeployment: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: defaultNetworkRuleAction
      ipRules: [for cidr in allowedPublicIpRanges: {
        value: cidr
      }]
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
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

output keyVaultId string = keyVault.id

@description('Name of the Container Instances group.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('Container image to deploy.')
param containerImage string = 'mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated8.0'

@description('Number of CPU cores.')
param cpuCores int = 1

@description('Memory in GB.')
param memoryInGB int = 2

@description('Restart policy for containers.')
@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restartPolicy string = 'OnFailure'

@description('Subnet ID for VNet integration.')
param subnetId string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Environment variables for the container.')
param environmentVariables array = []

@description('Enable managed identity.')
param enableManagedIdentity bool = true

// Container Instances Group
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    containers: [
      {
        name: '${name}-container'
        properties: {
          image: containerImage
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          environmentVariables: environmentVariables
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
            {
              port: 443
              protocol: 'TCP'
            }
          ]
        }
      }
    ]
    restartPolicy: restartPolicy
    osType: 'Linux'
    subnetIds: [
      {
        id: subnetId
      }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        workspaceKey: listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey
      }
    }
    priority: 'Regular'
    sku: 'Standard'
  }
}

// Additional container for sidecar pattern (optional)
resource sidecarContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: '${name}-sidecar'
  location: location
  tags: union(tags, { purpose: 'sidecar' })
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    containers: [
      {
        name: 'app-container'
        properties: {
          image: containerImage
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          environmentVariables: environmentVariables
          ports: [
            {
              port: 8080
              protocol: 'TCP'
            }
          ]
        }
      }
      {
        name: 'logging-sidecar'
        properties: {
          image: 'mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod20230816'
          resources: {
            requests: {
              cpu: json('0.5')
              memoryInGB: 1
            }
          }
          environmentVariables: [
            {
              name: 'WORKSPACE_ID'
              value: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
            }
            {
              name: 'WORKSPACE_KEY'
              secureValue: listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey
            }
          ]
        }
      }
    ]
    restartPolicy: 'Always'
    osType: 'Linux'
    subnetIds: [
      {
        id: subnetId
      }
    ]
    priority: 'Regular'
    sku: 'Standard'
  }
}

// Container group for batch processing
resource batchContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: '${name}-batch'
  location: location
  tags: union(tags, { purpose: 'batch-processing' })
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    containers: [
      {
        name: 'batch-processor'
        properties: {
          image: 'mcr.microsoft.com/dotnet/runtime:8.0'
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 4
            }
          }
          environmentVariables: [
            {
              name: 'BATCH_SIZE'
              value: '1000'
            }
            {
              name: 'WORKER_THREADS'
              value: '4'
            }
          ]
          command: [
            '/bin/bash'
            '-c'
            'echo "Starting batch processing..." && sleep 3600'
          ]
        }
      }
    ]
    restartPolicy: 'OnFailure'
    osType: 'Linux'
    subnetIds: [
      {
        id: subnetId
      }
    ]
    priority: 'Spot'
    sku: 'Standard'
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: containerGroup
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ContainerInstanceLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
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

output containerGroupId string = containerGroup.id
output containerGroupName string = containerGroup.name
output containerGroupFqdn string = containerGroup.properties.ipAddress.fqdn
output containerGroupIpAddress string = containerGroup.properties.ipAddress.ip
output containerGroupIdentityPrincipalId string = enableManagedIdentity ? containerGroup.identity.principalId : ''
output sidecarContainerGroupId string = sidecarContainerGroup.id
output batchContainerGroupId string = batchContainerGroup.id
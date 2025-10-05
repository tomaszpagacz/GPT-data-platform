@description('Name of the Azure Machine Learning workspace.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('Resource ID of the storage account for ML workspace.')
param storageAccountId string

@description('Resource ID of the Key Vault.')
param keyVaultId string

@description('Resource ID of the Application Insights.')
param applicationInsightsId string

@description('Resource ID of the container registry (optional).')
param containerRegistryId string = ''

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Subnet ID for private endpoints.')
param privateEndpointSubnetId string

@description('Private DNS zone IDs for ML workspace endpoints.')
param privateDnsZoneIds array

@description('Enable high business impact workspace.')
param hbiWorkspace bool = false

// Filter DNS zones for ML workspace
var mlDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.api.azureml.ms') ? zoneId : null]
var mlDnsZonesFiltered = filter(mlDnsZones, id => id != null)

var mlNotebooksDnsZones = [for zoneId in privateDnsZoneIds: endsWith(zoneId, '/privatelink.notebooks.azure.net') ? zoneId : null]
var mlNotebooksDnsZonesFiltered = filter(mlNotebooksDnsZones, id => id != null)

// Azure Machine Learning Workspace
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: name
    description: 'Azure ML workspace for ${name}'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: applicationInsightsId
    containerRegistry: !empty(containerRegistryId) ? containerRegistryId : null
    publicNetworkAccess: 'Disabled'
    discoveryUrl: 'https://${location}.api.azureml.ms/discovery'
    encryption: {
      status: 'Enabled'
      keyVaultProperties: {
        keyVaultArmId: keyVaultId
        keyIdentifier: ''
      }
    }
    hbiWorkspace: hbiWorkspace
    v1LegacyMode: false
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
      outboundRules: {
        'allow-azure-services': {
          type: 'ServiceTag'
          destination: {
            serviceTag: 'AzureActiveDirectory'
            protocol: 'TCP'
            portRanges: '443'
          }
        }
      }
    }
    featureStoreSettings: {
      computeRuntime: {
        sparkRuntimeVersion: '3.3'
      }
      offlineStoreConnectionName: 'offline-store'
      onlineStoreConnectionName: 'online-store'
    }
  }
}

// Private endpoint for ML workspace API
resource mlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${name}-pe-api'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-api-connection'
        properties: {
          privateLinkServiceId: mlWorkspace.id
          groupIds: [
            'amlworkspace'
          ]
        }
      }
    ]
  }
}

// Private endpoint for ML notebooks
resource mlNotebooksPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${name}-pe-notebooks'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-notebooks-connection'
        properties: {
          privateLinkServiceId: mlWorkspace.id
          groupIds: [
            'notebook'
          ]
        }
      }
    ]
  }
}

// DNS zone group for ML API endpoint
resource mlZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(mlDnsZonesFiltered)) {
  name: 'default'
  parent: mlPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in mlDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// DNS zone group for ML notebooks endpoint
resource mlNotebooksZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(mlNotebooksDnsZonesFiltered)) {
  name: 'default'
  parent: mlNotebooksPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [for zoneId in mlNotebooksDnsZonesFiltered: {
      name: last(split(zoneId, '/'))
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// Compute instance for development
resource computeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  parent: mlWorkspace
  name: '${name}-dev-instance'
  location: location
  properties: {
    computeType: 'ComputeInstance'
    properties: {
      vmSize: 'Standard_DS3_v2'
      subnet: {
        id: privateEndpointSubnetId
      }
      applicationSharingPolicy: 'Personal'
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      setupScripts: {
        scripts: {
          creationScript: {
            scriptSource: 'inline'
            scriptData: base64('''
#!/bin/bash
# Install additional ML libraries
pip install --upgrade azureml-sdk
pip install mlflow
pip install optuna
pip install shap
pip install interpret
            ''')
          }
        }
      }
    }
  }
}

// Compute cluster for training workloads
resource computeCluster 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  parent: mlWorkspace
  name: '${name}-training-cluster'
  location: location
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: 'Standard_DS3_v2'
      vmPriority: 'Dedicated'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 10
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
      subnet: {
        id: privateEndpointSubnetId
      }
      enableNodePublicIp: false
      isolatedNetwork: false
      osType: 'Linux'
    }
  }
}

// Inference cluster for model deployment
resource inferenceCluster 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  parent: mlWorkspace
  name: '${name}-inference-cluster'
  location: location
  properties: {
    computeType: 'AKS'
    properties: {
      agentCount: 3
      agentVmSize: 'Standard_D3_v2'
      clusterFqdn: '${name}-inference.${location}.cloudapp.azure.com'
      orchestratorType: 'Kubernetes'
      systemServices: [
        {
          systemServiceType: 'None'
        }
      ]
    }
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: mlWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AmlComputeClusterEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AmlComputeClusterNodeEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AmlComputeJobEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AmlComputeCpuGpuUtilization'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AmlRunStatusChangedEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'ModelsChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'ModelsReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'ModelsActionEvent'
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

output mlWorkspaceId string = mlWorkspace.id
output mlWorkspaceName string = mlWorkspace.name
output mlWorkspaceIdentityPrincipalId string = mlWorkspace.identity.principalId
output computeInstanceName string = computeInstance.name
output trainingClusterName string = computeCluster.name
output inferenceClusterName string = inferenceCluster.name
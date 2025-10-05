@description('Name of the AKS cluster.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('Kubernetes version.')
param kubernetesVersion string = '1.28.3'

@description('VM size for the default node pool.')
param nodeVmSize string = 'Standard_D4s_v3'

@description('Number of nodes in the default pool.')
param nodeCount int = 3

@description('Minimum number of nodes for auto-scaling.')
param minNodeCount int = 1

@description('Maximum number of nodes for auto-scaling.')
param maxNodeCount int = 10

@description('Subnet ID for AKS nodes.')
param subnetId string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Enable Azure AD integration.')
param enableAzureAD bool = true

@description('Enable Azure RBAC for Kubernetes authorization.')
param enableAzureRBAC bool = true

@description('Network plugin (azure or kubenet).')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'

@description('Network policy (azure or calico).')
@allowed([
  'azure'
  'calico'
])
param networkPolicy string = 'azure'

@description('DNS service IP.')
param dnsServiceIP string = '10.0.0.10'

@description('Service CIDR.')
param serviceCidr string = '10.0.0.0/16'

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${name}-dns'
    enableRBAC: true
    
    // Node pools configuration
    agentPoolProfiles: [
      {
        name: 'system'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        minCount: minNodeCount
        maxCount: maxNodeCount
        vnetSubnetID: subnetId
        maxPods: 30
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        nodeLabels: {
          'node-type': 'system'
        }
      }
    ]
    
    // Network configuration
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'Standard'
      outboundType: 'loadBalancer'
    }
    
    // Azure AD integration
    aadProfile: enableAzureAD ? {
      managed: true
      enableAzureRBAC: enableAzureRBAC
      tenantID: tenant().tenantId
    } : null
    
    // API server configuration
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system'
      enablePrivateClusterPublicFQDN: false
    }
    
    // Add-ons
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
      azurepolicy: {
        enabled: true
      }
      ingressApplicationGateway: {
        enabled: false
      }
    }
    
    // Security configuration
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 48
      }
    }
    
    // Auto-upgrade configuration
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    
    // Storage profile
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    
    // Windows profile (if needed)
    windowsProfile: null
    
    // HTTP proxy configuration
    httpProxyConfig: null
    
    // Maintenance window
    maintenanceWindow: {
      allowedDays: [
        'Saturday'
        'Sunday'
      ]
      allowedHours: [
        2
        3
        4
      ]
    }
  }
}

// User node pool for application workloads
resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-10-01' = {
  parent: aksCluster
  name: 'user'
  properties: {
    count: 2
    vmSize: 'Standard_D2s_v3'
    osType: 'Linux'
    mode: 'User'
    enableAutoScaling: true
    minCount: 0
    maxCount: 5
    vnetSubnetID: subnetId
    maxPods: 30
    osDiskSizeGB: 128
    osDiskType: 'Managed'
    kubeletDiskType: 'OS'
    nodeLabels: {
      'node-type': 'user'
      'workload': 'general'
    }
    nodeTaints: []
  }
}

// GPU node pool for ML workloads (optional)
resource gpuNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-10-01' = {
  parent: aksCluster
  name: 'gpu'
  properties: {
    count: 0
    vmSize: 'Standard_NC6s_v3'
    osType: 'Linux'
    mode: 'User'
    enableAutoScaling: true
    minCount: 0
    maxCount: 3
    vnetSubnetID: subnetId
    maxPods: 30
    osDiskSizeGB: 256
    osDiskType: 'Managed'
    kubeletDiskType: 'OS'
    nodeLabels: {
      'node-type': 'gpu'
      'workload': 'ml'
      'accelerator': 'nvidia-tesla-v100'
    }
    nodeTaints: [
      'sku=gpu:NoSchedule'
    ]
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: aksCluster
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'kube-audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'kube-controller-manager'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'kube-scheduler'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'guard'
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

output aksClusterId string = aksCluster.id
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output aksClusterIdentityPrincipalId string = aksCluster.identity.principalId
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup
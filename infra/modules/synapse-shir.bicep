@description('Name of the virtual machine')
param vmName string

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Size of the virtual machine')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param vmSize string = 'Standard_D2s_v3'

@description('Admin username for the virtual machine')
param adminUsername string

@description('Admin password for the virtual machine')
@secure()
param adminPassword string

@description('Subnet ID for the virtual machine')
param subnetId string

@description('Tags for resources')
param tags object = {}

@description('Name of the associated Synapse workspace')
param synapseWorkspaceName string

@description('OS disk type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskType string = 'StandardSSD_LRS'

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: 'UTC'
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Custom Script Extension for SHIR Installation
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: 'InstallSHIR'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/tomaszpagacz/GPT-data-platform/main/scripts/setup-shir.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File setup-shir.ps1 -SynapseWorkspaceName ${synapseWorkspaceName} -IntegrationRuntimeName "${vmName}-ir"'
    }
  }
}

// Managed Identity for the VM
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${vmName}-identity'
  location: location
  tags: tags
}

// RBAC assignment for VM to access Synapse
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, managedIdentity.id, 'Synapse Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Enable Managed Identity on VM
resource vmIdentity 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    vm
  ]
}

output vmId string = vm.id
output vmName string = vm.name
output nicId string = nic.id
output managedIdentityId string = managedIdentity.id
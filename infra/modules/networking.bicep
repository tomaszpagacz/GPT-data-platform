@description('Name of the virtual network hosting the data platform resources.')
param name string

@description('Azure region for the network resources.')
param location string

@description('Address space allocated to the virtual network.')
param addressSpace string

@description('Subnet CIDR prefixes for platform components.')
param subnetAddressPrefixes object

@description('Resource tags applied to networking assets.')
param tags object = {}

var functionSubnetName = 'function-apps'
var integrationSubnetName = 'integration'
var privateEndpointSubnetName = 'private-endpoints'
var irSubnetName = 'self-hosted-ir'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
  }
}

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${name}-nat-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2022-07-01' = {
  name: '${name}-nat'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

resource functionNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${name}-func-nsg'
  location: location
  tags: tags
}

resource integrationNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${name}-integration-nsg'
  location: location
  tags: tags
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${name}-pe-nsg'
  location: location
  tags: tags
}

resource irNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${name}-ir-nsg'
  location: location
  tags: tags
}

resource functionSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${name}/${functionSubnetName}'
  properties: {
    addressPrefix: subnetAddressPrefixes.functionApps
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: functionNsg.id
    }
    natGateway: {
      id: natGateway.id
    }
  }
}

resource integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${name}/${integrationSubnetName}'
  properties: {
    addressPrefix: subnetAddressPrefixes.integration
    networkSecurityGroup: {
      id: integrationNsg.id
    }
    natGateway: {
      id: natGateway.id
    }
  }
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${name}/${privateEndpointSubnetName}'
  properties: {
    addressPrefix: subnetAddressPrefixes.privateEndpoints
    networkSecurityGroup: {
      id: privateEndpointNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}

resource irSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${name}/${irSubnetName}'
  properties: {
    addressPrefix: subnetAddressPrefixes.selfHostedIntegrationRuntime
    networkSecurityGroup: {
      id: irNsg.id
    }
    natGateway: {
      id: natGateway.id
    }
  }
}

output vnetId string = vnet.id
output functionSubnetId string = functionSubnet.id
output integrationSubnetId string = integrationSubnet.id
output privateEndpointsSubnetId string = privateEndpointSubnet.id
output selfHostedIntegrationRuntimeSubnetId string = irSubnet.id

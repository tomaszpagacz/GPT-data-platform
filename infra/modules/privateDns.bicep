@description('Private DNS zone suffixes to create for private endpoint resolution.')
param zoneSuffixes array

@description('Virtual network to link with the private DNS zones.')
param vnetId string

@description('Tags applied to the DNS zones.')
param tags object = {}

var zones = [for suffix in zoneSuffixes: {
  name: 'privatelink.${suffix}'
}]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in zones: {
  name: zone.name
  location: 'global'
  tags: tags
}]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in zones: {
  parent: privateDnsZones[i]
  name: 'link-${last(split(vnetId, '/'))}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}]

output privateDnsZoneIds array = [for i in range(0, length(zones)): privateDnsZones[i].id]

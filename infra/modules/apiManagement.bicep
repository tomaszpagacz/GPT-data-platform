@description('The name of the API Management service.')
param name string

@description('Location for resources.')
param location string = resourceGroup().location

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service.')
@allowed([
  1
  2
])
param skuCount int = 1

@description('The name of the owner email.')
param publisherEmail string

@description('The name of the owner.')
param publisherName string

@description('Enable virtual network integration')
param virtualNetworkEnabled bool = true

@description('Virtual network configuration')
param virtualNetworkConfiguration object = {
  subnetResourceId: ''
}

@description('Custom domain configuration')
param customDomains object = {
  enabled: false
  hostnames: []
}

@description('Tags for the resource')
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: skuCount
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkEnabled ? 'External' : 'None'
    virtualNetworkConfiguration: virtualNetworkEnabled ? virtualNetworkConfiguration : null
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
    hostnameConfigurations: customDomains.enabled ? array(union([{
      type: 'Proxy'
      hostName: first(customDomains.hostnames)
      negotiateClientCertificate: false
    }], skip(customDomains.hostnames, 1) == [] ? [] : [{
      type: 'Proxy'
      hostName: last(customDomains.hostnames)
      negotiateClientCertificate: false
    }])) : []
  }
}

@description('Built-in logger for Application Insights')
resource logger 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
  parent: apim
  name: 'app-insights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsights.id
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
  }
}

@description('Application Insights instance')
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: 'your-appinsights-name' // This should be parameterized
}

@description('Named Values (shared configuration)')
resource namedValues 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apim
  name: 'backend-url'
  properties: {
    displayName: 'backend-url'
    value: 'https://${functionApp.properties.defaultHostName}'
    secret: false
  }
}

@description('Function App backend')
resource functionApp 'Microsoft.Web/sites@2021-02-01' existing = {
  name: 'your-function-app-name' // This should be parameterized
}

output apimName string = apim.name
output apimId string = apim.id
output gatewayUrl string = apim.properties.gatewayUrl
@description('Name of the comprehensive API gateway.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('SKU for API Management.')
@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

@description('Publisher email for API Management.')
param publisherEmail string

@description('Publisher name for API Management.')
param publisherName string

@description('Subnet ID for API Management.')
param subnetId string

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Application Insights for API monitoring.')
param applicationInsightsId string

@description('Whether Application Insights is deployed and available.')
param deployApplicationInsights bool = false

@description('Key Vault for secrets management.')
param keyVaultId string

@description('Backend services configuration.')
param backendServices array = []

// Enhanced API Management Service
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
    publicNetworkAccess: 'Disabled'
    developerPortalStatus: 'Enabled'
    gatewayUrl: 'https://${name}.azure-api.net'
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
    apiVersionConstraint: {
      minApiVersion: '2021-08-01'
    }
  }
}

// Application Insights Logger
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = if (deployApplicationInsights) {
  parent: apiManagement
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger for API Management'
    credentials: {
      instrumentationKey: reference(applicationInsightsId, '2020-02-02').InstrumentationKey
    }
  }
}

// Global API Management Policies
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apiManagement
  name: 'policy'
  properties: {
    value: '''
    <policies>
      <inbound>
        <cors allow-credentials="true">
          <allowed-origins>
            <origin>*</origin>
          </allowed-origins>
          <allowed-methods>
            <method>GET</method>
            <method>POST</method>
            <method>PUT</method>
            <method>DELETE</method>
            <method>OPTIONS</method>
          </allowed-methods>
          <allowed-headers>
            <header>*</header>
          </allowed-headers>
        </cors>
        <rate-limit-by-key calls="1000" renewal-period="3600" counter-key="@(context.Request.IpAddress)" />
        <quota-by-key calls="10000" renewal-period="86400" counter-key="@(context.Request.IpAddress)" />
        <authentication-managed-identity resource="https://graph.microsoft.com" />
        <set-header name="X-Powered-By" exists-action="delete" />
        <set-header name="X-AspNet-Version" exists-action="delete" />
      </inbound>
      <backend>
        <forward-request />
      </backend>
      <outbound>
        <set-header name="X-Request-Id" exists-action="override">
          <value>@(context.RequestId)</value>
        </set-header>
      </outbound>
      <on-error>
        <set-status code="500" reason="Internal Server Error" />
        <set-body>@{
          return new JObject(
            new JProperty("error", new JObject(
              new JProperty("code", context.LastError.Source),
              new JProperty("message", context.LastError.Message),
              new JProperty("requestId", context.RequestId)
            ))
          ).ToString();
        }</set-body>
      </on-error>
    </policies>
    '''
  }
}

// GraphQL API
resource graphqlApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apiManagement
  name: 'graphql-api'
  properties: {
    displayName: 'GraphQL API'
    description: 'Modern GraphQL API for data platform'
    path: 'graphql'
    protocols: [
      'https'
    ]
    type: 'graphql'
    format: 'graphql-link'
    value: 'https://api.example.com/graphql'
    subscriptionRequired: true
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
  }
}

// REST API with OpenAPI specification
resource restApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apiManagement
  name: 'data-platform-api'
  properties: {
    displayName: 'Data Platform REST API'
    description: 'RESTful API for data platform operations'
    path: 'api/v1'
    protocols: [
      'https'
    ]
    type: 'http'
    subscriptionRequired: true
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
  }
}

// API Operations for REST API
resource getDataOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: restApi
  name: 'get-data'
  properties: {
    displayName: 'Get Data'
    method: 'GET'
    urlTemplate: '/data/{id}'
    description: 'Retrieve data by ID'
    templateParameters: [
      {
        name: 'id'
        description: 'Data identifier'
        type: 'string'
        required: true
      }
    ]
    request: {
      queryParameters: [
        {
          name: 'format'
          description: 'Response format'
          type: 'string'
          defaultValue: 'json'
          values: [
            'json'
            'xml'
          ]
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

// Backend for Data Services
resource dataBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiManagement
  name: 'data-backend'
  properties: {
    description: 'Data platform backend services'
    url: 'https://data-backend.internal'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 5
            interval: 'PT1M'
            statusCodeRanges: [
              {
                min: 500
                max: 599
              }
            ]
          }
          tripDuration: 'PT1M'
        }
      ]
    }
    pool: {
      size: 10
    }
  }
}

// Product for API grouping
resource apiProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  parent: apiManagement
  name: 'data-platform-product'
  properties: {
    displayName: 'Data Platform APIs'
    description: 'Comprehensive data platform API product'
    subscriptionRequired: true
    approvalRequired: true
    subscriptionsLimit: 100
    state: 'published'
  }
}

// Associate APIs with Product
resource productApiRest 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  parent: apiProduct
  name: restApi.name
}

resource productApiGraphQL 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  parent: apiProduct
  name: graphqlApi.name
}

// Named Values for configuration
resource apiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apiManagement
  name: 'backend-api-key'
  properties: {
    displayName: 'Backend API Key'
    secret: true
    keyVault: {
      secretIdentifier: '${reference(keyVaultId, '2023-07-01').vaultUri}secrets/backend-api-key'
    }
  }
}

// Subscription for internal services
resource internalSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  parent: apiManagement
  name: 'internal-services'
  properties: {
    scope: '/products/${apiProduct.name}'
    displayName: 'Internal Services Subscription'
    state: 'active'
    allowTracing: true
  }
}

// API Management Diagnostic Settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: apiManagement
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'Gateway Requests'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Capacity'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

output apiManagementId string = apiManagement.id
output apiManagementName string = apiManagement.name
output apiManagementIdentityPrincipalId string = apiManagement.identity.principalId
output gatewayUrl string = 'https://${apiManagement.properties.gatewayUrl}'
output developerPortalUrl string = 'https://${apiManagement.properties.developerPortalUrl}'
output restApiId string = restApi.id
output graphqlApiId string = graphqlApi.id
output productId string = apiProduct.id

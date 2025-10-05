@description('The name of the API Management service.')
param apimName string

@description('The name of the API.')
param apiName string

@description('The display name of the API.')
param displayName string

@description('The backend URL (Azure Function app URL).')
param backendUrl string

@description('The path to append to the API URL.')
param apiPath string

@description('The API Management logger ID for App Insights.')
param loggerId string = 'app-insights'

@description('The API Management named value ID for backend URL.')
param namedValueId string = 'backend-url'

@description('The subscription key header name.')
param subscriptionKeyHeaderName string = 'Ocp-Apim-Subscription-Key'

@description('CORS allowed origins.')
param corsAllowedOrigins array = []

resource api 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  name: '${apimName}/${apiName}'
  properties: {
    displayName: displayName
    description: 'API for ${displayName}'
    subscriptionRequired: true
    type: 'http'
    protocols: [
      'https'
    ]
    path: apiPath
    apiType: 'http'
    format: 'openapi+json'
    value: loadJsonContent('openapi.json')
    subscriptionKeyParameterNames: {
      header: subscriptionKeyHeaderName
    }
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  name: '${apimName}/${apiName}/policy'
  properties: {
    format: 'xml'
    value: '''
<policies>
  <inbound>
    <base />
    <set-backend-service base-url="{{${namedValueId}}}" />
    <cors>
      <allowed-origins>
        ${join(corsAllowedOrigins, '\n        ')}
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
      </allowed-methods>
      <allowed-headers>
        <header>${subscriptionKeyHeaderName}</header>
        <header>Content-Type</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
    <set-header name="Microsoft-Azure-Api-Management-Correlation-Id" exists-action="override">
      <value>@(context.RequestId)</value>
    </set-header>
  </on-error>
</policies>
'''
  }
  dependsOn: [
    api
  ]
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01' = {
  name: '${apimName}/${apiName}/applicationinsights'
  properties: {
    loggerId: loggerId
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    metrics: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
  }
  dependsOn: [
    api
  ]
}

output apiId string = api.id
output apiPath string = api.properties.path
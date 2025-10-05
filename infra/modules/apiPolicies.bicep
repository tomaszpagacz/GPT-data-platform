@description('The name of the API Management service.')
param apimName string

@description('Rate limit calls per subscription.')
param rateLimit int = 100

@description('Rate limit renewal period in seconds.')
param rateLimitRenewalPeriod int = 60

@description('API Management instance')
resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apimName
}

resource globalPolicy 'Microsoft.ApiManagement/service/policies@2021-08-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'xml'
    value: '''
<policies>
  <inbound>
    <rate-limit calls="${rateLimit}" renewal-period="${rateLimitRenewalPeriod}" />
    <check-header name="Ocp-Apim-Subscription-Key" exists-action="error" />
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-XSS-Protection" exists-action="override">
      <value>1; mode=block</value>
    </set-header>
    <set-header name="Content-Security-Policy" exists-action="override">
      <value>default-src 'self'</value>
    </set-header>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <set-header name="Server" exists-action="delete" />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}
@description('The name of the API Management service.')
param apimName string

@description('The maximum data transfer size in KB')
param maxDataTransferSize int = 1024

@description('The maximum number of requests per time window')
param maxRequestsPerTimeWindow int = 100

@description('The time window in seconds')
param timeWindowInSeconds int = 60

@description('Allowed IP ranges')
param allowedIpRanges array = []

resource compensatingControls 'Microsoft.ApiManagement/service/policies@2021-08-01' = {
  name: '${apimName}/policy'
  properties: {
    format: 'xml'
    value: '''
<policies>
    <inbound>
        <!-- Rate limiting per IP -->
        <rate-limit-by-key 
            calls="${maxRequestsPerTimeWindow}" 
            renewal-period="${timeWindowInSeconds}"
            counter-key="@(context.Request.IpAddress)" />
        
        <!-- Request size limiting -->
        <set-variable name="requestSize" value="@(context.Request.Headers["Content-Length"])" />
        <check-variable name="requestSize" operator="LessThan" value="${maxDataTransferSize * 1024}" />
        
        <!-- Enhanced logging -->
        <set-variable name="requestTimestamp" value="@(DateTime.UtcNow.ToString())" />
        <set-variable name="requestSize" value="@(context.Request.Headers["Content-Length"])" />
        <log-to-eventhub logger-id="data-access-logger">
            @{
                return new JObject(
                    new JProperty("timestamp", context.Variables["requestTimestamp"]),
                    new JProperty("ipAddress", context.Request.IpAddress),
                    new JProperty("method", context.Request.Method),
                    new JProperty("url", context.Request.Url),
                    new JProperty("requestSize", context.Variables["requestSize"]),
                    new JProperty("subscriptionId", context.Subscription?.Id),
                    new JProperty("userId", context.User?.Id)
                ).ToString();
            }
        </log-to-eventhub>

        <!-- Request validation -->
        <validate-content type="application/json" validate-as="json" />
        
        <!-- Schema validation if OpenAPI spec is available -->
        <validate-json-schema specification-path="apis" />
        
        <!-- Security headers -->
        <set-header name="X-Content-Type-Options" exists-action="override">
            <value>nosniff</value>
        </set-header>
        <set-header name="X-Frame-Options" exists-action="override">
            <value>DENY</value>
        </set-header>
        <set-header name="Content-Security-Policy" exists-action="override">
            <value>default-src 'self'</value>
        </set-header>
        
        <base />
    </inbound>
    <backend>
        <forward-request timeout="60" />
    </backend>
    <outbound>
        <!-- Response size monitoring -->
        <set-variable name="responseSize" value="@(context.Response.Headers["Content-Length"])" />
        <log-to-eventhub logger-id="data-access-logger">
            @{
                return new JObject(
                    new JProperty("timestamp", context.Variables["requestTimestamp"]),
                    new JProperty("responseSize", context.Variables["responseSize"]),
                    new JProperty("statusCode", context.Response.StatusCode)
                ).ToString();
            }
        </log-to-eventhub>
        
        <!-- Remove sensitive headers -->
        <set-header name="Server" exists-action="delete" />
        <set-header name="X-Powered-By" exists-action="delete" />
        <set-header name="X-AspNet-Version" exists-action="delete" />
        
        <base />
    </outbound>
    <on-error>
        <!-- Error logging -->
        <log-to-eventhub logger-id="error-logger">
            @{
                return new JObject(
                    new JProperty("timestamp", DateTime.UtcNow.ToString()),
                    new JProperty("source", context.LastError.Source),
                    new JProperty("reason", context.LastError.Reason),
                    new JProperty("message", context.LastError.Message)
                ).ToString();
            }
        </log-to-eventhub>
        <base />
    </on-error>
</policies>
'''
  }
}
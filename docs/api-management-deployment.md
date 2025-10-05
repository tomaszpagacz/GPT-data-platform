# API Management Deployment Guide

> **Note**: This guide covers the legacy API Management service. For new deployments, consider using the **Comprehensive API Gateway** which includes modern features like GraphQL support, enhanced security patterns, and better integration with containerized workloads. See the [Modern Platform Implementation Guide](modern-platform-implementation-guide.md) for details.

## Modern API Gateway vs Legacy APIM

The platform now includes a **Comprehensive API Gateway** that provides:
- GraphQL and REST API support
- OAuth 2.0 and modern authentication patterns  
- Enhanced rate limiting and throttling
- Request/response transformation
- Integration with AKS and Azure ML services
- Container API support

For new implementations, use the comprehensive gateway instead of the legacy APIM service documented below.

## Prerequisites

### Required Azure Permissions
- Contributor role on the target resource group
- Network Contributor role (for VNET integration)
- Key Vault Administrator (if using custom domains with certificates)

### Required Tools
- Azure CLI v2.50.0 or later
- Bicep CLI v0.20.0 or later
- Azure subscription with quota for API Management service

## Pre-deployment Checklist

### 1. Network Planning
```plaintext
Default CIDR allocations:
- VNET: 10.0.0.0/16
- APIM Subnet: 10.0.1.0/24 (minimum /27 required)
- Function Subnet: 10.0.2.0/24
- Private Endpoints Subnet: 10.0.3.0/24
```

Ensure these ranges don't conflict with existing networks if using VNET peering.

### 2. DNS Requirements
- If using custom domains:
  - Valid SSL certificate for your domain
  - Access to DNS zone management
  - Plan for DNS record updates

### 3. Parameter Files Updates
Update the following parameters in `/infra/params/<env>.apimanagement.parameters.json`:

```json
{
    "publisherEmail": {
        "value": "your-team-email@domain.com"  // Required
    },
    "publisherName": {
        "value": "Your Team Name"              // Required
    },
    "customDomains": {                         // Optional
        "enabled": true,
        "hostnames": ["api.yourdomain.com"]
    }
}
```

### 4. Environment-Specific Considerations

#### Development (dev)
- Uses Developer SKU (non-SLA, lowest cost)
- Recommended for API development and testing
- No custom domain required
- VNET integration optional

Required updates in `dev.apimanagement.parameters.json`:
- Set publisherEmail and publisherName
- Set virtualNetworkEnabled based on needs
- Verify Developer SKU is sufficient

#### System Integration Testing (sit)
- Uses Standard SKU
- Recommended for integration testing
- VNET integration recommended
- Custom domain optional

Required updates in `sit.apimanagement.parameters.json`:
- Set publisherEmail and publisherName
- Configure VNET integration
- Set appropriate SKU count based on load testing requirements

#### Production (prod)
- Uses Premium SKU for high availability
- VNET integration required
- Custom domain recommended
- Multiple instances for availability

Required updates in `prod.apimanagement.parameters.json`:
- Set publisherEmail and publisherName
- Configure custom domains
- Set skuCount to at least 2 for HA
- Verify Premium SKU features needed

## Deployment Steps

1. Deploy Base Infrastructure:
```bash
# Deploy networking first
az deployment group create \
  --name networking-deployment \
  --resource-group <your-resource-group> \
  --template-file infra/modules/networking.bicep \
  --parameters @infra/params/<env>.networking.parameters.json

# Note the subnet ID outputs for APIM
```

2. Deploy API Management:
```bash
# Deploy APIM
az deployment group create \
  --name apim-deployment \
  --resource-group <your-resource-group> \
  --template-file infra/modules/apiManagement.bicep \
  --parameters @infra/params/<env>.apimanagement.parameters.json
```

3. Import APIs:
```bash
# Deploy API definitions
az deployment group create \
  --name api-deployment \
  --resource-group <your-resource-group> \
  --template-file infra/modules/apiDefinition.bicep \
  --parameters apimName=<your-apim-name> apiName=<your-api-name>
```

4. Apply Policies:
```bash
# Deploy global policies
az deployment group create \
  --name policies-deployment \
  --resource-group <your-resource-group> \
  --template-file infra/modules/apiPolicies.bicep \
  --parameters apimName=<your-apim-name>
```

## Post-deployment Verification

1. Verify API Management Service:
```bash
# Check APIM provisioning state
az apim show --name <your-apim-name> --resource-group <your-resource-group> --query provisioningState
```

2. Test API Accessibility:
```bash
# Get the gateway URL
az apim show --name <your-apim-name> --resource-group <your-resource-group> --query gatewayUrl

# Test an API (replace with your subscription key)
curl -H "Ocp-Apim-Subscription-Key: <key>" https://<gateway-url>/hello
```

3. Verify Network Settings:
```bash
# Check VNET integration
az apim show --name <your-apim-name> --resource-group <your-resource-group> --query virtualNetworkType
```

## Troubleshooting

Common Issues:
1. APIM Deployment Timeout
   - Premium SKU deployment can take 1-2 hours
   - Developer SKU typically takes 20-30 minutes

2. Network Configuration Issues
   - Verify NSG rules allow APIM management endpoints
   - Check subnet delegation settings
   - Verify service endpoints are enabled

3. Custom Domain Issues
   - Verify DNS records are properly configured
   - Check SSL certificate validity
   - Ensure certificate is properly imported

## Monitoring Recommendations

1. Enable Application Insights:
   - Already configured in template
   - Review sampling settings based on traffic

2. Set up Alerts:
   - Capacity metrics (>80% usage)
   - Response times (>1s)
   - Failed requests (>1%)

## Cost Considerations

SKU Pricing (approximate monthly):
- Developer: ~$50/month
- Standard: ~$500/month
- Premium: ~$2,500/month/unit

Additional Costs:
- Bandwidth
- Custom domains (SSL certificates)
- Application Insights

## Security Notes

1. Network Security:
   - APIM subnet is isolated
   - NSG rules are restrictive
   - Management endpoints are protected

2. API Security:
   - Subscription keys required
   - Rate limiting enabled
   - Security headers configured

3. Access Control:
   - Use RBAC for management
   - Implement OAuth2 for APIs
   - Configure IP restrictions if needed
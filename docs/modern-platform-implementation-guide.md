# Modern Data Platform Implementation Guide

> **Last Updated:** 2025-01-15
> **Audience:** Administrator, Architect
> **Prerequisites:** Azure subscription Owner role, Azure CLI, Bicep CLI, kubectl

## Overview

This guide provides step-by-step instructions for implementing the modernized GPT Data Platform with advanced components including Microsoft Purview, Azure Machine Learning, Azure Kubernetes Service, Microsoft Fabric, Azure Container Instances, and comprehensive API Gateway with GraphQL support.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Phases](#deployment-phases)
- [Post-Deployment Tasks](#post-deployment-tasks)
- [Monitoring Setup](#monitoring-setup)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

## Prerequisites

### Required Tools
```bash
# Install Azure CLI (latest version)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Bicep CLI
az bicep install

# Install kubectl for AKS management
az aks install-cli

# Install Microsoft Fabric CLI (optional)
az extension add --name fabric
```

### Required Permissions
- **Contributor** role on the target subscription
- **User Access Administrator** role for RBAC assignments
- **Fabric Administrator** for Microsoft Fabric setup

## Deployment Steps

### Phase 1: Core Infrastructure Update

1. **Update DNS Zones**
   ```bash
   # The private DNS zones are automatically updated in main.bicep
   # Verify all required zones are created
   az network private-dns zone list --resource-group "rg-dataplatform-${environment}"
   ```

2. **Deploy Updated Infrastructure**
   ```bash
   # Deploy the updated main template
   az deployment sub create \
     --name "dataplatform-modernization-$(date +%Y%m%d%H%M)" \
     --location "switzerlandnorth" \
     --template-file "infra/main.bicep" \
     --parameters \
       namePrefix="gptdata" \
       environment="dev" \
       synapseSqlAdminLogin="sqladmin" \
       synapseSqlAdminPassword="YourSecurePassword123!"
   ```

### Phase 2: Service-Specific Configuration

#### Microsoft Purview Setup

1. **Deploy Purview Account**
   ```bash
   # Purview is deployed automatically via main.bicep
   # Verify deployment
   az purview account show \
     --name "gptdata-purview-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Configure Data Sources**
   ```bash
   # Register data sources (requires Purview REST API or Portal)
   # Data Lake Storage
   # Synapse Analytics
   # SQL databases
   # Microsoft Fabric datasets
   ```

3. **Set Up Data Classification**
   - Configure sensitivity labels
   - Set up data classification rules
   - Enable automatic scanning

#### Azure Machine Learning Configuration

1. **Verify ML Workspace**
   ```bash
   # Check ML workspace deployment
   az ml workspace show \
     --name "gptdata-ml-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Configure Compute Resources**
   ```bash
   # Compute instances and clusters are created automatically
   # Verify compute resources
   az ml compute list \
     --workspace-name "gptdata-ml-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

3. **Set Up MLOps Pipelines**
   ```bash
   # Create example ML pipeline
   az ml job create \
     --file examples/ml-pipeline.yml \
     --workspace-name "gptdata-ml-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

#### Azure Kubernetes Service (AKS) Setup

1. **Get AKS Credentials**
   ```bash
   # Connect to AKS cluster
   az aks get-credentials \
     --name "gptdata-aks-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Verify Cluster Status**
   ```bash
   # Check cluster health
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. **Deploy Sample Application**
   ```bash
   # Deploy sample containerized application
   kubectl apply -f examples/sample-app.yaml
   ```

4. **Configure Ingress Controller**
   ```bash
   # Install NGINX ingress controller
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

#### Microsoft Fabric Configuration

1. **Verify Fabric Capacity**
   ```bash
   # Check Fabric capacity
   az fabric capacity show \
     --name "gptdata-fabric-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Configure Auto-Scaling**
   ```bash
   # Auto-scaling is configured automatically
   # Verify auto-scale settings
   az monitor autoscale show \
     --name "gptdata-fabric-dev-autoscale" \
     --resource-group "rg-dataplatform-dev"
   ```

3. **Create OneLake Data Sources**
   - Connect to Data Lake Storage
   - Set up data flows and pipelines
   - Create data warehouses and lakehouses
   - Build reports and visualizations in Fabric

#### Container Instances Configuration

1. **Verify Container Groups**
   ```bash
   # Check container instances
   az container show \
     --name "gptdata-aci-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Monitor Container Logs**
   ```bash
   # View container logs
   az container logs \
     --name "gptdata-aci-dev" \
     --resource-group "rg-dataplatform-dev" \
     --container-name "gptdata-aci-dev-container"
   ```

#### Comprehensive API Gateway Setup

1. **Verify API Management**
   ```bash
   # Check API Management service
   az apim show \
     --name "gptdata-apigw-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

2. **Configure API Policies**
   ```bash
   # Update API policies for security and rate limiting
   az apim api policy set \
     --service-name "gptdata-apigw-dev" \
     --resource-group "rg-dataplatform-dev" \
     --api-id "data-platform-api" \
     --policy-file "examples/api-policy.xml"
   ```

3. **Test GraphQL Endpoint**
   ```bash
   # Test GraphQL API
   curl -X POST https://gptdata-apigw-dev.azure-api.net/graphql \
     -H "Content-Type: application/json" \
     -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY" \
     -d '{"query": "{ __schema { types { name } } }"}'
   ```

### Phase 3: Azure Functions .NET 8 Upgrade

1. **Update Function App Runtime**
   ```bash
   # Runtime is updated automatically via Bicep template
   # Verify runtime version
   az functionapp config show \
     --name "gptdata-func-dev" \
     --resource-group "rg-dataplatform-dev" \
     --query "linuxFxVersion"
   ```

2. **Update Function Code**
   ```csharp
   // Update function code to use .NET 8 isolated worker
   // Example function with new runtime:
   using Microsoft.Azure.Functions.Worker;
   using Microsoft.Extensions.Logging;
   
   public class HttpTriggerFunction
   {
       private readonly ILogger _logger;
   
       public HttpTriggerFunction(ILoggerFactory loggerFactory)
       {
           _logger = loggerFactory.CreateLogger<HttpTriggerFunction>();
       }
   
       [Function("HttpExample")]
       public HttpResponseData Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
       {
           _logger.LogInformation("C# HTTP trigger function processed a request.");
           // Function logic here
       }
   }
   ```

3. **Update Project Files**
   ```xml
   <!-- Update .csproj file -->
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <AzureFunctionsVersion>v4</AzureFunctionsVersion>
       <OutputType>Exe</OutputType>
     </PropertyGroup>
     <ItemGroup>
       <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.19.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.16.4" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.0.13" />
     </ItemGroup>
   </ItemGroup>
   ```

## Verification and Testing

### Health Checks

1. **Infrastructure Health**
   ```bash
   # Run comprehensive health check script
   chmod +x infra/pipeline/check-platform-health.sh
   ./infra/pipeline/check-platform-health.sh
   ```

2. **Service Connectivity**
   ```bash
   # Test service-to-service connectivity
   # Purview to Storage
   # ML to Storage and Key Vault
   # AKS to private endpoints
   # API Gateway to backend services
   ```

3. **Security Validation**
   ```bash
   # Verify private endpoints
   # Check RBAC assignments
   # Validate network security groups
   # Test managed identity authentication
   ```

### Performance Testing

1. **Load Testing API Gateway**
   ```bash
   # Use Azure Load Testing or Artillery
   artillery run examples/api-load-test.yml
   ```

2. **ML Workload Testing**
   ```bash
   # Submit test ML job
   az ml job create --file examples/test-ml-job.yml
   ```

3. **Container Performance**
   ```bash
   # Monitor container resource usage
   kubectl top pods --all-namespaces
   ```

## Post-Deployment Configuration

### Security Hardening

1. **Update Network Security Groups**
   ```bash
   # Configure additional NSG rules if needed
   az network nsg rule create \
     --resource-group "rg-dataplatform-dev" \
     --nsg-name "nsg-dataplatform" \
     --name "AllowMLCompute" \
     --priority 1100 \
     --source-address-prefixes "VirtualNetwork" \
     --destination-address-prefixes "VirtualNetwork" \
     --destination-port-ranges "443" \
     --access "Allow" \
     --protocol "Tcp"
   ```

2. **Configure Key Vault Policies**
   ```bash
   # Add access policies for new services
   az keyvault set-policy \
     --name "gptdata-kv-dev" \
     --object-id "$(az resource show --ids /subscriptions/.../resourceGroups/rg-dataplatform-dev/providers/Microsoft.MachineLearningServices/workspaces/gptdata-ml-dev --query identity.principalId -o tsv)" \
     --secret-permissions get list \
     --key-permissions get list
   ```

### Monitoring Setup

1. **Configure Alerts**
   ```bash
   # Set up critical alerts for new services
   az monitor metrics alert create \
     --name "AKS-HighCPU" \
     --resource-group "rg-dataplatform-dev" \
     --scopes "/subscriptions/.../resourceGroups/rg-dataplatform-dev/providers/Microsoft.ContainerService/managedClusters/gptdata-aks-dev" \
     --condition "avg Percentage CPU > 80" \
     --description "AKS cluster high CPU usage"
   ```

2. **Set Up Dashboards**
   - Create Azure Monitor dashboards
   - Configure Microsoft Fabric monitoring reports
   - Set up ML experiment tracking

### Cost Optimization

1. **Configure Auto-Scaling**
   ```bash
   # AKS cluster auto-scaling is enabled by default
   # Verify auto-scaler configuration
   az aks show \
     --name "gptdata-aks-dev" \
     --resource-group "rg-dataplatform-dev" \
     --query "agentPoolProfiles[0].enableAutoScaling"
   ```

2. **Set Up Budget Alerts**
   ```bash
   # Create budget for new services including Fabric
   az consumption budget create \
     --budget-name "DataPlatform-Modern-Services" \
     --amount 5000 \
     --resource-group "rg-dataplatform-dev" \
     --time-grain "Monthly" \
     --start-date "2025-01-01" \
     --end-date "2025-12-31"
   ```

## Troubleshooting

### Common Issues

1. **Private Endpoint Connectivity**
   ```bash
   # Test private endpoint resolution
   nslookup gptdata-ml-dev.api.azureml.ms
   ```

2. **AKS Node Issues**
   ```bash
   # Check node status and events
   kubectl describe nodes
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

3. **Function App Runtime Issues**
   ```bash
   # Check function app logs
   az functionapp log tail \
     --name "gptdata-func-dev" \
     --resource-group "rg-dataplatform-dev"
   ```

### Recovery Procedures

1. **Service Recovery**
   - Use infrastructure rollback scripts
   - Restore from backups if needed
   - Scale services up if auto-scaling issues

2. **Data Recovery**
   - Use Purview for data lineage tracking
   - Restore ML models from registry
   - Recover container data from persistent volumes

## Next Steps

1. **Data Migration**
   - Migrate existing data to new platform components
   - Update data pipelines to use new services
   - Validate data integrity

2. **Application Updates**
   - Update applications to use new APIs
   - Migrate workloads to AKS
   - Implement new ML pipelines

3. **Training and Documentation**
   - Train team on new services
   - Update operational procedures
   - Create user documentation

## Related Documentation

- [Platform Architecture](architecture.md) - Understanding the overall system design
- [Security Assessment](security-assessment.md) - Security configuration and compliance
- [RBAC Implementation](rbac-implementation-guide.md) - Access control setup
- [Deployment Troubleshooting](deployment-troubleshooting.md) - Common deployment issues
- [Cost Optimization](cost-optimization.md) - Cost management strategies

## Next Steps

After completing platform implementation:

1. Review [Security Assessment](security-assessment.md) for compliance verification
2. Configure [RBAC Implementation](rbac-implementation-guide.md) for access control
3. Set up monitoring and alerting as described in operational documentation
4. Follow [Cost Optimization](cost-optimization.md) for resource efficiency
5. Begin development using the function and Logic Apps guides

## Support and Resources

- **Azure Documentation**: https://docs.microsoft.com/azure/
- **Bicep Documentation**: https://docs.microsoft.com/azure/azure-resource-manager/bicep/
- **AKS Best Practices**: https://docs.microsoft.com/azure/aks/
- **ML Platform Guide**: https://docs.microsoft.com/azure/machine-learning/
- **Microsoft Fabric**: https://docs.microsoft.com/fabric/

For issues or questions, contact the Data Platform Team or create an issue in the project repository.
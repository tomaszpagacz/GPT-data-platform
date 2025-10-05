# Azure Data Platform - Deployment Strategy

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Security Configuration](#security-configuration)
4. [Deployment Phases](#deployment-phases)
5. [Post-Deployment Tasks](#post-deployment-tasks)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

---

## 🛠️ Prerequisites

### 1. Azure Subscription & Permissions
- **Azure Subscription** with Owner or Contributor access
- **Service Principal** with appropriate permissions for pipeline deployment
- **Resource Groups** creation permissions
- **Role assignment** permissions for RBAC setup

### 2. Security Groups Setup
**Required Azure AD Security Groups** (update GUIDs in parameter files):
- Platform Admins
- Platform Operators  
- Platform Developers
- Platform Readers
- ML Engineers
- Data Analysts
- Data Scientists
- Data Engineers
- Data Governance Team

### 3. Azure DevOps Setup
- **Azure DevOps Organization** and Project
- **Service Connection** to Azure subscription
- **Variable Groups** configured:
  - `infrastructure-variables`
  - `security-scanning-variables`

### 4. Local Development Setup
```bash
# Install required tools
az --version                    # Azure CLI 2.40+
bicep --version                # Bicep CLI 0.18+
git --version                  # Git 2.30+

# Login to Azure
az login
az account set --subscription "your-subscription-id"

# Clone and navigate to repository
git clone https://github.com/tomaszpagacz/GPT-data-platform.git
cd GPT-data-platform
```

---

## 🏗️ Environment Setup

### Phase 1: Prerequisite Validation
```bash
# Run prerequisite check
./infra/pipeline/check-prerequisites.sh

# Expected output: All resource providers registered
# If any providers are missing, the script will register them
```

### Phase 2: Parameter Configuration

#### 2.1 Update Security Groups (Critical)
Edit environment-specific parameter files with your Azure AD Group Object IDs:

**For DEV Environment:**
```bash
# Edit infra/params/dev.main.parameters.json
{
  "securityGroups": {
    "value": {
      "platformAdmins": "your-platform-admins-group-id",
      "platformOperators": "your-platform-operators-group-id",
      "platformDevelopers": "your-platform-developers-group-id",
      "platformReaders": "your-platform-readers-group-id",
      "mlEngineers": "your-ml-engineers-group-id",
      "dataAnalysts": "your-data-analysts-group-id",
      "dataScientists": "your-data-scientists-group-id",
      "dataEngineers": "your-data-engineers-group-id",
      "dataGovernanceTeam": "your-data-governance-group-id"
    }
  }
}
```

#### 2.2 Get Azure AD Group IDs
```bash
# List your Azure AD groups and get Object IDs
az ad group list --query "[].{Name:displayName, ObjectId:id}" --output table

# Or search for specific group
az ad group show --group "Platform Admins" --query "id" --output tsv
```

#### 2.3 Update Synapse Credentials
```bash
# Generate secure password
SYNAPSE_PASSWORD=$(openssl rand -base64 32)
echo "Generated Synapse Password: $SYNAPSE_PASSWORD"

# Update in parameter files (dev.main.parameters.json, prod.main.parameters.json)
# Replace "YourSecurePassword123!" with the generated password
```

---

## 🔐 Security Configuration

### 1. Azure DevOps Variable Groups

#### infrastructure-variables
```yaml
Variables:
- serviceConnection: "Azure-ServiceConnection-Name"
- resourceGroup: "rg-gptdata"
- location: "switzerlandnorth"
- environment: "dev" # or "sit", "prod"
- maxAllowedCost: "5000" # Monthly cost limit in USD
- validateResourceLocks: "true"
```

#### security-scanning-variables
```yaml
Variables:
- performSecurityScan: "true"
- securityScanFrequency: "weekly"
- complianceCheckEnabled: "true"
```

### 2. Service Principal Setup
```bash
# Create service principal for pipeline
az ad sp create-for-rbac --name "GPT-DataPlatform-Pipeline" \
  --role "Owner" \
  --scopes "/subscriptions/your-subscription-id"

# Output will contain:
# - appId (Application ID)
# - password (Client Secret)  
# - tenant (Tenant ID)
```

---

## 🚀 Deployment Phases

### Phase 1: Development Environment (30-45 minutes)

#### Step 1: Local Validation
```bash
# Validate all Bicep templates
./infra/pipeline/validate-all-bicep.sh

# Expected output: "All Bicep files built successfully!"
```

#### Step 2: Deploy Core Infrastructure
```bash
# Deploy main infrastructure
az deployment sub create \
  --name "gptdata-dev-$(date +%Y%m%d-%H%M%S)" \
  --location "switzerlandnorth" \
  --template-file "infra/main.bicep" \
  --parameters @infra/params/dev.main.parameters.json

# Monitor deployment (15-30 minutes)
```

#### Step 3: Deploy Eventing Infrastructure
```bash
# Deploy eventing components
az deployment group create \
  --resource-group "rg-gptdata-dev" \
  --template-file "infra/modules/eventing.bicep" \
  --parameters @infra/params/dev.eventing.parameters.json
```

#### Step 4: Configure Key Vault Secrets
```bash
# Deploy secrets
az deployment group create \
  --resource-group "rg-gptdata-dev" \
  --template-file "infra/modules/keyVaultSecrets.bicep" \
  --parameters @infra/params/dev.keyvaultsecrets.parameters.json
```

### Phase 2: System Integration Testing (SIT) Environment

#### Step 1: Update SIT Parameters
```bash
# Copy and modify for SIT
cp infra/params/dev.main.parameters.json infra/params/sit.main.parameters.json
# Update environment value to "sit"
# Update security groups if different
```

#### Step 2: Deploy SIT Environment
```bash
# Deploy SIT infrastructure  
az deployment sub create \
  --name "gptdata-sit-$(date +%Y%m%d-%H%M%S)" \
  --location "switzerlandnorth" \
  --template-file "infra/main.bicep" \
  --parameters @infra/params/sit.main.parameters.json
```

### Phase 3: Production Environment

#### Step 1: Production-Specific Configuration
```bash
# Create production parameters
cp infra/params/dev.main.parameters.json infra/params/prod.main.parameters.json

# Update for production:
# - environment: "prod"
# - Stronger passwords
# - Production security groups
# - Resource sizing adjustments
```

#### Step 2: Production Deployment (with approvals)
```bash
# Production deployment with enhanced monitoring
az deployment sub create \
  --name "gptdata-prod-$(date +%Y%m%d-%H%M%S)" \
  --location "switzerlandnorth" \
  --template-file "infra/main.bicep" \
  --parameters @infra/params/prod.main.parameters.json
```

---

## 🔄 Automated Pipeline Deployment

### 1. Trigger Pipeline Deployment
```bash
# Push changes to trigger pipeline
git add .
git commit -m "Deploy data platform infrastructure"
git push origin main

# Pipeline will automatically:
# 1. Validate Bicep templates
# 2. Run security scans
# 3. Deploy to DEV
# 4. Wait for approval
# 5. Deploy to SIT  
# 6. Wait for approval
# 7. Deploy to PROD
```

### 2. Monitor Pipeline Progress
- **Azure DevOps Portal**: Monitor deployment stages
- **Azure Portal**: Watch resource deployment progress
- **Log Analytics**: Monitor deployment logs

---

## ✅ Post-Deployment Tasks

### 1. Verify Core Services (15 minutes)

#### Storage Account Validation
```bash
# Check storage account
STORAGE_NAME=$(az storage account list --resource-group rg-gptdata-dev --query "[0].name" -o tsv)
az storage container list --account-name $STORAGE_NAME --output table
```

#### Synapse Workspace Setup
```bash
# Get Synapse workspace URL
SYNAPSE_URL=$(az synapse workspace show --name gptdata-dev-synapse --resource-group rg-gptdata-dev --query "connectivityEndpoints.web" -o tsv)
echo "Synapse Studio URL: $SYNAPSE_URL"

# Create Synapse admin user
az synapse role assignment create \
  --workspace-name gptdata-dev-synapse \
  --role "Synapse Administrator" \
  --assignee "your-user-email@domain.com"
```

#### Key Vault Access Validation
```bash
# Test Key Vault access
KEYVAULT_NAME=$(az keyvault list --resource-group rg-gptdata-dev --query "[0].name" -o tsv)
az keyvault secret list --vault-name $KEYVAULT_NAME --output table
```

### 2. Configure Application Services

#### Function App Deployment
```bash
# Get Function App details
FUNCTION_APP=$(az functionapp list --resource-group rg-gptdata-dev --query "[0].name" -o tsv)

# Deploy function code (if available)
# func azure functionapp publish $FUNCTION_APP
```

#### Logic Apps Configuration
```bash
# Get Logic App details
LOGIC_APP=$(az logic workflow list --resource-group rg-gptdata-dev --query "[0].name" -o tsv)
echo "Logic App: $LOGIC_APP"
```

### 3. RBAC Verification (Critical)
```bash
# Verify RBAC assignments were created
./infra/pipeline/check-platform-health.sh

# Check role assignments on key resources
az role assignment list --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-gptdata-dev" --output table
```

---

## 📊 Monitoring & Maintenance

### 1. Platform Health Monitoring
```bash
# Run health check script
./infra/pipeline/check-platform-health.sh

# Monitor cost optimization
./infra/pipeline/optimize-costs.sh
```

### 2. Automated Monitoring Setup
- **Log Analytics**: Centralized logging for all services
- **Application Insights**: Function Apps and Logic Apps monitoring
- **Azure Monitor**: Resource health and performance metrics
- **Cost Management**: Budget alerts and cost optimization

### 3. Security Monitoring
- **Microsoft Defender for Cloud**: Security recommendations
- **Key Vault Monitoring**: Access logs and certificate expiration
- **Network Security Groups**: Traffic monitoring
- **Azure Policy**: Compliance monitoring

---

## 🚨 Troubleshooting

### Common Deployment Issues

#### 1. RBAC Assignment Failures
```bash
# Check service principal permissions
az role assignment list --assignee "service-principal-object-id" --output table

# Verify security groups exist
az ad group show --group "security-group-object-id"
```

#### 2. Resource Naming Conflicts
```bash
# Check existing resources
az resource list --location switzerlandnorth --output table

# Modify namePrefix in parameters if needed
```

#### 3. Deployment Timeouts
```bash
# Check deployment status
az deployment sub show --name "deployment-name" --query "properties.provisioningState"

# View deployment errors
az deployment sub show --name "deployment-name" --query "properties.error"
```

#### 4. Rollback Procedure
```bash
# Use rollback script for critical issues
./infra/pipeline/rollback-deployment.sh

# Manual rollback
az deployment sub delete --name "failed-deployment-name"
```

### Emergency Contacts
- **Platform Team**: platform-team@company.com
- **Security Team**: security-team@company.com  
- **On-Call Engineer**: +1-xxx-xxx-xxxx

---

## 📈 Success Metrics

### Deployment Success Criteria
- ✅ All Bicep templates compile successfully
- ✅ All Azure resources deployed without errors
- ✅ RBAC assignments configured correctly
- ✅ Security groups have appropriate access
- ✅ Monitoring and alerting operational
- ✅ Cost controls in place
- ✅ Security compliance validated

### Performance Targets
- **Deployment Time**: < 45 minutes for full environment
- **Availability**: 99.9% uptime SLA
- **Security**: Zero critical security findings
- **Cost**: Within allocated budget limits

---

## 🎯 Next Steps After Deployment

1. **User Onboarding**: Add users to appropriate security groups
2. **Data Ingestion**: Configure data sources and pipelines
3. **ML Workloads**: Deploy machine learning models
4. **Monitoring Setup**: Configure custom dashboards
5. **Backup Strategy**: Implement data backup procedures
6. **Disaster Recovery**: Test recovery procedures
7. **Training**: Conduct user training sessions

---

*This deployment strategy ensures a secure, monitored, and maintainable Azure Data Platform with comprehensive RBAC automation.*
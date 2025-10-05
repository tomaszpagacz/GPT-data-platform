# 🚀 Azure Data Platform - Deployment Checklist

## 📋 Pre-Deployment Checklist

### ✅ Prerequisites Verification
- [ ] Azure CLI installed and updated (`az --version`)
- [ ] Bicep CLI installed (`bicep --version`)
- [ ] Logged into Azure (`az login`)
- [ ] Correct subscription selected (`az account show`)
- [ ] Required permissions (Owner/Contributor on subscription)
- [ ] Resource providers registered (`./infra/pipeline/check-prerequisites.sh`)

### ✅ Security Setup
- [ ] Azure AD Security Groups created with correct members:
  - [ ] Platform Admins
  - [ ] Platform Operators  
  - [ ] Platform Developers
  - [ ] Platform Readers
  - [ ] ML Engineers
  - [ ] Data Analysts
  - [ ] Data Scientists
  - [ ] Data Engineers
  - [ ] Data Governance Team
- [ ] Security Group Object IDs documented
- [ ] Service Principal created for pipeline (if using Azure DevOps)

### ✅ Configuration Files
- [ ] Parameter files updated with correct security group IDs
- [ ] Synapse admin password generated and updated
- [ ] Environment-specific configurations verified
- [ ] Name prefixes chosen to avoid conflicts

## 🛠️ Deployment Steps

### Phase 1: Template Validation (5 minutes)
```bash
# Quick validation
./deploy-platform.sh --validate

# Or manual validation
./infra/pipeline/validate-all-bicep.sh
```
- [ ] All Bicep templates compile successfully
- [ ] No critical errors reported
- [ ] Warnings reviewed and acceptable

### Phase 2: Development Environment (30-45 minutes)

#### Manual Deployment
```bash
# Run interactive deployment script
./deploy-platform.sh

# Or manual deployment
az deployment sub create \
  --name "gptdata-dev-$(date +%Y%m%d-%H%M%S)" \
  --location "switzerlandnorth" \
  --template-file "infra/main.bicep" \
  --parameters @infra/params/dev.main.parameters.json
```

#### Deployment Checklist
- [ ] Deployment initiated successfully
- [ ] No error messages during deployment
- [ ] All resources created in resource group
- [ ] RBAC assignments completed
- [ ] Storage accounts accessible
- [ ] Key Vault secrets deployed
- [ ] Synapse workspace operational
- [ ] Function Apps deployed
- [ ] Logic Apps created
- [ ] Event Grid/Event Hubs configured
- [ ] Azure ML workspace ready
- [ ] Purview account configured
- [ ] AKS cluster running
- [ ] API Management deployed

### Phase 3: Additional Components (15 minutes)
```bash
# Deploy eventing infrastructure
az deployment group create \
  --resource-group "rg-gptdata-dev" \
  --template-file "infra/modules/eventing.bicep" \
  --parameters @infra/params/dev.eventing.parameters.json

# Deploy Key Vault secrets
az deployment group create \
  --resource-group "rg-gptdata-dev" \
  --template-file "infra/modules/keyVaultSecrets.bicep" \
  --parameters @infra/params/dev.keyvaultsecrets.parameters.json
```

- [ ] Eventing components deployed
- [ ] Key Vault secrets configured
- [ ] API Management configured (if applicable)

## ✅ Post-Deployment Verification

### Platform Health Check (10 minutes)
```bash
# Run health check script
./infra/pipeline/check-platform-health.sh
```

- [ ] All resources show "Succeeded" status
- [ ] Resource groups created correctly
- [ ] Network connectivity established
- [ ] Storage accounts accessible
- [ ] Key Vault permissions working
- [ ] RBAC assignments active

### Service-Specific Validation

#### Synapse Analytics
```bash
# Get Synapse URL
az synapse workspace show --name gptdata-dev-synapse --resource-group rg-gptdata-dev --query "connectivityEndpoints.web"
```
- [ ] Synapse Studio accessible
- [ ] SQL Admin login working
- [ ] Spark pools available
- [ ] Data integration capabilities working

#### Azure Machine Learning
```bash
# Get ML workspace details
az ml workspace show --name gptdata-dev-ml --resource-group rg-gptdata-dev
```
- [ ] ML Studio accessible
- [ ] Compute instances available
- [ ] Data stores configured
- [ ] Model registry working

#### Storage & Data Services
- [ ] Data Lake Storage containers created
- [ ] Blob storage accessible with correct permissions
- [ ] File shares mounted correctly
- [ ] Data encryption enabled

#### Security & Governance
- [ ] Key Vault accessible by applications
- [ ] Managed identities working
- [ ] RBAC permissions enforced
- [ ] Purview data discovery working
- [ ] Network security groups configured

#### Computing & Processing
- [ ] Function Apps responding to triggers
- [ ] Logic Apps workflows executing
- [ ] AKS cluster nodes healthy
- [ ] Container instances running

#### Monitoring & Observability
- [ ] Log Analytics workspace collecting data
- [ ] Application Insights monitoring applications
- [ ] Azure Monitor alerts configured
- [ ] Cost management budgets set

## 🔄 Pipeline Deployment (Alternative)

### Azure DevOps Setup
- [ ] Service connection configured
- [ ] Variable groups created and populated
- [ ] Pipeline permissions granted
- [ ] Branch protection rules enabled

### Pipeline Execution
```bash
# Trigger pipeline by pushing to main branch
git add .
git commit -m "Deploy data platform infrastructure"
git push origin main
```

- [ ] Pipeline triggered successfully
- [ ] Security scans passed
- [ ] DEV environment deployed
- [ ] SIT environment deployed (with approval)
- [ ] PROD environment deployed (with approval)

## 🎯 Success Criteria

### Technical Validation
- [ ] ✅ Zero deployment failures
- [ ] ✅ All resources in "Succeeded" state
- [ ] ✅ RBAC assignments configured correctly
- [ ] ✅ Network connectivity established
- [ ] ✅ Security compliance validated
- [ ] ✅ Monitoring operational

### Business Validation
- [ ] ✅ Users can access assigned resources
- [ ] ✅ Data ingestion pipelines ready
- [ ] ✅ Analytics workloads functional
- [ ] ✅ ML development environment ready
- [ ] ✅ Cost controls in place
- [ ] ✅ Backup and DR configured

## 🚨 Troubleshooting Quick Reference

### Common Issues
| Issue | Solution |
|-------|----------|
| RBAC assignment failures | Verify security group Object IDs |
| Naming conflicts | Update namePrefix in parameters |
| Deployment timeout | Check resource quotas and limits |
| Permission denied | Verify service principal permissions |
| Template validation errors | Run `./infra/pipeline/validate-all-bicep.sh` |

### Emergency Rollback
```bash
# Use rollback script
./infra/pipeline/rollback-deployment.sh

# Or manual cleanup
az deployment sub delete --name "failed-deployment-name"
az group delete --name "rg-gptdata-environment" --yes
```

## 📞 Support Contacts

- **Deployment Issues**: platform-team@company.com
- **Security Questions**: security-team@company.com  
- **Emergency Support**: +1-xxx-xxx-xxxx

---

## 🎉 Deployment Complete!

Once all checkboxes are completed, your Azure Data Platform is ready for:
- Data ingestion and processing
- Machine learning workloads
- Analytics and reporting
- Governance and compliance
- User onboarding and training

**Next Step**: Review `DEPLOYMENT-STRATEGY.md` for detailed post-deployment configuration.

---

*Deployment Date: ___________*  
*Deployed By: ___________*  
*Environment: ___________*  
*Deployment Name: ___________*
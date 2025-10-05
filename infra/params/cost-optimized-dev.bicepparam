using '../main.bicep'

// ========================================
// COST-OPTIMIZED DEPLOYMENT PARAMETERS
// ========================================
// Generated automatically for: dev environment
// Generated on: Sun Oct  5 03:11:23 UTC 2025
//
// This parameter file is optimized for cost management in dev environments.
// Expensive 24/7 charging resources are selectively disabled to reduce costs.

// ========================================
// COST OPTIMIZATION SWITCHES
// ========================================
// These parameters control which expensive resources get deployed.
// Setting to false prevents deployment and saves costs.

// 💰 DISABLED: Microsoft Fabric - Saves: $525/month (F2 minimum)
param deployFabric = false

// 💰 DISABLED: Azure Kubernetes Service - Saves: $420/month (3 nodes)
param deployAKS = false

// ✅ ENABLED: Azure Machine Learning - Est. cost: $200+/month (compute instances)
param deployMachineLearning = true

// 💰 DISABLED: Microsoft Purview - Saves: $400/month (4 capacity units)
param deployPurview = false

// 💰 DISABLED: Synapse Dedicated SQL - Saves: $1,200/month (DW100c)
param deploySynapseDedicatedSQL = false

// 💰 DISABLED: Self-Hosted IR VM - Saves: $140/month (Standard_D2s_v3)
param deploySHIR = false

// ✅ ENABLED: Container Instances - Est. cost: Variable (pay-per-use)
param deployContainerInstances = true

// ✅ ENABLED: Logic Apps Standard - Est. cost: $200/month (base plan)
param deployLogicApps = true

// ✅ ENABLED: Cognitive Services - Est. cost: Variable by tier
param deployCognitiveServices = true

// ✅ ENABLED: Azure Maps - Est. cost: Variable by tier
param deployAzureMaps = true


// ========================================
// COST SAVINGS SUMMARY
// ========================================
// Estimated monthly savings for dev: ~$2685 USD
// (Based on disabled expensive resources)
//
// To use these parameters:
// az deployment group create \
//   --resource-group <rg-name> \
//   --template-file ../main.bicep \
//   --parameters @/workspaces/GPT-data-platform/scripts/../infra/params/cost-optimized-dev.bicepparam \
//   --parameters namePrefix=<prefix> environment=dev


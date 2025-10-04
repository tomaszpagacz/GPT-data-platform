# GPT Data Platform

## Overview
This repository captures the high-level architecture for a modular, Azure-native data analytics platform that ingests heterogeneous sources (APIs, databases, files, and streaming IoT feeds) into Azure Data Lake Storage Gen2. The solution emphasises cost efficiency, GDPR-compliant operations in Switzerland, and extensibility for future machine learning and analytics workloads.

Key Azure services:
- **Azure Functions** for custom, event-driven ingestion and lightweight API façades.
- **Azure Logic Apps Standard** for low-code, connector-rich orchestration of SaaS and on-premises workflows.
- **Azure Event Grid** to propagate change notifications and trigger Synapse pipelines.
- **Azure Synapse Analytics** (serverless SQL, dedicated SQL for metadata, and multiple Spark pools) for data engineering, governance, and analytics.
- **Azure AI (Cognitive Services)** to provide scalable machine learning APIs and enrichments with private connectivity.
- **Azure Data Lake Storage Gen2** as the central data lake with raw, curated, and consumption zones.
- **Azure Maps** for spatial enrichment when required.
- **Microsoft Purview**, **Azure Monitor / Log Analytics**, and **Application Insights** for governance and observability.

## Networking architecture (without Azure Firewall)
To satisfy GDPR requirements, reduce operational overhead, and protect the platform from public exposure, the networking design adopts a lightweight hub-and-spoke topology without Azure Firewall. Security relies on private connectivity, subnet isolation, and Azure-native controls.

### 1. Topology
- Deploy or reuse a small **connectivity hub VNet** that can host VPN/ExpressRoute gateways, Azure Bastion, and DNS forwarders.
- Create a dedicated **data platform spoke VNet** peered to the hub. Reserve ample address space (e.g., /22) for integration workloads, Synapse managed private endpoints, and future expansion.
- Use **site-to-site VPN or ExpressRoute** to reach on-premises systems when needed. Until then, the spoke operates independently with private endpoints.

### 2. Subnet layout in the data platform spoke
- **Integration subnet**: hosts Function Apps (Premium/Elastic plan), Logic Apps Standard, and optional containerised integration runtimes with VNet integration enabled.
- **Synapse managed workspace**: uses Synapse-managed VNet with data exfiltration protection. Configure managed private endpoints for ADLS Gen2, Azure SQL (metadata), Event Grid, Key Vault, and Log Analytics.
- **Self-hosted Integration Runtime subnet**: deploy a VM scale set or Azure Container Instances to reach on-premises data sources where required.
- **Reserved subnets**: keep additional subnets (/26) available for future services (e.g., Purview managed VNet, Databricks with VNet injection, AKS for advanced ML scenarios).

### 3. Private connectivity
- Enable **Private Endpoints** for ADLS Gen2, Synapse workspace endpoints, Azure SQL, Event Grid, Key Vault, Purview, and storage accounts. Associate the corresponding **Private DNS zones** with the hub and spoke VNets to resolve private FQDNs.
- For outbound traffic that must reach the public internet (e.g., GitHub, SaaS APIs), attach a **NAT Gateway** to the integration subnet to provide consistent egress IP addresses without introducing a full firewall appliance.

### 4. Security controls
- Apply **Network Security Groups (NSGs)** to each subnet, restricting east-west traffic to only the necessary flows (e.g., Functions → Synapse endpoints, Integration Runtime → on-premises connectors). Document required service tags (AzureMonitor, Storage, etc.) to streamline operations for the small data team.
- Leverage **Managed Identities** and **Azure AD authentication** end-to-end; avoid storing secrets in code. Use **Key Vault** (with private endpoint) for any required keys or connection strings.
- Enforce **Azure Policy** assignments to guarantee Swiss region deployment, Private Link usage, and encryption with Microsoft-managed keys as mandated.

### 5. Access patterns
- Expose curated data through Synapse serverless SQL endpoints, Azure Functions (API façade), or managed file delivery via Logic Apps. All endpoints are AAD-protected and accessed privately or via Application Gateway/WAF if public publishing becomes necessary later.
- Power BI, Power Apps, and Azure Static Web Apps consume data over secure channels (AAD/OAuth), ensuring no direct inbound connectivity to the data platform resources.

### 6. Operations and monitoring
- Centralise diagnostics in **Log Analytics** and **Application Insights**, both reachable via private endpoints.
- Implement **Azure Monitor alerts** for ingestion failures, Synapse job run health, and NSG rule change detection. Track data quality metrics within Synapse pipelines or Spark notebooks and feed results into dashboards or automated notifications.

### 7. Scalability considerations
- Provision multiple **Synapse Spark pools** (e.g., small, medium, large) with auto-pause/auto-scale. Tag workloads to route jobs to the appropriate pool and allow concurrent execution without contention.
- Maintain a lightweight **infrastructure-as-code** repository (Bicep/Terraform) defining VNets, subnets, private endpoints, and service deployments. Integrate with GitHub Actions or Azure DevOps for automated deployments managed by the data operations team.

This networking strategy minimises operational burden by avoiding Azure Firewall while still providing strong isolation through VNets, private endpoints, and NSGs. It ensures compliant, secure connectivity for ingestion, processing, and consumption workloads with room for future enhancements.

## Infrastructure as Code layout

The `infra/` directory introduces a modular [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview) codebase that provisions the core platform resources:

- `main.bicep` orchestrates shared services (Log Analytics, networking, Key Vault), data landing zones (ADLS Gen2), orchestration runtimes (Azure Functions, Logic App Standard), analytics engines (Synapse workspace and Spark pools), Azure Maps, Azure AI services, and integration primitives (Event Grid). Parameters provide environment-specific values such as the name prefix, Synapse SQL admin credentials, and optional IP allow lists.
- `modules/` contains reusable building blocks for monitoring, networking, private DNS, secure storage, application hosting, Logic Apps, Event Grid, Synapse, Azure Maps, and Azure AI (Cognitive Services).

> **Note:** The repository assumes Bicep CLI version `0.20` or later for deployment. Use the helper script in `scripts/install-azure-tools.sh` to install both the Azure CLI and the Bicep CLI on Debian/Ubuntu environments before running `bicep build` or `az deployment` commands. Future updates will introduce CI/CD workflows to validate and publish the infrastructure templates automatically.

## Local tooling

Before running validation commands such as `bicep build` or `az deployment sub create`, install the required CLIs:

```bash
sudo ./scripts/install-azure-tools.sh
```

The script installs the Azure CLI from the Microsoft package repository and bootstraps the matching Bicep CLI version via `az bicep install`.

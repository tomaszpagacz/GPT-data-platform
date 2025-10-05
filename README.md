# GPT Data Platform

## Overview
This repository implements a comprehensive, Azure-native data analytics platform that ingests heterogeneous sources into Azure Data Lake Storage Gen2. The solution emphasizes cost efficiency, GDPR-compliant operations, and extensibility for future machine learning and analytics workloads.

## Core Components

### Data Processing & Analytics
- **Azure Synapse Analytics**
  - Serverless SQL for ad-hoc queries
  - Dedicated SQL pools for metadata
  - Multiple Spark pools for data engineering
  - Self-hosted Integration Runtime for hybrid scenarios

### Event Processing & Integration
- **Azure Event Grid** & **Event Hub**
  - Storage account monitoring
  - Event-driven architectures
  - Real-time data processing
  
### Compute & Processing
- **Azure Functions** 
  - Event-driven ingestion
  - Custom API facades
  - Lightweight data transformations

- **Azure Logic Apps Standard**
  - Workflow orchestration
  - SaaS integration
  - Business process automation

### Storage & Data Management
- **Azure Data Lake Storage Gen2**
  - Raw data landing
  - Curated datasets
  - Consumption-ready data

### AI & Enrichment
- **Azure AI (Cognitive Services)**
  - Machine learning APIs
  - Data enrichment
  - Private connectivity

- **Azure Maps**
  - Spatial data processing
  - Location intelligence
  - Geospatial analytics

### Security & Monitoring
- **Azure Monitor / Application Insights**
  - Comprehensive logging
  - Performance monitoring
  - Custom dashboards

- **Private Endpoints & NSGs**
  - Network isolation
  - Secure access
  - Traffic control
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

## Infrastructure as Code

### Core Infrastructure (`/infra`)
- `main.bicep` - Primary deployment template
- `modules/` - Reusable components
  - `apiManagement.bicep` - API Management setup
  - `eventing.bicep` - Event Grid & Event Hub
  - `synapse.bicep` - Synapse workspace & pools
  - `synapse-shir.bicep` - Self-hosted runtime
  - `monitoring.bicep` - Observability stack
  - `networking.bicep` - Network components
  - `storage.bicep` - Data Lake configuration

### Environment Configuration (`/infra/params`)
- Development (`dev.*parameters.json`)
- Testing (`sit.*parameters.json`)
- Production (`prod.*parameters.json`)

> **Note:** The repository assumes Bicep CLI version `0.20` or later for deployment. Use the helper script in `scripts/install-azure-tools.sh` to install both the Azure CLI and the Bicep CLI on Debian/Ubuntu environments before running `bicep build` or `az deployment` commands. Future updates will introduce CI/CD workflows to validate and publish the infrastructure templates automatically.

## Deployment & Operations

### Prerequisites
1. Azure CLI & Bicep
   ```bash
   ./scripts/install-azure-tools.sh
   ```

2. Required Azure Resources:
   - Resource Group
   - Virtual Network
   - Private DNS Zones
   - Key Vault

### Deployment Process
1. Base Infrastructure:
   ```bash
   az deployment group create \
     --resource-group <rg-name> \
     --template-file infra/main.bicep \
     --parameters @infra/params/dev.parameters.json
   ```

2. Event Infrastructure:
   ```bash
   ./scripts/deploy-eventing.sh <env> <region> <resource-group>
   ```

3. Synapse SHIR:
   ```bash
   az pipeline create \
     --name "Synapse-SHIR-Deployment" \
     --yml-path infra/pipeline/synapse-shir-pipeline.yml
   ```

## Development Guides

### Documentation
- [API Management](docs/api-management-deployment.md)
- [Event Infrastructure](docs/eventing-infrastructure.md)
- [Functions Development](docs/functions-development.md)
- [Logic Apps](docs/logic-apps-development.md)
- [RBAC Management](docs/rbac-management.md)
- [Security Assessment](docs/security-assessment.md)

### Helper Scripts (`/helpers`)
- Environment setup
- Dependency management
- Testing utilities
- Validation tools

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Create a pull request

## License
This project is licensed under the MIT License - see the LICENSE file for details

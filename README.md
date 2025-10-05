# GPT Data Platform

> **Last Updated:** 2025-01-15
> **Audience:** Developer, Architect, Operator
> **Prerequisites:** Azure subscription, Azure CLI, basic understanding of Azure services

## Overview

The GPT Data Platform is a comprehensive, Azure-native data analytics solution that ingests heterogeneous data sources into Azure Synapse Analytics and Data Lake Storage Gen2. The platform emphasizes cost efficiency, GDPR-compliant operations, and extensibility for future machine learning and analytics workloads.

## Table of Contents

- [Core Components](#core-components)
- [Architecture Overview](#architecture-overview)
- [Infrastructure as Code](#infrastructure-as-code)
- [Deployment & Operations](#deployment--operations)
- [Development Guides](#development-guides)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Core Components

### Data Processing & Analytics
- **Azure Synapse Analytics**
  - Serverless SQL for ad-hoc queries
  - Dedicated SQL pools for metadata
  - Multiple Spark pools for data engineering
  - Self-hosted Integration Runtime for hybrid scenarios

### Event Processing & Integration
- **Azure Event Grid & Event Hub**
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

## Architecture Overview

### Networking Architecture
The platform adopts a lightweight hub-and-spoke topology optimized for GDPR compliance and operational efficiency:

- **Hub VNet**: Connectivity services (VPN/ExpressRoute gateways, Azure Bastion, DNS forwarders)
- **Spoke VNet**: Data platform workloads with subnet isolation
- **Private Endpoints**: Secure access to all Azure services
- **Network Security Groups**: Traffic control and east-west security
- **NAT Gateway**: Controlled outbound internet access

### Security Architecture
- **Azure AD Integration**: End-to-end identity and access management
- **Managed Identities**: Service authentication without secrets
- **Key Vault**: Centralized secret management
- **Azure Policy**: Governance and compliance enforcement
- **Private Link**: Network-level security for all services

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

### CI/CD Pipeline (`/infra/pipeline`)
- `azure-pipelines.yml` - Complete CI/CD pipeline with security scanning
- Multi-stage deployment (Pre-deployment → Security Scan → Dependency Validation → Build → Deploy)
- Automated testing and validation gates

## Deployment & Operations

### Prerequisites

1. **Azure CLI & Bicep**
   ```bash
   ./scripts/install-azure-tools.sh
   ```

2. **Required Azure Resources**
   - Resource Group
   - Virtual Network
   - Private DNS Zones
   - Key Vault

### Quick Start Deployment

1. **Base Infrastructure**
   ```bash
   az deployment group create \
     --resource-group <rg-name> \
     --template-file infra/main.bicep \
     --parameters @infra/params/dev.main.parameters.json
   ```

2. **Event Infrastructure**
   ```bash
   ./scripts/deploy-eventing.sh <name-prefix> <env> <region> <resource-group>
   ```

3. **Synapse Workspace**
   ```bash
   az pipeline create \
     --name "Synapse-CICD-Pipeline" \
     --yml-path infra/pipeline/synapse-cicd-pipeline.yml
   ```

4. **Synapse SHIR**
   ```bash
   az pipeline create \
     --name "Synapse-SHIR-Deployment" \
     --yml-path infra/pipeline/synapse-shir-pipeline.yml
   ```

### Available Workflows

#### Logic Apps Workflows (`src/logic-apps/workflows`)
- **wf-schedule-synapse**: Daily scheduled Synapse pipeline execution
  - Runs at 4:00 AM UTC with jitter to prevent thundering herd
  - Uses blob lease for leader election across multiple instances
  - Calls Synapse pipelines with date parameters via REST API

- **wf-queue-synapse**: Event-driven Synapse pipeline execution
  - Processes messages from Azure Storage Queues with deduplication
  - Config-driven routing based on blob path patterns
  - Idempotent processing with correlation IDs and dead letter queues

## Development Guides

### 📚 Documentation
- [Documentation Index](docs/README.md) - Complete documentation overview
- [Platform Architecture](docs/architecture.md) - System design and components
- [Security Assessment](docs/security-assessment.md) - Security architecture and compliance

### 🚀 Development
- [Azure Functions Development](docs/functions-development.md) - Function development guide
- [Logic Apps Development](docs/logic-apps-development.md) - Workflow development guide
- [API Management](docs/api-management-deployment.md) - API gateway configuration

### ⚙️ Infrastructure & Operations
- [Modern Platform Implementation](docs/modern-platform-implementation-guide.md) - Infrastructure deployment
- [RBAC Implementation](docs/rbac-implementation-guide.md) - Access control setup
- [Deployment Troubleshooting](docs/deployment-troubleshooting.md) - Common deployment issues
- [Cost Optimization](docs/cost-optimization.md) - Cost management strategies

### 🔧 Helper Scripts (`/helpers`)
- Environment setup and validation
- Dependency management
- Testing utilities
- Configuration tools

## Contributing

1. **Setup Development Environment**
   ```bash
   ./setup-environment.sh
   ```

2. **Follow Development Workflow**
   - Fork the repository
   - Create a feature branch from `main`
   - Make changes following established patterns
   - Run tests and validation
   - Submit a pull request

3. **Documentation Standards**
   - Follow the [Documentation Index](docs/README.md) standards
   - Update documentation for any new features
   - Include appropriate metadata and cross-references

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

### Getting Help
- Review [Deployment Troubleshooting](docs/deployment-troubleshooting.md) for common issues
- Check [Documentation Index](docs/README.md) for comprehensive guides
- Consult team documentation for internal procedures

### Related Projects
- [Azure Synapse Analytics Documentation](https://docs.microsoft.com/en-us/azure/synapse-analytics/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)

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
### Related Projects
- [Azure Synapse Analytics Documentation](https://docs.microsoft.com/en-us/azure/synapse-analytics/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)

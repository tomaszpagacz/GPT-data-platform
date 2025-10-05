# Platform Architecture

## System Architecture

```mermaid
graph TB
    subgraph Data Sources
        API[External APIs] --> AF[Azure Functions]
        Files[File Systems] --> SA[Storage Account]
        DB[(Databases)] --> SHIR[Self-hosted IR]
        IoT[IoT Devices] --> EH1[IoT Event Hub]
    end

    subgraph Integration Layer
        AF --> |Custom Processing| EG[Event Grid]
        SA --> |Change Events| EG
        SHIR --> |Data Movement| SYN[Synapse Analytics]
        EH1 --> |Real-time Data| EH2[Event Hub]
    end

    subgraph Processing Layer
        EG --> |Events| EH2
        EH2 --> |Stream Processing| SYN
        SYN --> |Transform| DL[Data Lake]
        
        subgraph Synapse Analytics
            SP[Spark Pools]
            SQL[Serverless SQL]
            DW[Dedicated SQL]
        end
    end

    subgraph Enrichment Layer
        CS[Cognitive Services] --> |ML Enrichment| SYN
        AM[Azure Maps] --> |Spatial Data| SYN
    end

    subgraph Storage Layer
        DL --> |Raw| RAW[Raw Zone]
        DL --> |Curated| CUR[Curated Zone]
        DL --> |Consumption| CONS[Consumption Zone]
    end

    subgraph Security & Monitoring
        KV[Key Vault] --> |Secrets| SYN
        KV --> |Secrets| AF
        MI[Managed Identity] --> |Auth| KV
        LA[Log Analytics] --> |Logs| MON[Azure Monitor]
        AI[App Insights] --> |Telemetry| MON
    end

    subgraph API Management
        APIM[API Management] --> |APIs| AF
        APIM --> |APIs| SYN
    end

    classDef azureService fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#008272,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef processing fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    
    class AF,EH1,EH2,EG,SYN,CS,AM,APIM azureService
    class SA,DL,RAW,CUR,CONS storage
    class KV,MI security
    class SP,SQL,DW processing
```

## Component Descriptions

### Integration Components
- **Azure Functions**: Event-driven compute for custom integrations
- **Event Grid**: Event routing and distribution
- **Event Hub**: Real-time data ingestion and stream processing
- **Self-hosted IR**: On-premises data integration runtime

### Processing Components
- **Synapse Analytics**:
  - Spark Pools: Distributed data processing
  - Serverless SQL: Ad-hoc analytics
  - Dedicated SQL: Performance-critical workloads

### Storage Components
- **Data Lake Zones**:
  - Raw: Original, unmodified data
  - Curated: Cleaned and transformed data
  - Consumption: Business-ready datasets

### Security Components
- **Key Vault**: Centralized secret management
- **Managed Identities**: Service authentication
- **Private Endpoints**: Network isolation

### Monitoring Components
- **Azure Monitor**: Unified monitoring
- **App Insights**: Application telemetry
- **Log Analytics**: Log aggregation and analysis

## Security Architecture

```mermaid
graph TB
    subgraph Authentication
        AAD[Azure AD] --> |Identity| MI[Managed Identity]
        MI --> |Auth| Resources
    end

    subgraph Network Security
        NSG[NSG Rules] --> |Filter| VNet[Virtual Network]
        PE[Private Endpoints] --> |Secure Access| Resources
        VNet --> |Isolation| Resources
    end

    subgraph Resources
        KV[Key Vault]
        SA[Storage Account]
        SYN[Synapse]
        EH[Event Hub]
    end

    subgraph Access Control
        RBAC[RBAC Roles] --> |Permissions| Resources
        Policies[Azure Policies] --> |Governance| Resources
    end

    subgraph Monitoring
        LA[Log Analytics]
        AM[Azure Monitor]
        Resources --> |Logs| LA
        Resources --> |Metrics| AM
    end

    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef network fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    
    class AAD,MI,KV,RBAC,Policies security
    class NSG,PE,VNet network
    class LA,AM monitoring
```

## Integration Patterns

```mermaid
sequenceDiagram
    participant API as External API
    participant AF as Azure Function
    participant EG as Event Grid
    participant EH as Event Hub
    participant SYN as Synapse
    participant DL as Data Lake

    API->>AF: HTTP Request
    AF->>EG: Publish Event
    EG->>EH: Forward Event
    EH->>SYN: Stream Processing
    SYN->>DL: Store Results
    
    par Monitoring
        AF->>AI: Log Telemetry
        EH->>AM: Log Metrics
        SYN->>LA: Log Analytics
    end
```

## Network Topology

```mermaid
graph TB
    subgraph Hub VNet
        FW[Azure Firewall]
        BAST[Azure Bastion]
        DNS[DNS Forwarder]
    end

    subgraph Spoke VNet
        subgraph Integration Subnet
            AF[Functions]
            LA[Logic Apps]
        end
        
        subgraph Data Subnet
            SYN[Synapse]
            SHIR[Self-hosted IR]
        end
        
        subgraph Private Endpoint Subnet
            PE1[Storage PE]
            PE2[KeyVault PE]
            PE3[EventHub PE]
        end
    end

    subgraph Security
        NSG1[Integration NSG]
        NSG2[Data NSG]
        NSG3[PE NSG]
    end

    Hub VNet ---|Peering| Spoke VNet
    NSG1 --> Integration Subnet
    NSG2 --> Data Subnet
    NSG3 --> Private Endpoint Subnet

    classDef network fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef compute fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff

    class FW,BAST,DNS,PE1,PE2,PE3 network
    class NSG1,NSG2,NSG3 security
    class AF,LA,SYN,SHIR compute
```

## Event Processing Flow

```mermaid
graph TB
    subgraph Sources
        SA[Storage Account] --> |Blob Events| EG
        AF[Azure Functions] --> |Custom Events| EG
        API[External APIs] --> |Data Events| AF
    end

    subgraph Event Processing
        EG[Event Grid Topic] --> |Forward| EH[Event Hub]
        EH --> |Consumer Group 1| SP1[Spark Processing]
        EH --> |Consumer Group 2| SP2[Stream Analytics]
        EH --> |Consumer Group 3| MON[Monitoring]
    end

    subgraph Storage
        SP1 --> |Processed Data| DL[Data Lake]
        SP2 --> |Real-time Data| DL
    end

    subgraph Monitoring
        MON --> |Metrics| AM[Azure Monitor]
        MON --> |Logs| LA[Log Analytics]
        AM --> |Alert| ALT[Alerts]
        LA --> |Query| WB[Workbooks]
    end

    classDef source fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef processing fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#008272,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff

    class SA,AF,API source
    class EG,EH,SP1,SP2 processing
    class DL storage
    class MON,AM,LA,ALT,WB monitoring
```

## Component-Specific Architectures

### Synapse Analytics Architecture

```mermaid
graph TB
    subgraph Data Sources
        DL[(Data Lake)] --> |Raw Data| SYN
        EH[Event Hub] --> |Streaming| SYN
        DB[(External DB)] --> |SHIR| SYN
    end

    subgraph Synapse Analytics
        subgraph Compute Resources
            SP[Spark Pools] --> |Process| DW
            SS[Serverless SQL] --> |Query| DW
            DW[Dedicated SQL Pool] --> |Serve| META[Metadata]
        end

        subgraph Integration
            SHIR[Self-hosted IR] --> |Load| STG[Staging]
            STG --> |Transform| DW
        end

        subgraph Security
            PE[Private Endpoints] --> |Secure Access| Compute Resources
            MI[Managed Identity] --> |Auth| PE
        end

        subgraph Monitoring
            METRICS[Metrics] --> MON
            LOGS[Logs] --> MON
            MON[Monitoring] --> |Alert| ALT[Alerts]
        end
    end

    subgraph Data Consumption
        DW --> |Serve| PWR[Power BI]
        DW --> |API| APIM[API Management]
        META --> |Lineage| PUR[Purview]
    end

    classDef source fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef compute fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#008272,stroke:#fff,stroke-width:2px,color:#fff

    class DL,EH,DB source
    class SP,SS,DW,STG compute
    class PE,MI security
    class METRICS,LOGS,MON,ALT monitoring
```

### Event Processing Architecture

```mermaid
graph TB
    subgraph Event Sources
        SA[Storage Account] --> |Blob Events| EG
        FN[Azure Functions] --> |Custom Events| EG
        DB[(Databases)] --> |CDC Events| EG
    end

    subgraph Event Grid Infrastructure
        EG[Event Grid Topic] --> |Route| EH
        EG --> |Route| WH[Webhooks]
        EG --> |Route| FN2[Functions]

        subgraph Topic Configuration
            FLT[Filters]
            RTN[Retry Policy]
            DLQ[Dead Letter]
        end
    end

    subgraph Event Hub Infrastructure
        EH[Event Hub Namespace]
        
        subgraph Event Hubs
            EH1[Storage Events] --> CG1[Consumer Group 1]
            EH1 --> CG2[Consumer Group 2]
            EH2[Custom Events] --> CG3[Consumer Group 3]
        end

        subgraph Processing
            CG1 --> |Stream| SP[Spark Processing]
            CG2 --> |Monitor| LA[Log Analytics]
            CG3 --> |Process| AF[Azure Function]
        end
    end

    subgraph Security & Networking
        subgraph Private Network
            PE1[Event Grid PE]
            PE2[Event Hub PE]
        end
        
        subgraph Network Security
            NSG[NSG Rules]
            RT[Route Table]
        end
    end

    subgraph Monitoring
        LA --> |Logs| AM[Azure Monitor]
        AM --> |Alert| ALT[Alerts]
        AM --> |Visual| DB2[Dashboard]
    end

    classDef source fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef processing fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#008272,stroke:#fff,stroke-width:2px,color:#fff

    class SA,FN,DB source
    class EG,EH,EH1,EH2,SP,AF processing
    class PE1,PE2,NSG,RT security
    class LA,AM,ALT,DB2 monitoring
```

### Storage Architecture

```mermaid
graph TB
    subgraph Data Lake Storage
        subgraph Raw Zone
            RB[Blob Storage] --> |Ingest| RC[Raw Container]
            RC --> |RBAC| RAP[Raw Access Policy]
        end

        subgraph Curated Zone
            CB[Blob Storage] --> |Process| CC[Curated Container]
            CC --> |RBAC| CAP[Curated Access Policy]
        end

        subgraph Consumption Zone
            PB[Blob Storage] --> |Serve| PC[Presentation Container]
            PC --> |RBAC| PAP[Presentation Access Policy]
        end
    end

    subgraph Data Movement
        ADF[Data Factory] --> |Copy| RB
        SYN[Synapse] --> |Transform| CB
        EH[Event Hub] --> |Stream| RB
    end

    subgraph Security
        subgraph Authentication
            MI[Managed Identity]
            RBAC[RBAC Roles]
            SAS[SAS Tokens]
        end

        subgraph Network Security
            PE1[Storage PE]
            NSG[NSG Rules]
            FW[Storage Firewall]
        end

        subgraph Encryption
            CMK[Customer Managed Keys]
            SSE[Storage Service Encryption]
            ST[Secure Transfer]
        end
    end

    subgraph Monitoring
        MET[Metrics] --> AM[Azure Monitor]
        LOG[Logs] --> LA[Log Analytics]
        AM --> |Alert| ALT[Alerts]
        LA --> |Query| WB[Workbooks]
    end

    classDef storage fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef movement fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#008272,stroke:#fff,stroke-width:2px,color:#fff

    class RB,CB,PB,RC,CC,PC storage
    class MI,RBAC,SAS,PE1,NSG,FW,CMK,SSE,ST security
    class ADF,SYN,EH movement
    class MET,LOG,AM,LA,ALT,WB monitoring
```

### API Management Architecture

```mermaid
graph TB
    subgraph API Management
        subgraph Gateway
            APIM[API Gateway]
            POL[Policies]
            RT[Rate Limiting]
            CA[Cache]
        end

        subgraph Security
            OAuth[OAuth 2.0]
            JWT[JWT Validation]
            CORS[CORS Policy]
        end

        subgraph Backend Services
            AF[Azure Functions]
            LA[Logic Apps]
            SYN[Synapse SQL]
        end
    end

    subgraph Client Apps
        MOB[Mobile Apps]
        WEB[Web Apps]
        SPA[SPA]
    end

    subgraph Network Security
        PE[Private Endpoint]
        NSG[NSG Rules]
        WAF[WAF Policy]
    end

    subgraph Monitoring
        APM[App Insights]
        LOG[Log Analytics]
        MET[Metrics]
    end

    MOB --> |Request| APIM
    WEB --> |Request| APIM
    SPA --> |Request| APIM

    APIM --> |Auth| OAuth
    APIM --> |Validate| JWT
    APIM --> |Allow| CORS

    APIM --> |Execute| POL
    APIM --> |Limit| RT
    APIM --> |Check| CA

    APIM --> |Route| AF
    APIM --> |Route| LA
    APIM --> |Route| SYN

    PE --> |Secure| APIM
    NSG --> |Filter| PE
    WAF --> |Protect| APIM

    APIM --> |Log| APM
    APIM --> |Analytics| LOG
    APIM --> |Monitor| MET

    classDef gateway fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff
    classDef backend fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#008272,stroke:#fff,stroke-width:2px,color:#fff

    class APIM,POL,RT,CA gateway
    class OAuth,JWT,CORS,PE,NSG,WAF security
    class AF,LA,SYN backend
    class APM,LOG,MET monitoring
```

## Capacity Planning & Scaling

### Compute Resource Scaling

```mermaid
graph TB
    subgraph Synapse Spark Pools
        direction TB
        subgraph Small Pool Configuration
            SS[Small Pool] --> |3-12 nodes| SN[Node Size: Small]
            SN --> |Auto-scale| ST[Timeout: 15min]
        end
        
        subgraph Medium Pool Configuration
            MS[Medium Pool] --> |5-20 nodes| MN[Node Size: Medium]
            MN --> |Auto-scale| MT[Timeout: 30min]
        end
        
        subgraph Large Pool Configuration
            LS[Large Pool] --> |10-40 nodes| LN[Node Size: Large]
            LN --> |Auto-scale| LT[Timeout: 60min]
        end
    end

    subgraph Azure Functions
        direction TB
        subgraph Consumption Plan
            CP[Consumption] --> |Auto-scale| CI[Instances: 0-200]
            CI --> |Timeout| CT[Timeout: 5min]
        end
        
        subgraph Premium Plan
            PP[Premium] --> |Pre-warmed| PI[Instances: 1-20]
            PI --> |Scale| PT[Rules: CPU/Memory]
        end
    end

    subgraph Event Processing
        direction TB
        subgraph Event Hub Standard
            EHS[Standard] --> |TU: 1-20| EHSS[Auto-inflate]
            EHSS --> |Partitions| EHSP[Count: 4]
        end
        
        subgraph Event Hub Premium
            EHP[Premium] --> |TU: 1-40| EHPS[Zone Redundant]
            EHPS --> |Partitions| EHPP[Count: 8]
        end
    end

    classDef small fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef medium fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef large fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff

    class SS,SN,ST small
    class MS,MN,MT medium
    class LS,LN,LT large
```

### Storage Capacity Planning

```mermaid
graph TB
    subgraph Data Lake Storage
        direction TB
        subgraph Raw Zone Capacity
            RZ[Raw Zone] --> |Initial| RZI[500 TB]
            RZI --> |Growth| RZG[20% Annual]
        end
        
        subgraph Curated Zone Capacity
            CZ[Curated Zone] --> |Initial| CZI[200 TB]
            CZI --> |Growth| CZG[30% Annual]
        end
        
        subgraph Consumption Zone Capacity
            PZ[Consumption Zone] --> |Initial| PZI[100 TB]
            PZI --> |Growth| PZG[40% Annual]
        end
    end

    subgraph Performance Tiers
        direction TB
        subgraph Hot Tier
            HT[Hot Storage] --> |IOPS| HTI[Up to 20k]
            HTI --> |Latency| HTL[<10ms]
        end
        
        subgraph Cool Tier
            CT[Cool Storage] --> |Access| CTI[Infrequent]
            CTI --> |Latency| CTL[<60ms]
        end
        
        subgraph Archive Tier
            AT[Archive] --> |Access| ATI[Rare]
            ATI --> |Latency| ATL[Hours]
        end
    end

    subgraph Throughput Scaling
        direction TB
        subgraph Standard
            STD[Standard] --> |IOPS| STDI[5000]
            STDI --> |Throughput| STDT[50 MB/s]
        end
        
        subgraph Premium
            PRE[Premium] --> |IOPS| PREI[20000]
            PREI --> |Throughput| PRET[200 MB/s]
        end
    end

    classDef hot fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef cool fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef archive fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff

    class HT,HTI,HTL hot
    class CT,CTI,CTL cool
    class AT,ATI,ATL archive
```

### Cost Optimization Patterns

```mermaid
graph TB
    subgraph Compute Cost Optimization
        direction TB
        subgraph Auto-scaling Rules
            AR[Auto-scale] --> |CPU| CPU[>70% Scale Out]
            AR --> |Memory| MEM[>80% Scale Out]
            AR --> |Queue| QUE[>100 Messages]
        end
        
        subgraph Scale Down Rules
            SD[Scale Down] --> |CPU| CPUD[<30% Scale In]
            SD --> |Memory| MEMD[<40% Scale In]
            SD --> |Queue| QUED[<10 Messages]
        end
    end

    subgraph Storage Cost Optimization
        direction TB
        subgraph Lifecycle Management
            LM[Lifecycle] --> |Hot| H90[90 Days]
            LM --> |Cool| C180[180 Days]
            LM --> |Archive| A365[365 Days]
        end
        
        subgraph Compression
            CP[Compression] --> |Raw| CPR[No Compression]
            CP --> |Curated| CPC[Column Compression]
            CP --> |Archive| CPA[Row Compression]
        end
    end

    subgraph Reserved Capacity
        direction TB
        subgraph Commitment Levels
            CL[Reserved] --> |1 Year| Y1[10-15% Savings]
            CL --> |3 Years| Y3[20-25% Savings]
        end
        
        subgraph Resource Types
            RT[Resources] --> |Storage| RTS[Reserved TB]
            RT --> |Compute| RTC[Reserved vCores]
        end
    end

    classDef scaling fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef reserved fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff

    class AR,CPU,MEM,QUE scaling
    class LM,H90,C180,A365 storage
    class CL,Y1,Y3 reserved
```

### Workload-Based Scaling Scenarios

```mermaid
sequenceDiagram
    participant M as Monitoring
    participant S as Scaling Engine
    participant R as Resources
    participant A as Alerts

    Note over M,A: Batch Processing Scenario
    M->>S: High CPU Detection
    S->>R: Scale Out Spark Pool
    R->>M: Resource Metrics
    M->>A: Scale Event Alert

    Note over M,A: Real-time Processing
    M->>S: Message Backlog
    S->>R: Increase TUs
    R->>M: Throughput Metrics
    M->>A: Scaling Alert

    Note over M,A: Interactive Query
    M->>S: Concurrent Users
    S->>R: Scale SQL Pool
    R->>M: Performance Metrics
    M->>A: Scale Notification
```

### Environment-Based Scaling Matrix

```mermaid
graph TB
    subgraph Development
        direction TB
        subgraph Dev Compute
            DC[Compute] --> |Spark| DS[Small Pool]
            DC --> |SQL| DSQ[On-demand]
        end
        
        subgraph Dev Storage
            DST[Storage] --> |ADLS| DSA[Standard]
            DST --> |Backup| DSB[LRS]
        end
    end

    subgraph Testing
        direction TB
        subgraph Test Compute
            TC[Compute] --> |Spark| TS[Medium Pool]
            TC --> |SQL| TSQ[Standard]
        end
        
        subgraph Test Storage
            TST[Storage] --> |ADLS| TSA[Standard]
            TST --> |Backup| TSB[ZRS]
        end
    end

    subgraph Production
        direction TB
        subgraph Prod Compute
            PC[Compute] --> |Spark| PS[Large Pool]
            PC --> |SQL| PSQ[Premium]
        end
        
        subgraph Prod Storage
            PST[Storage] --> |ADLS| PSA[Premium]
            PST --> |Backup| PSB[GRS]
        end
    end

    classDef dev fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff
    classDef test fill:#004B50,stroke:#fff,stroke-width:2px,color:#fff
    classDef prod fill:#B4009E,stroke:#fff,stroke-width:2px,color:#fff

    class DC,DS,DSQ,DST,DSA,DSB dev
    class TC,TS,TSQ,TST,TSA,TSB test
    class PC,PS,PSQ,PST,PSA,PSB prod
```
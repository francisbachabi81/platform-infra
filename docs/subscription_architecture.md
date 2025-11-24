# Subscription Architecture & Deployment Model

This document provides an updated and expanded overview of how subscriptions are structured and how Terraform deploys resources across Azure Government (**hrz**) and Azure Commercial (**pub**).  
It incorporates platform, core, network, and observability stack behaviors.

---

# Subscription Topology (6 Subscriptions per Cloud)

Each cloud (Azure Government / Azure Commercial) uses an identical subscription structure:

| Plane | Subscription Name | Purpose |
|-------|-------------------|---------|
| **nonprod** | **Intterra NonProd Core** | Shared-network + core resources for dev & qa |
| **nonprod** | **Intterra Dev** | Application infrastructure for development workloads |
| **nonprod** | **Intterra QA** | Application infrastructure for testing workloads |
| **prod** | **Intterra Prod Core** | Shared-network + core resources for uat & prod |
| **prod** | **Intterra UAT** | Application infrastructure for user acceptance testing |
| **prod** | **Intterra Prod** | Application infrastructure for production |

This gives **6 total per cloud**, **12 total** across hrz + pub.

---

# Deployment Logic: Plane vs Environment

Terraform uses both **plane** (`nonprod`, `prod`) and **environment** (`dev`, `qa`, `uat`, `prod`) to determine *which subscription* receives the resources.

---

## Plane-Level Shared Resources → **Core Subscriptions**

The following stacks **always** deploy to the *Core subscription* of the plane:

| Stack | Deploys To |
|-------|------------|
| **Shared Network** | Nonprod Core or Prod Core |
| **Core** | Nonprod Core or Prod Core |

### Shared Network Resources (Plane-Level)

These resources are created once per plane (`nonprod` or `prod`):

- Hub VNet  
- Spoke VNets (delegated per env through platform-app)  
- Private DNS Zones  
- DNS Private Resolver (inbound/outbound)  
- Azure Firewall (optional)  
- Bastion (optional)  
- VPN Gateway (optional)  
- Application Gateway (optional)  
- Azure Front Door (optional)  
- NSGs for every subnet  
- Public DNS (optional)

### Core Resources (Plane-Level)

These provide observability and shared services for **all environments** in the plane:

| Resource | hrz | pub |
|---|:--:|:--:|
| Core RG | ✅ | ✅ |
| Log Analytics Workspace | ✅ | ✅ |
| Application Insights | ✅ | ✅ |
| Recovery Services Vault | ✅ | ✅ |

---

## Environment-Level Resources → **Environment Subscriptions**

These stacks deploy **only to their corresponding env subscription**:

| Stack | Deploys To | Notes |
|-------|------------|--------|
| **Platform App** | Dev / QA / UAT / Prod | Application infrastructure |
| **Observability** | same env subscription | Diagnostics + alerts |

Environment subscriptions contain *all application-tier resources*—isolated per environment.

---

# Platform-App Stack: What Gets Created Per Product

This matrix defines which resources exist in each cloud, exactly matching the implementation.

| Resource / Module | hrz | pub | Notes |
|---|:--:|:--:|---|
| Key Vault | ✅ | ✅ | Env-level KV |
| Storage Account | ✅ | ✅ | Env-level SA |
| Cosmos (NoSQL) |  | ✅ | Only in pub |
| Communication Service (Email) |  | ✅ | Pub-only; feature-gated |
| AKS Cluster | ✅ | ✅ | Env AKS |
| Service Bus | ✅ | ✅ | When `var.create_servicebus` |
| App Service Plan |  | ✅ | Pub-only |
| Function Apps |  | ✅ | Pub-only |
| Event Hubs |  | ✅ | Dev/Prod only |
| Cosmos PostgreSQL |  | ✅ | Feature-gated |
| PostgreSQL Flex | ✅ | ✅ | Supported everywhere |
| PostgreSQL Replica | ✅* | ✅* | If `pg_replica_enabled=true` and `pg_ha_enabled=false`; typically only QA/Prod |
| Redis Cache | ✅ | ✅ | Env-level Redis |

---

# Observability Stack: Diagnostics & Alerts

Observability **does not create resources**. It attaches:

- Diagnostic settings  
- Activity log alerts  
- Action groups  

…to resources already deployed by Shared Network, Core, or Platform-App.

It covers:

- NSGs  
- Key Vault  
- Storage  
- Service Bus  
- Event Hubs  
- PostgreSQL / Cosmos PG  
- Redis  
- Recovery Services Vault  
- Application Insights  
- VPN Gateway  
- Function Apps  
- Web Apps  
- Application Gateway  
- Azure Front Door  
- Cosmos DB  
- AKS  

Everything is routed to the **Log Analytics Workspace** resolved from core/platform outputs.

---

# Related Documents

- [`docs/folder_structure.md`](folder_structure.md)
- [`docs/network_overview.md`](network_overview.md)
- [`docs/workflows_documentation.md`](workflows_documentation.md)  
- Root [`README.md`](../README.md) links back to this architecture file.


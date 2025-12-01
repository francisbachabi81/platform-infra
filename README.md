# Terraform Infra — Azure Gov & Azure Commercial

This repository contains Terraform configurations and GitHub Actions workflows for deploying shared network, core infrastructure, platform applications, and observability components across:

- **Azure Government** (`hrz`)
- **Azure Commercial** (`pub`)

The project is organized into reusable **modules**, environment/plane-specific **stacks**, and **workflows** that orchestrate plans and applies.

---

## Quick Navigation

### Documentation

- **Subscription Architecture Overview**: [`docs/subscription_architecture.md`](docs/subscription_architecture.md)
- **Repo structure & stacks**: [`docs/folder_structure.md`](docs/folder_structure.md)
- **Workflows & execution order**: [`docs/workflows_documentation.md`](docs/workflows_documentation.md)
- **Secrets schema / GitHub secrets notes**: [`docs/wiki-gh-secrets-hrz-pub.md`](docs/wiki-gh-secrets-hrz-pub.md)
- **Azure VPN Client Setup (Gov + Commercial)**: [`docs/vpn_client_setup.md`](docs/vpn_client_setup.md)

### Stacks

Each stack has its own `README.md` with purpose, inputs, dependencies, and related workflows:

- **Shared Network** – plane-level networking  
  → [`stacks/shared-network/README.md`](stacks/shared-network/README.md)

- **Core** – plane-level shared/core services  
  → [`stacks/core/README.md`](stacks/core/README.md)

- **Platform App** – env-level application infrastructure  
  → [`stacks/platform-app/README.md`](stacks/platform-app/README.md)

- **Platform Registry** – shared ACR for container images (Azure Gov only)  
  → [`stacks/platform-registry/README.md`](stacks/platform-registry/README.md)

- **Observability** – env-level diagnostics and monitoring  
  → [`stacks/observability/README.md`](stacks/observability/README.md)

- **Provision-Secrets** – JSON schemas describing required secrets  
  → [`stacks/provision-secrets/README.md`](stacks/provision-secrets/README.md)

---

## High-Level Layout

```text
readme.md
modules/
stacks/
workflows/
docs/
```

- **`modules/`** – Reusable Terraform modules (vnet, nsg, app-service-plan, postgres-flex, keyvault, storage, etc.).
- **`stacks/`** – Top-level stacks that compose modules into deployable units per plane/environment (plus a shared registry stack).
- **`workflows/`** – GitHub Actions YAML files for plan/apply + secrets + approvals.
- **`docs/`** – Structural documentation for the repo and workflows.

See [`docs/folder_structure.md`](docs/folder_structure.md) for a detailed breakdown.

---

## Azure VPN Client — Connectivity for Nonprod & Prod

The **Shared-Network** stack deploys VPN Gateways for each plane (`nonprod` and `prod`) and each product:

- **Azure Government** (`hrz`)
- **Azure Commercial** (`pub`)

To connect to your VNets, users download an Azure VPN Client profile (`.xml`) and import it into the **Azure VPN Client** (Windows/macOS).

A full guide is available here:

[`VPN Setup Guide`](docs/vpn_client_setup.md)

That page includes:

- Download links for **nonprod** and **prod**
- Links for both **hrz (Gov)** and **pub (Commercial)**
- Step-by-step import instructions  
- Notes for tenant selection, certificate prompts, and split-tunnel behavior

---

## Platform-Registry Stack — Shared ACR (Azure Gov Only)

The **Platform Registry** stack (`stacks/platform-registry/`) provisions a **single Azure Container Registry (ACR)** instance that is:

- **Deployed only in Azure Government (`hrz`)**
- **Always production plane** (no nonprod variant)
- **Shared across workloads** (AKS, app services, jobs) that need to push or pull container images

Key characteristics:

- Lives in the **Azure Gov production subscription**.
- Uses its own Terraform state key
- Creates:
  - One **resource group** dedicated to the registry (for example: `rg-core-pr-usaz-01-reg`).
  - One **ACR** (for example: `acrintterra`).

Typical usage pattern:

- Deployed once via the **Platform Registry** GitHub workflows (for example `registry-plan.yml` / `registry-apply.yml`).  
- Referenced by other stacks (e.g., `platform-app`, AKS modules, CI/CD pipelines) via its **outputs** (login server, ACR ID, name) or via environment-level configuration.

There is **no Azure Commercial registry** in this design; all shared images are stored in the **Gov ACR**.

---

## Platform-App — What Gets Created per Product

> ✅ = created (subject to feature toggles/inputs). Empty = not created for that product.

| Resource / Module | hrz | pub | Notes |
|---|:--:|:--:|---|
| Key Vault | ✅ | ✅ |  |
| Storage Account | ✅ | ✅ |  |
| Cosmos (NoSQL) |  | ✅ |  |
| Communication Service (Email) |  | ✅ | Created only when email/Comms features are enabled (public cloud only) |
| AKS Cluster | ✅ | ✅ |  |
| Service Bus | ✅ | ✅ | When `var.create_servicebus` |
| App Service Plan |  | ✅ | Public only |
| Function Apps |  | ✅ |  |
| Event Hubs |  | ✅ | Dev/Prod only |
| Cosmos PostgreSQL |  | ✅ | When enabled |
| PostgreSQL Flex | ✅  | ✅ |  |
| PostgreSQL Replica | ✅* | ✅* | Replica is created only when pg_replica_enabled=true and pg_ha_enabled=false (mutually exclusive with HA), and typically enabled only for QA and Prod. |
| Redis Cache | ✅ | ✅ |  |

---

## Core Stack — Plane-Level Shared Resources

| Resource | hrz | pub |
|---|:--:|:--:|
| Core RG | ✅ | ✅ |
| Log Analytics | ✅ | ✅ |
| Application Insights | ✅ | ✅ |
| Recovery Services Vault | ✅ | ✅ |
| Linux VM GitHub Actions runner | ✅ | ✅ |


The **Core** stack provisions a **Linux VM** intended to run as a **self-hosted GitHub Actions runner** for internal workloads, including **initial AKS setup and application deployment jobs**.

Before running any **Platform-App** workflows, you **must**:

1. Finish deploying the Core stack for your plane/product  
2. SSH into the VM  
3. Install and register the GitHub Actions runner  
4. Confirm that the runner is *online* and properly tagged (e.g., `self-hosted`, `nonprod` or `prod`)

[`See full instructions here`](stacks/core/README.md) 

This page documents VM access, required packages, runner registration commands, firewall considerations, tags, and operational guidance.

Platform-App workflows will **fail** if the VM runner is not fully configured.

---

## Observability Stack — Diagnostics & Alerts Coverage

The **observability** stack does **not** create the core/platform resources themselves; instead, it:

- Resolves existing IDs from the **network**, **core**, and **platform-app** remote state.
- Attaches **diagnostic settings** to those resources, sending logs/metrics to the shared **Log Analytics workspace**.
- Creates **action groups** when a shared one doesn’t already exist.
- Configures **activity log alerts** at both env and core subscription scopes.

> ✅ = diagnostics/alerts configured when the resource exists and the corresponding feature flag is enabled (or not gated).

### Diagnostics to Log Analytics

| Resource Type / Scope | hrz | pub | Notes |
|---|:--:|:--:|---|
| Network Security Groups (NSGs) | ✅ | ✅ | `azurerm_monitor_diagnostic_setting.nsg`; enables `NetworkSecurityGroupEvent` / `NetworkSecurityGroupRuleCounter` where available |
| Subscription Activity Logs (env subscription) | ✅ | ✅ | `sub_env` setting; categories: Administrative, Security, ServiceHealth, Alert, Recommendation, Policy, Autoscale, ResourceHealth |
| Key Vault | ✅ | ✅ | `kv`; only when `var.enable_kv_diagnostics = true`; enables `AuditEvent`, `AzurePolicyEvaluationDetails` if supported |
| Storage Accounts | ✅ | ✅ | `sa`; enables StorageRead/Write/Delete logs + all metrics categories supported |
| Service Bus Namespace | ✅ | ✅ | `sbns`; enables `OperationalLogs` when present |
| Event Hubs Namespace | ✅ | ✅ | `ehns`; enables `OperationalLogs` when present |
| PostgreSQL Flexible / CDBPG | ✅ | ✅ | `pg`; enables `PostgreSQLLogs`, `QueryStoreRuntimeStatistics`, `QueryStoreWaitStatistics` where supported |
| Redis Cache | ✅ | ✅ | `redis`; enables `ConnectedClientList`, `CacheRead/Write/Delete` where supported |
| Recovery Services Vault | ✅ | ✅ | `rsv`; enables `AzureBackupOperations`, `AzureSiteRecoveryJobs`, `AzureSiteRecoveryEvents`, `CoreAzureBackup`, plus optional addon categories |
| Application Insights | ✅ | ✅ | `appi`; enables AppRequests, AppDependencies, AppTraces, etc. (workspace-based) |
| VPN Gateway | ✅ | ✅ | `vpng`; enables `GatewayDiagnosticLog`, `TunnelDiagnosticLog`, `RouteDiagnosticLog` |
| Function Apps | ✅ | ✅ | `fa`; enables `FunctionAppLogs`, `AppServicePlatformLogs` |
| Web Apps (App Services) | ✅ | ✅ | `web`; enables HTTP, console, and application logs where supported |
| Application Gateway (WAF) | ✅ | ✅ | `appgw`; enables access, performance, and firewall logs |
| Azure Front Door / WAF | ✅ | ✅ | `afd`; enables `FrontdoorAccessLog`, `FrontdoorWebApplicationFirewallLog` |
| Cosmos DB (NoSQL) | ✅ | ✅ | `cosmos`; only when `var.enable_cosmos_diagnostics = true`; enables DataPlane/ControlPlane/Query/Partition logs |
| AKS Clusters | ✅ | ✅ | `aks`; only when `var.enable_aks_diagnostics = true` **and** env is one of `dev`, `uat`, `prod`; enables all available log + metric categories |

All diagnostics are sent to the **Log Analytics workspace** resolved as `local.law_id` (from core/platform outputs, or an explicit override).

### Alerts & Action Groups

| Feature | hrz | pub | Notes |
|---|:--:|:--:|---|
| Shared Action Group (core or fallback) | ✅ | ✅ | Uses existing core `action_group` if present; otherwise creates `azurerm_monitor_action_group.fallback` in core or env RGs |
| Env RG Change Alert | ✅ | ✅ | `rg_changes_env`; alerts on Administrative operations in the env app RG |
| Env Subscription Service Health Alert | ✅ | ✅ | `service_health_env`; ServiceHealth incidents in the env subscription |
| Core Subscription Service Health Alert | ✅ | ✅ | `service_health_core`; ServiceHealth incidents in the core subscription |
| Core RG Change Alert | ✅ | ✅ | `rg_changes_core`; Administrative operations in the core RG |

> The observability stack is **product-agnostic**: behavior is the same for `hrz` and `pub`; differences come from which resources actually exist in each environment and which feature flags (`enable_*_diagnostics`, etc.) are set.

---

## Shared-Network Overview

The shared-network stack establishes:

- Hub/Spoke VNets per plane + environment  
- VPN Gateway (optional)  
- Application Gateway (optional)  
- Azure Front Door (optional)  
- Private DNS zones + resolver  
- Per-subnet NSGs  
- Public DNS (optional)

Cloud awareness is handled by `var.product`.

---

## Secrets Hydration (Provision-Secrets Workflow)

The **infra-secrets-provision.yml** workflow automatically hydrates Azure Key Vault secrets using schemas under `stacks/provision-secrets/`.

### Key features:

- Auto-select cloud (hrz/pub)
- One KV hydrated per run
- Supports literal bundle secrets
- Uses schema to determine required values

---

## Deployment Order (Conceptual)

The typical end-to-end order is:

1. **Bootstrap Secrets**
   - Workflow: `infra-secrets-provision.yml`
   - Uses `stacks/provision-secrets/*.secrets.schema.json`

2. **Shared Network (Plane Level)**
   - Workflows: `network-plan.yml` / `network-apply.yml`
   - Stack: `stacks/shared-network/`
   - Inputs: `product` (`hrz` or `pub`), `plane` (`nonprod` or `prod`)

3. **Core (Plane Level)**
   - Workflows: `core-plan.yml` / `core-apply.yml`
   - Stack: `stacks/core/`
   - Inputs: `product` (`hrz` or `pub`), `plane` (`np` or `pr` → nonprod/prod)

4. **Platform Registry (Gov Only, Shared)**
   - Workflows: `registry-plan.yml` / `registry-apply.yml`
   - Stack: `stacks/platform-registry/`
   - Inputs: `subscription_id`, `tenant_id`, `location`, `registry_name`, `tags`

5. **Platform App (Environment Level)**
   - Workflows: `platform-plan.yml` / `platform-apply.yml`
   - Stack: `stacks/platform-app/`
   - Inputs: `product` (`hrz` or `pub`), `env` (`dev`, `qa`, `uat`, `prod`)

6. **Observability (Environment Level)**
   - Workflows: `observability-plan.yml` / `observability-apply.yml`
   - Stack: `stacks/observability/`
   - Inputs: `product` (`hrz` or `pub`), `env` (`dev`, `qa`, `uat`, `prod`)

> Governance workflow `govern-approval.yml` runs alongside this flow to enforce approvals for apply steps.

Details on workflows and their mapping to stacks are available in [`docs/workflows_documentation.md`](docs/workflows_documentation.md).

---

## Contributing

When adding new infrastructure:

1. **Decide where it lives:**
   - Reusable across stacks → create/update a module under `modules/`.
   - Specific to a plane/env → wire modules into the appropriate stack under `stacks/`.
   - Shared/global (like ACR) → consider a dedicated stack like `stacks/platform-registry/`.

2. **Update documentation:**
   - If you add a new stack, create a `README.md` following the existing pattern.
   - If you add/change workflows, update `docs/workflows_documentation.md`.

3. **Keep naming consistent:**
   - Use `hrz` / `pub` for product.
   - Prefer `nonprod` / `prod` for planes (vs `np` / `pr`) where possible.

---

## Getting Started (Very High Level)

1. Deploy the **Platform Registry** (Azure Gov only)
2. Run the **Shared Network** plan/apply for your target plane and product.
3. Run the **Core** plan/apply for the same plane/product.
4. For each environment (dev/qa/uat/prod) and product (hrz/pub), run **Platform App** and then **Observability**.
5. Ensure required secrets are configured (see `wiki-gh-secrets-hrz-pub.md` and the `provision-secrets` README).

For more details, start with:

- [`docs/folder_structure.md`](docs/folder_structure.md)
- [`docs/workflows_documentation.md`](docs/workflows_documentation.md)

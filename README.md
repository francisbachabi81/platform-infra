
# Unified Infrastructure Repository

This repo merges **Horizon (hrz)** and **Public (pub)** infrastructure into a single codebase.

- Shared code lives under `stacks/` (e.g., `shared-network/`, `platform-app/`, `provision-secrets/`).
- **`modules/`** — Reusable Terraform modules for all products.
- Behavior switches by `var.product` (`hrz` or `pub`) and `var.env` (`dev|qa|uat|prod`).
- Conditional creation is driven by these locals in `stacks/platform-app/main.tf`:
  ```hcl
  locals {
    enable_public_features = var.product == "pub"
    enable_hrz_features    = var.product == "hrz"
    enable_both            = local.enable_public_features || local.enable_hrz_features
  }
  ```

---

## What gets created by **platform-app** (by product)

> ✅ = created (subject to feature toggles/inputs). Empty = not created for that product.

| Resource / Module | Created for **hrz** | Created for **pub** | Notes |
|---|:--:|:--:|---|
| **Key Vault** (`module.kv1`) | ✅ | ✅ | Count = `local.enable_both ? 1 : 0` |
| **Storage Account** (`module.sa1`) | ✅ | ✅ | Depends on Key Vault |
| **Cosmos (NoSQL)** (`module.cosmos1`, db, containers) |  | ✅ | `local.cosmos_enabled = local.enable_public_features` |
| **AKS User-Assigned Identity (hub/env)** | ✅* | ✅* | Created when `local.create_aks` and env placement conditions are met |
| **AKS Cluster (hub for dev; env for uat/prod)** | ✅* | ✅* | Hub: dev only; Env: uat/prod only; requires PDNS zone and subnet |
| **AKS Diagnostics → Log Analytics** | ✅* | ✅* | When `local.manage_aks_diag` is true (`law_workspace_id` required) |
| **Service Bus** (`module.sbns1`) | ✅* | ✅* | When `var.create_servicebus` |
| **App Service Plan (Linux)** |  | ✅ | Public-only app hosting |
| **Function App #1 & #2** |  | ✅ | Uses SA for content, optional PEs/SCM PEs |
| **Event Hubs + CGs** |  | ✅* | When `local.create_eventhub` (dev/prod only) |
| **Cosmos DB for PostgreSQL (Citus)** |  | ✅* | When `var.create_cdbpg` |
| **PostgreSQL Flexible (primary)** |  | ✅ | Private networking only |
| **PostgreSQL Flexible (replica)** | ✅* | ✅* | When `var.pg_replica_enabled && !var.pg_ha_enabled` |
| **Redis Cache** | ✅ | ✅ | Private Endpoints if provided |

\* **Conditional** — subject to additional inputs such as `create_aks`, environment (`dev|uat|prod`), required subnets, PDNS zones, SKUs, etc.

---

## What gets created by the **core stack** (plane‑scoped)

Core provides shared observability / protection per plane (`nonprod` = dev+qa, `prod` = uat+prod). These resources are referenced by `platform-app` (e.g., AKS diagnostics, App Insights connection string).

> ✅ = created when the corresponding `create_*` toggle is `true`.

| Resource | Created for **hrz** | Created for **pub** | Notes |
|---|:--:|:--:|---|
| **Resource Group (core)** | ✅ | ✅ | `module.rg_core_platform` |
| **Log Analytics Workspace** | ✅ | ✅ | `azurerm_log_analytics_workspace` |
| **Application Insights (workspace-based)** | ✅ | ✅ | `azurerm_application_insights` |
| **Recovery Services Vault** | ✅ | ✅ | `azurerm_recovery_services_vault` |

---

## High-level overview of the **shared-network** stack

The shared-network stack establishes plane-wide connectivity and name resolution, then attaches per-environment spokes. It is intentionally high-level here—implementation lives in `stacks/shared-network/`.

**Scope (Hub & Spokes)**
- One **Hub VNet** per plane (`nonprod` / `prod`) and **Spoke VNets** for each environment (dev, qa, uat, prod).
- **Resource Groups** split by hub vs. env to match subscription layout.

**Connectivity**
- **VNet Peerings** hub↔spoke, with gateway transit when a VPN gateway is present.
- Optional **VPN Gateway** (and public IP if requested) for P2S/S2S scenarios.

**Ingress / Edge (optional)**
- **Application Gateway (WAF)** if an `appgw` subnet exists and `create_app_gateway` is true.
- Optional **Azure Front Door** profile/endpoint for global edge routing.

**Name Resolution**
- **Private DNS Zones** (centralized in hub) with links to all hub/spoke VNets.
- Optional **Private DNS Resolver** with inbound/outbound subnets and forwarding rules.

**Network Security**
- **Per‑subnet NSGs** (excluding special subnets like `GatewaySubnet`/`appgw`).  
- **Baseline rules**: deny Internet egress where appropriate, allow Azure DNS/NTP/Monitor, AKS egress allowances, and PE isolation rules for private endpoints.

**Public DNS (optional)**
- Public DNS zones created in the hub RG when specified.

> The shared-network layer is designed to be cloud‑aware (Commercial or Gov) via `var.product` and uses consistent tagging, naming, and dependency ordering so spokes, PEs, and higher-level services (AKS, Functions, databases) can plug in with minimal per‑env differences.

---

## Secrets Hydration (Provision-Secrets Workflow)

The **provision-secrets.yaml** workflow automates the process of populating Azure Key Vaults with required secrets per environment and product.

### Key Features
- One Key Vault hydrated per run (supports multiple vaults through `kv_sequence` if needed later).
- Automatically resolves the correct **Azure cloud** (Commercial or Government) based on the product.
- Identifies and applies the appropriate JSON schema from `/stacks/provision-secrets/`.

### Workflow Inputs
| Input | Description | Default |
|--------|--------------|----------|
| `env` | Target environment (`dev`, `qa`, `uat`, `prod`). | `dev` |
| `product` | Product (`hrz` = Gov, `pub` = Commercial). | `hrz` |
| `kv_sequence` | 2-digit Key Vault sequence (e.g., `01`, `02`). | `01` |
| `manifest_path` | Optional path to a JSON schema (e.g., `/stacks/provision-secrets/hrz-kvt02-secrets.schema.json`). | Auto-resolved |
| `literal_bundle_secret` | Name of the GitHub secret that stores key/value pairs for `literal_bundle_ref` secrets. | `SEED_JSON` |

### Schema File Example
```json
{
  "secrets": [
    { "name": "DOCKER--REGISTRY-HOST", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-HOST" } },
    { "name": "DOCKER--REGISTRY-PASSWORD", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-PASSWORD" } }
  ]
}
```

### Required GitHub Secrets
#### Baseline (common to all envs/lane)
These do **not** change per environment; they select the cloud at runtime based on `product`.
| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID_HRZ` | GitHub OIDC app registration (Gov) |
| `AZURE_CLIENT_ID_PUB` | GitHub OIDC app registration (Commercial) |
| `AZ_TENANT_HRZ` | Azure AD tenant (Gov) |
| `AZ_TENANT_PUB` | Azure AD tenant (Commercial) |

---

#### Per-Environment Secrets (dev, qa, uat, prod)
Used primarily by **shared-network** and **core** when targeting a specific app environment subscription.

> Define these in the corresponding GitHub **Environment** (`dev`, `qa`, `uat`, `prod`). Provide **both** Gov and Commercial IDs so workflows can choose via `var.product`.

| Environment | Horizon (Gov) | Public (Commercial) |
|---|---|---|
| `dev`  | `AZ_SUB_HRZ_DEV`  | `AZ_SUB_PUB_DEV`  |
| `qa`   | `AZ_SUB_HRZ_QA`   | `AZ_SUB_PUB_QA`   |
| `uat`  | `AZ_SUB_HRZ_UAT`  | `AZ_SUB_PUB_UAT`  |
| `prod` | `AZ_SUB_HRZ_PROD` | `AZ_SUB_PUB_PROD` |

---

#### Lane-Level Secrets
The **shared-network** and **core** stacks also deploy **plane/lane** resources that span multiple envs:
- **nonprod lane** → covers `dev` and `qa` (hub/shared resources)
- **prod lane** → covers `uat` and `prod` (hub/shared resources)

#### Nonprod Lane (shared-network, core)
| Secret | Purpose |
|---|---|
| `AZ_SUB_HRZ_NONPROD` | Hub/plane subscription for **hrz** nonprod (Gov) |
| `AZ_SUB_PUB_NONPROD` | Hub/plane subscription for **pub** nonprod (Commercial) |

#### Prod Lane (shared-network, core)
| Secret | Purpose |
|---|---|
| `AZ_SUB_HRZ_PROD` | Hub/plane subscription for **hrz** prod (Gov) |
| `AZ_SUB_PUB_PROD` | Hub/plane subscription for **pub** prod (Commercial) |

---

#### Example Mapping (who needs what)
- **shared-network (nonprod run)**: `AZURE_CLIENT_ID_*`, `AZ_TENANT_*`, `AZ_SUB_*_NONPROD` (lane level)
- **shared-network (prod run)**: `AZURE_CLIENT_ID_*`, `AZ_TENANT_*`, `AZ_SUB_*_PROD` (lane level)
- **core (nonprod run)**: `AZURE_CLIENT_ID_*`, `AZ_TENANT_*`, `AZ_SUB_*_NONPROD`
- **core (prod run)**: `AZURE_CLIENT_ID_*`, `AZ_TENANT_*`, `AZ_SUB_*_PROD`
- **env-targeted tasks (e.g., per-env overrides)**: add the per-env secret from section 2 (e.g., `AZ_SUB_PUB_QA`).

---

#### Quick Checklist
- [ ] Set **baseline** OIDC + tenant secrets as repo secrets.
- [ ] For each environment (`dev`, `qa`, `uat`, `prod`), add the **per-env** subscription IDs.
- [ ] For **lane** runs, add `AZ_SUB_*_NONPROD` and `AZ_SUB_*_PROD` to **`nonprod`** and **`prod-lane`** environments.

---

### Usage Example
To hydrate Horizon dev Key Vault:
1. Go to **Actions → provision-secrets**.
2. Select `product = hrz`, `env = dev`, and leave other fields as default.
3. Workflow hydrates `kvt-hrz-dev-usaz-01` using `/stacks/provision-secrets/hrz.secrets.schema.json`.

---

## Future-Proofing

The repository is structured for scalability:

- New products/clouds: extend locals and stack toggles, reuse existing modules.
- New Key Vaults per environment: add schema files following the current naming convention (e.g., `hrz-kvt02-secrets.schema.json`, `pub-kvt02-secrets.schema.json`).
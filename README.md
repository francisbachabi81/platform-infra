# Terraform Infra — Azure Gov & Azure Commercial

This repository contains Terraform configurations and GitHub Actions workflows for deploying shared network, core infrastructure, platform applications, and observability components across:

- **Azure Government** (`hrz`)
- **Azure Commercial** (`pub`)

The project is organized into reusable **modules**, environment/plane-specific **stacks**, and **workflows** that orchestrate plans and applies.

---

## Quick Navigation

### Documentation

- **Repo structure & stacks**: [`docs/folder_structure.md`](docs/folder_structure.md)
- **Workflows & execution order**: [`docs/workflows_documentation.md`](docs/workflows_documentation.md)
- **Secrets schema / GitHub secrets notes**: [`docs/wiki-gh-secrets-hrz-pub.md`](docs/wiki-gh-secrets-hrz-pub.md)

### Stacks

Each stack has its own `README.md` with purpose, inputs, dependencies, and related workflows:

- **Shared Network** – plane-level networking  
  → [`stacks/shared-network/README.md`](stacks/shared-network/README.md)

- **Core** – plane-level shared/core services  
  → [`stacks/core/README.md`](stacks/core/README.md)

- **Platform App** – env-level application infrastructure  
  → [`stacks/platform-app/README.md`](stacks/platform-app/README.md)

- **Observability** – env-level diagnostics and monitoring  
  → [`stacks/observability/README.md`](stacks/observability/README.md)

- **Provision-Secrets** – JSON schemas describing required secrets  
  → [`stacks/provision-secrets/README.md`](stacks/provision-secrets/README.md)

---

## High-Level Layout

```text
readme.md
wiki-gh-secrets-hrz-pub.md
modules/
stacks/
workflows/
docs/
```

- **`modules/`** – Reusable Terraform modules (vnet, nsg, app-service-plan, postgres-flex, keyvault, storage, etc.).
- **`stacks/`** – Top-level stacks that compose modules into deployable units per plane/environment.
- **`workflows/`** – GitHub Actions YAML files for plan/apply + secrets + approvals.
- **`docs/`** – Structural documentation for the repo and workflows.

See [`docs/folder_structure.md`](docs/folder_structure.md) for a detailed breakdown.

---

## Platform-App — What Gets Created per Product

> ✅ = created (subject to feature toggles/inputs). Empty = not created for that product.

| Resource / Module | hrz | pub | Notes |
|---|:--:|:--:|---|
| Key Vault | ✅ | ✅ |  |
| Storage Account | ✅ | ✅ |  |
| Cosmos (NoSQL) |  | ✅ |  |
| AKS UAI | ✅ | ✅ |  |
| AKS Cluster | ✅ | ✅ |  |
| AKS Diagnostics | ✅ | ✅ |  |
| Service Bus | ✅ | ✅ | When `var.create_servicebus` |
| App Service Plan |  | ✅ | Public only |
| Function Apps |  | ✅ |  |
| Event Hubs |  | ✅ | Dev/Prod only |
| Cosmos PostgreSQL |  | ✅ | When enabled |
| PostgreSQL Flex |  | ✅ |  |
| PostgreSQL Replica | ✅ | ✅ |  |
| Redis Cache | ✅ | ✅ |  |

---

## Core Stack — Plane-Level Shared Resources

| Resource | hrz | pub |
|---|:--:|:--:|
| Core RG | ✅ | ✅ |
| Log Analytics | ✅ | ✅ |
| Application Insights | ✅ | ✅ |
| Recovery Services Vault | ✅ | ✅ |

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

4. **Platform App (Environment Level)**
   - Workflows: `platform-plan.yml` / `platform-apply.yml`
   - Stack: `stacks/platform-app/`
   - Inputs: `product` (`hrz` or `pub`), `env` (`dev`, `qa`, `uat`, `prod`)

5. **Observability (Environment Level)**
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

2. **Update documentation:**
   - If you add a new stack, create a `README.md` following the existing pattern.
   - If you add/change workflows, update `docs/workflows_documentation.md`.

3. **Keep naming consistent:**
   - Use `hrz` / `pub` for product.
   - Prefer `nonprod` / `prod` for planes (vs `np` / `pr`) where possible.

---

## Getting Started (Very High Level)

1. Ensure required secrets are configured (see `wiki-gh-secrets-hrz-pub.md` and the `provision-secrets` README).
2. Run the **Shared Network** plan/apply for your target plane and product.
3. Run the **Core** plan/apply for the same plane/product.
4. For each environment (dev/qa/uat/prod) and product (hrz/pub), run **Platform App** and then **Observability**.

For more details, start with:

- [`docs/folder_structure.md`](docs/folder_structure.md)
- [`docs/workflows_documentation.md`](docs/workflows_documentation.md)

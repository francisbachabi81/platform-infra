# Repository Structure Overview

This document provides a reorganized and clearer description of how the Terraform repository is structured for deployments across **Azure Government (hrz)** and **Azure Commercial (pub)**, while retaining all relevant technical details.

---

# 1. Top‑Level Repository Layout

```
.
├── README.md
├── docs/
├── modules/
├── stacks/
└── .github/workflows/
```

A quick summary of each folder:

- **docs/** — All architectural documents, VPN guides, workflow explanations, and secrets schemas.  
- **modules/** — All reusable Terraform modules (network, storage, compute, security, observability, etc.).  
- **stacks/** — Deployable Terraform stacks for shared networking, core infra, platform applications, registry, observability, and secret provisioning.  
- **workflows/** — GitHub Actions automation for planning/applying infrastructure and governance.

---

# 2. Documentation (`docs/`)

```
docs/
  folder_structure.md
  subscription_architecture.md
  network_overview.md
  network-diagram.png
  nonprod-network-diagram.png
  workflows_documentation.md
  vpn_client_setup.md
  wiki-gh-secrets-hrz-pub.md
```

**Descriptions:**

- **folder_structure.md** – Repository structure overview (this document).  
- **subscription_architecture.md** – How subscriptions and planes (nonprod/prod) map across hrz and pub. 
- **network_overview.md** – High-level hub/spoke architecture, shared-network stack purpose, VPN gateway layout, subnet model, DNS design, and VNet integration strategy for both Azure Gov and Azure Commercial.
- **workflows_documentation.md** – Relationship between GitHub Actions workflows and Terraform stacks.  
- **vpn_client_setup.md** – Azure VPN Client instructions (Windows/macOS/Linux) across planes and clouds.  
- **wiki-gh-secrets-hrz-pub.md** – Full secrets schema and usage details for GitHub.

Use this folder for all reference documentation and architecture notes.

---

# 3. Reusable Modules (`modules/`)

Modules encapsulate resource-building logic that can be consumed by multiple stacks.

Each module follows:

```
modules/<name>/
  main.tf
  variables.tf
  outputs.tf
```

Examples:

```
modules/
  vnet/
  nsg/
  resource-group/
  keyvault/
  storage-account/
  postgres-flex/
  redis-cache/
  app-service-plan/
  communication/
  dns-resolver/
  servicebus/
  event-hub/
  rbac/
  recovery-vault/
  frontdoor-profile/
  function-app/
```

Modules should remain **cloud-agnostic** unless explicitly required.

---

# 4. Stacks (`stacks/`)

Stacks represent **deployable infrastructure units**.  
Each stack has its own:

```
main.tf
variables.tf
outputs.tf
backend.tf
tfvars/
README.md
```

---

## 4.1 Shared Network Stack

```
stacks/shared-network/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    nonprod.hrz.tfvars
    nonprod.pub.tfvars
    prod.hrz.tfvars
    prod.pub.tfvars
```

**Purpose:** Provides hub/spoke VNets, NSGs, DNS, VPN gateways, App Gateway, and optional Front Door.

**Scope:** Plane-level, for both clouds.

---

## 4.2 Core Stack

```
stacks/core/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    np.hrz.tfvars
    np.pub.tfvars
    pr.hrz.tfvars
    pr.pub.tfvars
```

**Purpose:** Log Analytics workspace, Application Insights, Recovery Services Vault, shared action groups, and other cross-environment foundational services.

**Dependency:** Requires Shared Network for the given plane/product.

---

## 4.3 Platform Application Stack

```
stacks/platform-app/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    dev.*
    qa.*
    uat.*
    prod.*
```

**Purpose:** Environment-level application infrastructure (AKS, Service Bus, KV, storage, Redis, Event Hub, Function Apps, App Service Plans, databases, etc.).

**Dependencies:**  
Shared Network → Core → Platform App → Observability

---

## 4.4 Platform Registry Stack

```
stacks/platform-registry/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    pr.hrz.tfvars
```

**Purpose:**  
Dedicated **Azure Container Registry (ACR)** living **only in Azure Government** and **only in production (pr)**.

Provides a global, shared registry used by all hrz workloads.

---

## 4.5 Observability Stack

```
stacks/observability/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    dev.*
    qa.*
    uat.*
    prod.*
```

**Purpose:**  
Diagnostic settings, activity log routing, metric alerts, and action groups.

**Sequence:**  
Applied after Platform App for the same environment.

---

## 4.6 Provision-Secrets Stack

```
stacks/provision-secrets/
  schemas/*.secrets.schema.json
```

**Purpose:**  
Defines required secrets for hrz and pub.  
Used by the **infra-secrets-provision** workflow to hydrate Key Vaults and GitHub secrets.  
(Not a Terraform deployment stack.)

---

# 5. GitHub Workflows (`.github/workflows/`)

```
workflows/
  network-plan.yml
  network-apply.yml
  core-plan.yml
  core-apply.yml
  platform-plan.yml
  platform-apply.yml
  registry-plan.yml
  registry-apply.yml
  observability-plan.yml
  observability-apply.yml
  infra-secrets-provision.yml
  govern-approval.yml
```

Functions:

- Perform `terraform plan` & `apply` using OIDC  
- Manage state subscription vs target subscription  
- Upload & reuse tfplan artifacts  
- Enforce `/approve` gating via the governance workflow  
- Hydrate secrets into Key Vaults

Registry workflows are significantly simpler since they target a single cloud + single plane.

---

# 6. Recommendations & Best Practices

### Normalize naming
Prefer full names (`nonprod`, `prod`) instead of abbreviations (`np`, `pr`) for consistency.

### Maintain per-stack README files
Each should document:
- Purpose & scope  
- Dependencies  
- Required tfvars  
- Workflow usage  

### Keep modules generic & reusable
Stacks should orchestrate logic; modules should implement individual resource patterns.

### Maintain documentation in `docs/`
Centralize everything here and link from the root README.

---

# Summary

This repository is structured around:

- **Reusable modules**  
- **Deployable stacks per plane/environment**  
- **Workflows for secure, approved deployments**  
- **Documentation for all architecture and operational concerns**
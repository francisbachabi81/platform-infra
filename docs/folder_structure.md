# Repository Folder Structure

This document provides a high-level overview of the Terraform repository structure, focusing on how stacks, modules, and workflows are organized for Azure Government (`hrz`) and Azure Commercial (`pub`) deployments.

---

## 1. Root Layout

```text
readme.md
folder_structure.md              # (legacy, can be replaced by docs/folder_structure.md)
workflows_documentation.md       # (legacy, can be replaced by docs/workflows_documentation.md)
wiki-gh-secrets-hrz-pub.md
modules/
stacks/
workflows/
```

**Highlights**

- **`modules/`** — Reusable Terraform modules for common building blocks.
- **`stacks/`** — Top-level Terraform stacks (Shared Network, Core, Platform App, Observability, Provision-Secrets).
- **`workflows/`** — GitHub Actions workflows (plan/apply + secrets + approvals).
- **`wiki-gh-secrets-hrz-pub.md`** — Documentation describing secrets per environment/product.

> Recommendation: keep all new architecture docs under `docs/` and link them from `readme.md`.

---

## 2. Stacks

All stacks live under `stacks/` and generally follow:

```text
stacks/<stack-name>/
  backend.tf
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    <env/product>.tfvars
```

### 2.1 Shared Network Stack

```text
stacks/shared-network/
  backend.tf
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    nonprod.hrz.tfvars
    nonprod.pub.tfvars
    prod.hrz.tfvars
    prod.pub.tfvars
```

**Purpose (structural)**  
Defines **plane-level shared networking** (hub / shared network) per:

- **Plane**: `nonprod`, `prod`
- **Product**: `hrz` (Azure Gov), `pub` (Azure Commercial)

**Notes**

- This stack should be applied **before** `core`, `platform-app`, and `observability` for each plane.

---

### 2.2 Core Stack

```text
stacks/core/
  backend.tf
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    np.hrz.tfvars
    np.pub.tfvars
    pr.hrz.tfvars
    pr.pub.tfvars
```

**Purpose (structural)**  
Defines **plane-level shared/core infrastructure** (e.g., common services used by multiple environments).

**Inputs via tfvars**

- Plane is represented as:
  - `np` → nonprod
  - `pr` → prod
- Product:
  - `hrz`
  - `pub`

> Recommendation: consider renaming `np`/`pr` to `nonprod`/`prod` for consistency with `shared-network`.

**Dependency**

- Requires `shared-network` to be deployed for the same plane and product.

---

### 2.3 Platform Application Stack

```text
stacks/platform-app/
  backend.tf
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    dev.hrz.tfvars
    dev.pub.tfvars
    qa.hrz.tfvars
    qa.pub.tfvars
    uat.hrz.tfvars
    uat.pub.tfvars
    prod.hrz.tfvars
    prod.pub.tfvars
```

**Purpose (structural)**  
Defines **environment-specific application infrastructure**, deployed per environment and product.

**Inputs via tfvars**

- Env: `dev`, `qa`, `uat`, `prod`
- Product: `hrz`, `pub`

**Dependency**

- Depends on:
  - `shared-network` (plane networking)
  - `core` (plane shared/core services)

---

### 2.4 Observability Stack

```text
stacks/observability/
  README.md
  backend.tf
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    dev.hrz.tfvars
    dev.pub.tfvars
    qa.hrz.tfvars
    qa.pub.tfvars
    uat.hrz.tfvars
    uat.pub.tfvars
    prod.hrz.tfvars
    prod.pub.tfvars
```

**Purpose (structural)**  
Defines **environment-specific observability and diagnostics** (e.g., diagnostic settings, log routing) per environment and product.

**Inputs via tfvars**

- Env: `dev`, `qa`, `uat`, `prod`
- Product: `hrz`, `pub`

**Dependency**

- Typically applied **after** `platform-app` for the same environment, once core resources exist to attach diagnostics to.

---

### 2.5 Provision-Secrets Stack

```text
stacks/provision-secrets/
  hrz.secrets.schema.json
  pub.secrets.schema.json
```

**Purpose (structural)**  

- Stores **JSON schema definitions** describing required secrets for:
  - `hrz` (Azure Gov)
  - `pub` (Azure Commercial)
- This stack is **not** a Terraform configuration; it is used by the secrets provisioning workflow to hydrate Key Vaults and/or GitHub secrets.

---

## 3. Modules Library

```text
modules/
  acr/
  aks/
  app-gateway/
  app-service-plan/
  communication/
  cosmos-account/
  cosmosdb-postgresql/
  dns-resolver/
  event-hub/
  event-hub-consumer-groups/
  frontdoor-profile/
  function-app/
  keyvault/
  network/
    nsg/
    peering/
  postgres-flex/
  private-dns/
  rbac/
  recovery-vault/
  redis/
  resource-group/
  servicebus/
  storage-account/
  vnet/
  vpn-gateway/
  waf-policy/
  .DS_Store        # local artifact, can be ignored
```

Each module typically follows:

```text
modules/<name>/
  main.tf
  variables.tf
  outputs.tf
```

**Notes**

- `modules/network/` groups network-related submodules (`nsg`, `peering`).
- Modules are consumed from stack `main.tf` files to encapsulate resource-level logic.

---

## 4. Workflows

All workflow files used for infrastructure are stored in:

```text
workflows/
  core-apply.yml
  core-plan.yml
  govern-approval.yml
  infra-secrets-provision.yml
  network-apply.yml
  network-plan.yml
  observability-apply.yml
  observability-plan.yml
  platform-apply.yml
  platform-plan.yml
```

These are documented in detail in [`docs/workflows_documentation.md`](./workflows_documentation.md).

---

## 5. Recommended Improvements (Structure Only)

- **Normalize plane naming**  
  Align `core` tfvars naming (`np`/`pr`) with `shared-network` (`nonprod`/`prod`) to reduce cognitive overhead.

- **Per-stack README files**  
  Each stack folder should contain a concise `README.md` explaining:
  - Purpose
  - Inputs and tfvars mapping
  - Dependencies
  - Related workflows

- **Docs folder**  
  Store structural docs under `docs/`:
  - `docs/folder_structure.md`
  - `docs/workflows_documentation.md`
  - Link them from the root `readme.md`.

- **Ignore local artifacts**  
  Ensure `.DS_Store` and `__MACOSX/` are in `.gitignore` or removed from source.

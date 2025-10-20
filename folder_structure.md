# Repository Folder Structure

This document outlines the standardized Terraform repository structure that supports both **Azure Government (hrz)** and **Azure Commercial (pub)** deployments.  
It provides a unified approach for managing environments, stacks, modules, and secrets across all products.

---

## Root Layout

```
README.md
.github/
  workflows/
    platform-app.yaml
    shared-network.yaml
    plane-core.yaml
    provision-secrets.yaml
modules/
stacks/
```

---

## Modules

Reusable Terraform modules for shared components used across all stacks.  
Each module follows a consistent structure (`main.tf`, `variables.tf`, `outputs.tf`).

```
modules/
  acr/
  aks/
  app-gateway/
  app-service-plan/
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
```

Each subdirectory represents a standalone Terraform module that can be reused across different environments or products.

---

## Stacks

Primary Terraform stacks that organize major resource groups by function.

### Platform-App Stack
```
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

#### Key Points
- Hosts application infrastructure (AKS, Key Vault, Storage, Service Bus, Front Door, etc.).
- Uses product-specific tfvars for environment separation and backend configuration.

---

### Shared-Network Stack
```
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

#### Key Points
- Contains shared resources like VNets, Subnets, NSGs, Route Tables, VPN Gateway, and App Gateway.
- Supports both **nonprod** and **prod** planes for simplified management.
- Secrets schema files define the default hydration sets for each product Key Vault.

---

### Core Stack
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

#### Key Points
- Provides shared observability and protection per plane.
- Deploys **Log Analytics Workspace**, **Application Insights**, and **Recovery Services Vault**.
- Acts as a dependency layer for diagnostics integration (used by AKS, App Service, Function Apps, etc.).
- Managed per-lane (nonprod or prod) to serve all underlying environments (dev/qa and uat/prod).

---

## Secrets Schema (Provision-Secrets)

The `hrz.secrets.schema.json` and `pub.secrets.schema.json` files are used by the **provision-secrets.yaml** workflow to hydrate Key Vaults.  
They define which secrets should be populated and where their values are sourced from.

Example:
```json
{
  "secrets": [
    { "name": "DOCKER--REGISTRY-HOST", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-HOST" } },
    { "name": "DOCKER--REGISTRY-PASSWORD", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-PASSWORD" } }
  ]
}
```

Key Vault naming follows this convention:
```
kvt-<product>-<env>-<region>-<sequence>
# Example:
kvt-hrz-dev-usaz-01
kvt-pub-prod-cus-01
```

---

## GitHub Workflows

### env-deploy.yaml
Deploys Terraform for a given environment (`env`) and product (`hrz` or `pub`).  
Selects correct Azure environment, tenant, and subscription dynamically.

### shared-network.yaml
Provisions shared infrastructure components across multiple environments (`nonprod` or `prod`).

### core.yaml
Deploys shared monitoring and recovery resources (Log Analytics, App Insights, Recovery Vault) for each lane (`nonprod`, `prod`).

### provision-secrets.yaml
Hydrates Azure Key Vaults using JSON schema files in `/stacks/provision-secrets/`.
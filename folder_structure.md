# Repository Folder Structure

This document outlines the standardized Terraform repository structure that supports both **Azure Government (hrz)** and **Azure Commercial (pub)** deployments.  
It provides a unified approach for managing environments, stacks, modules, and secrets across all products.

---

## Root Layout

```
README.md
.github/
  workflows/
    env-deploy.yaml
    shared-network.yaml
    provision-secrets.yaml
envvars/
  dev.hrz.tfvars
  dev.pub.tfvars
  qa.hrz.tfvars
  qa.pub.tfvars
  uat.hrz.tfvars
  uat.pub.tfvars
  prod.hrz.tfvars
  prod.pub.tfvars
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

## Environment Variables (envvars/)

Contains environment-specific `.tfvars` files for both **Horizon (hrz)** and **Public (pub)** deployments.

```
envvars/
  dev.hrz.tfvars
  dev.pub.tfvars
  qa.hrz.tfvars
  qa.pub.tfvars
  uat.hrz.tfvars
  uat.pub.tfvars
  prod.hrz.tfvars
  prod.pub.tfvars
```

### Purpose
- Centralizes key environment-level variables (region, subscription, naming prefix, etc.).
- Used by GitHub Actions workflows to dynamically configure the Terraform backend and providers.

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
  frontdoor_module.tf
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
- The Front Door stack is merged into this layer for simplicity.
- Uses product-specific tfvars for environment separation and backend configuration.


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
  hrz.secrets.schema.json
  pub.secrets.schema.json
```

#### Key Points
- Contains shared resources like VNets, Subnets, NSGs, Route Tables, VPN Gateway, and App Gateway.
- Supports both **nonprod** and **prod** planes for simplified management.
- Secrets schema files define the default hydration sets for each product Key Vault.

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

### provision-secrets.yaml
Hydrates Azure Key Vaults using JSON schema files in `/stacks/shared-network/`.

---

## Summary

This structure ensures:
- **Modularity**: Modules are reusable and environment-agnostic.
- **Scalability**: Easy to extend for future products or additional clouds.
- **Governance**: Clear separation of environments, stacks, and configurations.
- **Automation-ready**: Fully compatible with the unified GitHub Actions workflows.

---

### Example Workflow Invocation

To deploy the dev Horizon stack:
```bash
gh workflow run env-deploy.yaml -f env=dev -f product=hrz -f apply=true
```

To hydrate secrets for Public QA:
```bash
gh workflow run provision-secrets.yaml -f product=pub -f env=qa
```


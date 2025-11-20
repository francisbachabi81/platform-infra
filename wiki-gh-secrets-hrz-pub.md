# GitHub Secrets – HRZ & PUB

This page documents the GitHub **Repository** and **Environment** secrets used for deploying the **HRZ** and **PUB** products to Azure via GitHub Actions.

- **Repository secrets** – available to all workflows in the repo.
- **Environment secrets** – scoped to a specific GitHub Environment (e.g., `dev`, `qa`, `uat`, `prod`).

> ℹ️ This document uses **dev** as the example environment. The same pattern can be replicated for `qa`, `uat`, and `prod`.

---

## 1. Repository Secrets

Repository secrets are defined under **Settings → Secrets and variables → Actions → Repository secrets**.

### 1.1 Shared / Global Repository Secrets

These are not specific to a single product.

| Secret name          | Scope   | Description                                         |
|----------------------|--------|-----------------------------------------------------|
| `GH_PAT_WORKFLOW`    | Global | GitHub Personal Access Token for workflow automations (e.g., updating tags, calling APIs). |

---

### 1.2 HRZ – Repository Secrets

These secrets are used when deploying the **HRZ** product.

| Secret name           | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `AZURE_CLIENT_ID_HRZ` | Azure AD (Entra ID) application / service principal **Client ID** for HRZ. |
| `AZ_TENANT_HRZ`       | Azure AD (Entra ID) **Tenant ID** for HRZ.                                 |
| `AZ_SUB_HRZ_DEV`      | Subscription ID for the **HRZ dev** subscription.                          |
| `AZ_SUB_HRZ_NONPROD`  | Subscription ID for the **HRZ nonprod** (shared nonprod) subscription.     |
| `AZ_SUB_HRZ_QA`       | Subscription ID for the **HRZ QA** subscription.                           |
| `AZ_SUB_HRZ_PROD`     | Subscription ID for the **HRZ prod** subscription.                         |
| `AZ_SUB_STATE_HRZ`    | Subscription ID that hosts the **HRZ Terraform remote state** resources.   |

> If HRZ does not have dedicated `DEV` / `QA` subscriptions, you can omit `AZ_SUB_HRZ_DEV` and/or `AZ_SUB_HRZ_QA` and adjust workflows accordingly.

---

### 1.3 PUB – Repository Secrets

These secrets are used when deploying the **PUB** product.

| Secret name            | Description                                                                 |
|------------------------|-----------------------------------------------------------------------------|
| `AZURE_CLIENT_ID_PUB`  | Azure AD (Entra ID) application / service principal **Client ID** for PUB. |
| `AZ_TENANT_PUB`        | Azure AD (Entra ID) **Tenant ID** for PUB.                                 |
| `AZ_SUB_PUB_DEV`       | Subscription ID for the **PUB dev** subscription.                          |
| `AZ_SUB_PUB_NONPROD`   | Subscription ID for the **PUB nonprod** subscription.                      |
| `AZ_SUB_PUB_QA`        | Subscription ID for the **PUB QA** subscription.                           |
| `AZ_SUB_STATE_PUB`     | Subscription ID that hosts the **PUB Terraform remote state** resources.   |

---

## 2. Environment Secrets (Dev Example)

Environment secrets are defined under **Settings → Environments → `<environment>` → Environment secrets**.

Below uses the **`dev`** environment as an example. You can repeat the same pattern for `qa`, `uat`, and `prod`.

### 2.1 HRZ – Environment Secrets (dev)

| Secret name                     | Description                                                                      |
|---------------------------------|----------------------------------------------------------------------------------|
| `AZ_SUB_HRZ_CORE`               | Subscription ID for the **HRZ core** resources in the **dev** environment.      |
| `HUB_SUB_ID_HRZ`                | Hub subscription ID for **HRZ** (networking / hub resources).                   |
| `HUB_TENANT_ID_HRZ`             | Tenant ID for the **HRZ hub** subscription.                                     |
| `CDBPG_ADMIN_PASSWORD_HRZ`      | Admin password for HRZ Cosmos DB/Postgres (or equivalent) in **dev**.           |
| `PG_ADMIN_PASSWORD_HRZ`         | Postgres admin password for HRZ in **dev**.                                     |

> Password secrets can be unique per product and per environment for easier rotation and separation of duties.

---

### 2.2 PUB – Environment Secrets (dev)

| Secret name                     | Description                                                                      |
|---------------------------------|----------------------------------------------------------------------------------|
| `AZ_SUB_PUB_CORE`               | Subscription ID for the **PUB core** resources in the **dev** environment.      |
| `HUB_SUB_ID_PUB`                | Hub subscription ID for **PUB** (networking / hub resources).                   |
| `HUB_TENANT_ID_PUB`             | Tenant ID for the **PUB hub** subscription.                                     |
| `CDBPG_ADMIN_PASSWORD_PUB`      | Admin password for PUB Cosmos DB/Postgres (or equivalent) in **dev**.           |
| `PG_ADMIN_PASSWORD_PUB`         | Postgres admin password for PUB in **dev**.                                     |

---

## 3. Usage Pattern in GitHub Actions

Below is an example of how workflows can select the right secrets based on `inputs.product` (e.g., `hrz` or `pub`) when running a job.

```yaml
name: "Plan | Example"

on:
  workflow_dispatch:
    inputs:
      product:
        description: "Product"
        type: choice
        options: [hrz, pub]
        default: hrz
      env:
        description: "Environment"
        type: choice
        options: [dev, qa, uat, prod]
        default: dev

jobs:
  plan:
    runs-on: ubuntu-latest
    env:
      PRODUCT: ${{ inputs.product }}
      ENVIRONMENT: ${{ inputs.env }}

      # Map product → client/tenant IDs
      AZURE_CLIENT_ID: ${{ inputs.product == 'hrz' && secrets.AZURE_CLIENT_ID_HRZ || secrets.AZURE_CLIENT_ID_PUB }}
      AZURE_TENANT_ID: ${{ inputs.product == 'hrz' && secrets.AZ_TENANT_HRZ || secrets.AZ_TENANT_PUB }}

      # Example: per-product core subscription (dev env)
      AZURE_SUBSCRIPTION_ID: ${{ inputs.product == 'hrz' && secrets.AZ_SUB_HRZ_CORE || secrets.AZ_SUB_PUB_CORE }}

      # Optional: per-product Postgres passwords
      PG_ADMIN_PASSWORD: ${{ inputs.product == 'hrz' && secrets.PG_ADMIN_PASSWORD_HRZ || secrets.PG_ADMIN_PASSWORD_PUB }}
```

Adjust the secret names above if you choose the **shared password** pattern instead of per-product credentials.

---

## 4. Checklist

When onboarding a new environment or product, confirm the following:

1. **Repository secrets**
   - [ ] `AZURE_CLIENT_ID_<PRODUCT>` created
   - [ ] `AZ_TENANT_<PRODUCT>` created
   - [ ] `AZ_SUB_<PRODUCT>_DEV` / `NONPROD` / `QA` / `PROD` created as needed
   - [ ] `AZ_SUB_STATE_<PRODUCT>` created

2. **Environment secrets** (per environment: `dev`, `qa`, `uat`, `prod`)
   - [ ] `<PRODUCT>` core subscription ID (`AZ_SUB_<PRODUCT>_CORE`)
   - [ ] Hub subscription/tenant IDs (`HUB_SUB_ID_<PRODUCT>`, `HUB_TENANT_ID_<PRODUCT>`)
   - [ ] DB/admin passwords: either shared (`PG_ADMIN_PASSWORD`, `CDBPG_ADMIN_PASSWORD`) **or** per product (`*_HRZ`, `*_PUB`).

Once the secrets are in place, workflows can safely use the same YAML across products and environments, with behavior driven entirely by `inputs.product` and `inputs.env`.

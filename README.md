# Unified Infrastructure Repository

This repo merges Horizon (hrz) and Public infrastructure into a single codebase.
- Shared code lives under `stacks/` (e.g., `shared-network/`, `platform-app/`, `provision-secrets/`).
- **`modules/`** — Reusable Terraform modules for all products.
- Behavior switches by `var.product` (`hrz` or `public`) and `var.env` (`dev|qa|uat|prod`).
- **Conditional resource creation logic lives directly in** `stacks/platform-app/main.tf` **via** `locals { ... }`:
  ```hcl
  locals {
    enable_public_features = var.product == "pub"
    enable_hrz_features    = var.product == "hrz"
    enable_both            = local.enable_public_features || local.enable_hrz_features
  }

## Product-specific resources
- Public-only (enabled when `var.product == "public"`): Event Hub, Azure Functions (see `stacks/envs/main.public-features.example.tf`).
- Horizon-only: wire up using `local.enable_hrz_features` in your modules.

## TFVars
Store opinionated tfvars in `tfvars/<env>.<product>.tfvars` if desired.


This allows each environment to use distinct naming, subscription IDs, and configurations while maintaining shared Terraform logic.

## Secrets Hydration (Provision-Secrets Workflow)

The **provision-secrets.yaml** workflow automates the process of populating Azure Key Vaults with required secrets per environment and product.

### Key Features
- One Key Vault hydrated per run (supports multiple vaults through `kv_sequence` if needed in the future).
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
| Secret | Description |
|---------|-------------|
| `AZURE_CLIENT_ID_HRZ`, `AZURE_CLIENT_ID_PUB` | Client IDs for Azure OIDC authentication. |
| `AZ_TENANT_HRZ`, `AZ_TENANT_PUB` | Tenant IDs for Azure Gov and Commercial. |
| `AZ_SUB_HRZ_DEV`, `AZ_SUB_HRZ_QA`, `AZ_SUB_HRZ_UAT`, `AZ_SUB_HRZ_NONPROD`, `AZ_SUB_HRZ_PROD` | Subscription IDs for Azure Gov. |
| `AZ_SUB_PUB_DEV`, `AZ_SUB_PUB_QA`, `AZ_SUB_PUB_UAT`, `AZ_SUB_PUB_NONPROD`, `AZ_SUB_PUB_PROD` | Subscription IDs for Azure Commercial. |
| `SEED_JSON` | JSON bundle of literal secrets used in `literal_bundle_ref` entries. |

### Usage Example
To hydrate Horizon dev Key Vault:
1. Go to **Actions → provision-secrets**.
2. Select `product = hrz`, `env = dev`, and leave other fields as default.
3. Workflow hydrates `kvt-hrz-dev-usaz-01` using `/stacks/provision-secrets/hrz.secrets.schema.json`.

## Future-Proofing

The repository is structured for scalability:
- Adding a new cloud or product only requires updating `stacks/platform-app/main.tf` **via** `locals { ... }` and workflows.
- Adding new Key Vaults per environment just needs new schema files following the naming convention:
  - `hrz-kvt02-secrets.schema.json`
  - `pub-kvt02-secrets.schema.json`
  
# GitHub Actions Workflows — Infrastructure & Secrets Management

This documentation covers the three primary GitHub Actions workflows used in the repository:
- **Platform App Deployment Workflow**
- **Shared Network Deployment Workflow**
- **Secrets Hydration Workflow (provision-secrets.yaml)**

---

## 1. Platform App Deployment Workflow

### Overview
This workflow deploys the **platform application stack** to Azure using Terraform. It supports multiple environments (`dev`, `qa`, `uat`, `prod`) and products (`hrz` for Azure Government, `pub` for Azure Commercial).

### Workflow Summary
- Selects the correct Azure environment, tenant, and subscription based on the provided inputs.
- Initializes Terraform with a backend in the appropriate storage account.
- Executes validation, plan, and apply (or destroy) operations.
- Uploads plan and apply logs as workflow artifacts.

### Required Secrets
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
Used primarily by **shared-network** when targeting a specific app environment subscription.

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
| `HUB_SUB_ID_HRZ` | Hub/plane subscription if your hub lives in a different tenant/sub than the plane’s default |
| `HUB_TENANT_ID_HRZ` | Hub/plane tenant if your hub lives in a different tenant/sub than the plane’s default |
| `AZ_SUB_PUB_NONPROD` | Hub/plane subscription for **pub** nonprod (Commercial) |
| `HUB_SUB_ID_PUB` | Hub/plane subscription if your hub lives in a different tenant/sub than the plane’s default |
| `HUB_TENANT_ID_PUB` | Hub/plane tenant if your hub lives in a different tenant/sub than the plane’s default |

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

### How to Run
1. Navigate to **Actions → platform-app** in GitHub.
2. Select the environment and product.
3. Optionally toggle `apply` or `destroy`.
4. Click **Run Workflow**.

---

## 2. Shared Network Deployment Workflow

### Overview
Deploys the **shared networking layer** (VNets, subnets, NSGs, routes, gateways, private DNS zones) used across all environments.

### Workflow Summary
- Runs Terraform to provision networking components.
- Stores state in `shared-network/<plane>/terraform.tfstate`.
- Uses the same OIDC identity and tenant logic as the Platform workflow.

### Required Secrets
Same as the Platform App workflow.

### How to Run
1. Go to **Actions → shared-network-deploy**.
2. Choose `plane` (nonprod or prod) and `product` (`hrz` or `pub`).
3. Set `apply=true` if you want to apply changes.
4. Click **Run Workflow**.

---

## 3. Secrets Hydration Workflow (provision-secrets.yaml)

### Overview
This workflow hydrates an Azure **Key Vault** with secrets defined in JSON schema files stored under `/stacks/provision-secrets/`. It supports one vault per run but can easily accommodate new vaults in the future by adjusting the **sequence** or **manifest path**.

### Key Concepts

#### File Naming Convention
Default schema files:
```
/stacks/provision-secrets/hrz.secrets.schema.json
/stacks/provision-secrets/pub.secrets.schema.json
```

For additional Key Vaults (future expansion):
```
hrz-kvt02-secrets.schema.json
pub-kvt02-secrets.schema.json
```

#### Key Vault Naming Convention
```
kvt-<product>-<env>-<region>-<sequence>
```
Examples:
- `kvt-hrz-dev-usaz-01`
- `kvt-hrz-dev-usaz-02`
- `kvt-pub-qa-cus-01`

### How It Works
1. Selects the Azure cloud (Commercial or Government) based on the `product` input.
2. Determines the target region (`usaz` for Gov, `cus` for Commercial by default).
3. Identifies which JSON schema file to use based on `kv_sequence` or `manifest_path`.
4. Opens the target Key Vault (enables PNA and allows firewall temporarily).
5. Seeds secrets defined in the schema.
6. Closes the Key Vault (disables PNA and sets firewall to Deny).

### Inputs
| Input | Description | Default |
|--------|--------------|----------|
| `env` | Target environment (`dev`, `qa`, `uat`, `prod`). | `dev` |
| `product` | Product (`hrz` = Azure Gov, `pub` = Azure Commercial). | `hrz` |
| `region_short` | Region short code. Auto defaults based on product. | `usaz` or `cus` |
| `kv_sequence` | Two-digit sequence number for the Key Vault. | `01` |
| `manifest_path` | Optional path to a specific JSON schema file. | auto-resolved |
| `literal_bundle_secret` | GitHub secret name containing a JSON bundle of literal values. | `SEED_JSON` |

### Required Secrets
| Secret | Description |
|---------|-------------|
| `AZURE_CLIENT_ID_HRZ` / `AZURE_CLIENT_ID_PUB` | OIDC client IDs for Azure Gov and Commercial. |
| `AZ_TENANT_HRZ` / `AZ_TENANT_PUB` | Tenant IDs for Gov and Commercial. |
| `AZ_SUB_HRZ_DEV|QA|UAT|PROD` | Subscription IDs for Azure Gov. |
| `AZ_SUB_PUB_DEV|QA|UAT|PROD` | Subscription IDs for Azure Commercial. |
| `SEED_JSON` | JSON bundle of literal values for use in `literal_bundle_ref` secrets. |

### Example Schema File
```json
{
  "secrets": [
    { "name": "DOCKER--REGISTRY-HOST", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-HOST" } },
    { "name": "DOCKER--REGISTRY-PASSWORD", "source": { "type": "literal_bundle_ref", "key": "DOCKER--REGISTRY-PASSWORD" } }
  ]
}
```

### How to Run
1. Go to **Actions → provision-secrets**.
2. Choose:
   - `product` (`hrz` or `pub`)
   - `env` (`dev`, `qa`, `uat`, `prod`)
   - `kv_sequence` (e.g., `01`, `02`)
3. Optionally specify a custom schema via `manifest_path`.
4. Run the workflow.

### Output & Behavior
- The workflow hydrates secrets into `kvt-<product>-<env>-<region>-<sequence>`.
- Automatically handles region suffixes (`core.usgovcloudapi.net` vs. `core.windows.net`).
- Displays a summary of processed secrets.
- Ensures the Key Vault is closed (PNA Disabled, Firewall Deny) after completion.

### Expected Outcomes
- All secrets defined in the manifest appear in the corresponding Key Vault.
- The vault remains secured after hydration.
- Errors are surfaced clearly if any secret source or schema path is invalid.

---

## OIDC Setup for GitHub Workflows

### Steps
1. Create an Azure App Registration for each tenant (Gov and Commercial).
2. Add **Federated Credentials** with:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Subject: `repo:<org>/<repo>:ref:refs/heads/*`
   - Audience: `api://AzureADTokenExchange`
3. Assign **Contributor** role (or least privilege) to the Service Principal on the target subscription.
4. Store `AZURE_CLIENT_ID_*`, `AZ_TENANT_*`, and `AZ_SUB_*` in GitHub Secrets.

### Verification
Run any of the workflows and confirm successful authentication in the log output.

---

## Summary
This workflow suite ensures consistent, secure, and automated management of:
- Infrastructure (via Terraform)
- Networking (via shared-network)
- Secrets (via provision-secrets)

It supports both **Azure Commercial** and **Azure Government**, and can easily expand to handle future Key Vaults or schema files without structural changes to the workflows.

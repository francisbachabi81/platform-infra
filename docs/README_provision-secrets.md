# Provision Secrets

This folder documents the **Key Vault–to–Key Vault secret sync workflow** used to bootstrap and maintain application secrets across environments.

There is **no schema** and **no Terraform** in this folder. Secrets are managed by updating a **source “core” Key Vault** and then running a **GitHub Actions workflow** that copies the right secrets into the **destination environment Key Vault**.

---

## How it works

### 1) Source Key Vault (Core / Hub subscription)

Developers **create or update secrets in the core Key Vault** for the correct product and plane:

| Environment | Source plane | HRZ (Azure Gov) source KV | PUB (Azure Commercial) source KV |
|---|---|---|---|
| `dev`, `qa` | `np` | `kvt-hrz-np-usaz-core-01` | `kvt-pub-np-cus-core-01` |
| `uat`, `prod` | `pr` | `kvt-hrz-pr-usaz-core-01` | `kvt-pub-pr-cus-core-01` |

> The source Key Vault is in the **core/hub subscription** (separate from the environment subscription).

### 2) Secret naming rule (required)

**All secrets in the source KV must be prefixed by environment:**

- `DEV--<secret-name>`
- `QA--<secret-name>`
- `UAT--<secret-name>`
- `PROD--<secret-name>`

Example:

- `DEV--AGENCY-UI--VITE-OAUTH-CLIENT-ID`
- `QA--POSTGRES--APP-PASSWORD`

### 3) Destination Key Vault (Environment subscription)

When you run the workflow, it writes secrets into the **environment Key Vault**:

- `kvt-<product>-<env>-<region>-<seq>`

Examples (default `seq=01`):
- `kvt-hrz-dev-usaz-01`
- `kvt-hrz-qa-usaz-01`
- `kvt-hrz-uat-usaz-01`
- `kvt-hrz-prod-usaz-01`
- `kvt-pub-dev-cus-01`
- `kvt-pub-prod-cus-01`

**Important behavior:** the workflow **strips the prefix** when writing to destination.

So:
- `DEV--FOO` in the source becomes `FOO` in the destination.

---

## What you (developer/operator) do

### A) Create a new secret

1. Go to the **source core Key Vault** for your product and environment plane (see table above).
2. Create the secret with the **correct env prefix**:
   - If you are working on `dev`, name it `DEV--<name>`
   - If `qa`, name it `QA--<name>`
   - If `uat`, name it `UAT--<name>`
   - If `prod`, name it `PROD--<name>`
3. Set the secret value.
4. Run the workflow for the target environment (next section).

### B) Update an existing secret

1. Update the secret value in the **source core Key Vault** (same name, same prefix).
2. Run the workflow for the target environment.

---

## Running the workflow

Workflow name: **Bootstrap | Provision Secrets**

Inputs:
- `product`: `hrz` or `pub`
- `env`: `dev`, `qa`, `uat`, or `prod`
- `kv_sequence`: destination Key Vault sequence (default `01`)

### What to expect during a run

The workflow will:

1. **Enable Public Network Access (PNA)** and set `default-action Allow` on:
   - Source core Key Vault (in hub/core subscription)
   - Destination environment Key Vault (in the env subscription)

2. Find all secrets in the source KV with the environment prefix (e.g., `DEV--` for `dev`).

3. For each secret:
   - If destination secret does not exist → **CREATE**
   - If destination secret exists and value differs → **UPDATE**
   - If destination secret exists and value matches → **SKIP** (unchanged)

4. Log a summary like:
   - Total evaluated
   - Created
   - Updated
   - Unchanged (skipped)
   - Errors

5. **Disable PNA** and set `default-action Deny` on **both** Key Vaults (always, even on failure).

> If any secrets fail to sync, the job exits non-zero.

---

## Permissions & prerequisites

- The workflow uses **OIDC** (`azure/login@v2`) and requires:
  - `Key Vault Secrets Officer` (or equivalent) on **both** vaults (read source secrets, write destination secrets)
  - Permission to update Key Vault network settings (PNA and firewall default action) on **both** vaults
- GitHub secrets required for subscription selection:
  - **HRZ:** `AZ_SUB_HRZ_DEV`, `AZ_SUB_HRZ_QA`, `AZ_SUB_HRZ_UAT`, `AZ_SUB_HRZ_PROD`, `AZ_SUB_HRZ_CORE`
  - **PUB:** `AZ_SUB_PUB_DEV`, `AZ_SUB_PUB_QA`, `AZ_SUB_PUB_UAT`, `AZ_SUB_PUB_PROD`, `AZ_SUB_PUB_CORE`
- Tenant/client secrets used by the workflow:
  - `AZ_TENANT_HRZ`, `AZURE_CLIENT_ID_HRZ`
  - `AZ_TENANT_PUB`, `AZURE_CLIENT_ID_PUB`

---

## Quick examples

### Add a new DEV secret and sync to dev
1. In `kvt-hrz-np-usaz-core-01` (HRZ) create:
   - `DEV--SOME-SERVICE--API-KEY = <value>`
2. Run workflow:
   - `product=hrz`, `env=dev`, `kv_sequence=01`
3. Result in `kvt-hrz-dev-usaz-01`:
   - `SOME-SERVICE--API-KEY = <value>`

### Rotate a PROD secret and sync to prod
1. In `kvt-pub-pr-cus-core-01` (PUB) update:
   - `PROD--PAYMENTS--STRIPE-KEY = <new value>`
2. Run workflow:
   - `product=pub`, `env=prod`, `kv_sequence=01`
3. Result in `kvt-pub-prod-cus-01`:
   - `PAYMENTS--STRIPE-KEY` updated

---

## Notes

- Do **not** store unprefixed secrets in the source core Key Vault for this workflow—only prefixed secrets are considered.
- If a secret must exist in multiple environments, you must create one prefixed secret per environment (e.g., `DEV--...`, `QA--...`, etc.).

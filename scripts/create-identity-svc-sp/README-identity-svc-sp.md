# identity-svc Entra App + Service Principal Bootstrap

This repo includes a cross‑platform PowerShell script that creates (or reuses) an **Entra ID App Registration** + **Service Principal** for `identity-svc`, grants the Microsoft Graph **Application** permission `User.Read.All`, rotates a client secret, and outputs the resulting values to a JSON file.

> **Sensitive output:** the script prints and writes a **client secret value**. Treat the JSON output like a password (do not commit to git, do not paste in tickets/slack, etc.).

---

## What this script does

`create-identity-svc-sp.ps1` performs these steps:

1. **Validates prerequisites**
   - Requires Azure CLI (`az`)
   - Requires you to be logged in to the target tenant: `az login --tenant <TENANT_ID>`

2. **Creates or reuses the App Registration**
   - App display name follows the naming convention:
     - `app-<product>-<env>-<region>-identity-svc-<seq>`
     - Example: `app-hrz-dev-usaz-identity-svc-01`

3. **Adds Microsoft Graph permission requirement**
   - Adds **Application permission**: `User.Read.All`

4. **Grants the permission (admin consent equivalent)**
   - Instead of `az ad app permission admin-consent` (often unreliable), it grants the permission the same way the **Azure Portal** does:
   - Creates an **appRoleAssignment** on the **service principal** using `az rest` against Microsoft Graph

   If the assignment already exists, the script is idempotent and reports it as already granted.

5. **Creates/rotates a client secret**
   - Creates a new secret unless `-NoRotate` is provided
   - Secret expiration defaults to **365 days** (configurable)

6. **Writes an output JSON file**
   - Includes the `clientId`, secret value, expiration, and consent status

---

## Requirements

- PowerShell 7+ (pwsh)
  - Windows: install PowerShell 7 or use Windows Terminal + pwsh
  - macOS: `brew install --cask powershell`
- Azure CLI
  - macOS: `brew install azure-cli`
  - Windows: Azure CLI MSI installer
- Entra permissions to **grant app roles** (admin consent equivalent)
  - Typically one of: **Global Admin**, **Privileged Role Admin**, **Cloud App Admin**, **Application Admin** (tenant policy dependent)

---

## Login

Log into the correct tenant before running:

```bash
az login --tenant <TENANT_ID>
```

(If you’re already logged in but on the wrong tenant, the script will attempt to switch.)

---

## How to run

From the folder containing the script:

```bash
pwsh -File ./create-identity-svc-sp.ps1 `
  -Product hrz `
  -Env dev `
  -Region usaz `
  -Seq 01 `
  -TenantId dd58f16c-b85a-4d66-99e1-f86905453853
```

### Optional parameters

- `-SecretValidityDays 365` (default 365)
- `-NoRotate` (do not create a new secret; note you **cannot** retrieve an existing secret value)
- `-SkipAdminConsent` (adds permission requirement but **does not** grant it)
- `-OutputPath ./my-output.json` (override output path)

---

## Output JSON

By default the script writes:

`identity-svc-sp-<product>-<plane>-<region>-<env>-<seq>.json`

Example file name:
- `identity-svc-sp-hrz-np-usaz-dev-01.json`

Key fields you’ll use next:

- `tenantId` — the tenant GUID you passed in
- `clientId` — the App Registration (application) client ID
- `secretValue` — the newly created client secret value
- `secretExpiration` — expiration timestamp
- `consentGranted` / `consentMessage` — whether the permission grant succeeded

---

## Manual Key Vault update (required)

After generating the JSON output, you must **manually create or update secrets** in the **environment-specific Key Vault** for the app.

### Which Key Vault?

Use the Key Vault for the specific **product + env** you are deploying.

Examples:
- **HRZ + DEV** → `kvt-hrz-dev-usaz-01`
- **PUB + PROD** → `kvt-pub-prod-cus-01`

General pattern (adjust `region` to match your environment):
- HRZ:
  - `kvt-hrz-<env>-<region>-01`
- PUB:
  - `kvt-pub-<env>-<region>-01`

> If your org uses a different Key Vault naming scheme for a specific environment, follow the environment vault used by that cluster/app deployment.

### Which secrets to update

In the **env-specific Key Vault**, create/update these three secrets:

1. `IDENTITY-SVC--AZURE-TENANT-ID`
   - **Value:** `tenantId` from JSON (or the `-TenantId` you used)

2. `IDENTITY-SVC--AZURE-CLIENT-ID`
   - **Value:** `clientId` from JSON

3. `IDENTITY-SVC--AZURE-CLIENT-SECRET`
   - **Value:** `secretValue` from JSON

> These are **app runtime secrets** consumed by `identity-svc`. The script’s output also contains env-scoped secret *names* (like `DEV--...`) for labeling/traceability, but your runtime Key Vault entries should use the three names above unless your deployment expects otherwise.

### Portal steps

1. Azure Portal → Key Vaults → select the env vault (example: `kvt-hrz-dev-usaz-01`)
2. **Secrets** → **Generate/Import**
3. Name: one of the three names above
4. Value: paste from the JSON output
5. Save

### CLI steps (optional)

If you prefer Azure CLI:

```bash
az keyvault secret set --vault-name <VAULT_NAME> --name IDENTITY-SVC--AZURE-TENANT-ID       --value "<TENANT_ID>"
az keyvault secret set --vault-name <VAULT_NAME> --name IDENTITY-SVC--AZURE-CLIENT-ID       --value "<CLIENT_ID>"
az keyvault secret set --vault-name <VAULT_NAME> --name IDENTITY-SVC--AZURE-CLIENT-SECRET   --value "<CLIENT_SECRET_VALUE>"
```

---

## Troubleshooting

### Consent grant failed in script
If `consentGranted` is `false`, the most common causes are:
- your account lacks the Entra role required to grant app roles (admin consent equivalent)
- conditional access / tenant restrictions

Fix:
- Grant consent in the **Entra portal** (App registration → API permissions → “Grant admin consent…”), then re-run your workflow.

### Secret value is missing
If secret creation fails or returns no password:
- Ensure you have permission to create credentials for the app registration
- Try again with a user that can manage app credentials

---

## Security reminder

- Do **not** commit the output JSON to source control.
- Store the secret value only in your **environment Key Vault**.
- Rotate secrets regularly (or rerun the script when rotating) and update Key Vault accordingly.

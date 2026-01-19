# Grafana UI SSO – Entra ID App Registration (No Admin Consent)

This script creates (or reuses) an Entra ID **App Registration** + **Service Principal** for **Grafana UI SSO**, configures the settings you listed, and outputs a JSON file you can use to populate **Key Vault** secrets.

It **does not** perform admin consent.

## What gets configured

### 1) App registration + service principal
- App name:
  - `app-<product>-<env>-<region>-obs-grafana-sso-<seq>`
  - Example: `app-hrz-dev-usaz-obs-grafana-sso-01`

### 2) API permissions
- Microsoft Graph → **Delegated** → **User.Read**
  - “Sign in and read user profile”
  - ✅ Admin consent **not required**

### 3) Token configuration: Groups claim + optional groups claim (ID / Access / SAML)

#### Groups claim (manifest)
The script sets the app manifest property:
- `groupMembershipClaims = "All"`

Portal equivalent:
- **Token configuration → Add groups claim**
  - Security groups
  - Directory roles
  - All groups

#### Optional claim: `groups`
The script ensures the optional claim **groups** exists for:
- **ID token**
- **Access token**
- **SAML token**

Portal equivalent:
- **Token configuration → Add optional claim**
  - Claim: `groups`
  - Token types: **ID**, **Access**, **SAML**

### 4) Authentication: Redirect URIs (Web)

The following Web redirect URIs are configured and merged (env-specific):

- `https://internal.<env>.horizon.intterra.io:8443/logs`
- `https://internal.<env>.horizon.intterra.io/logs/login/azuread`
- `https://internal.<env>.horizon.intterra.io:8443/logs/login/azuread`

### 5) App roles
Created if missing (Allowed member types: **Users/Groups**, Enabled):
- Grafana Org Admin (Value: `Admin`)
- Grafana Editor (Value: `Editor`)
- Grafana Viewer (Value: `Viewer`)

### 6) Client secret
Creates/rotates a client secret and includes the secret **value** and **expiration** in the JSON output.

---

## Requirements

- PowerShell 7+ (`pwsh`) on macOS/Windows/Linux
- Azure CLI (`az`) installed
- Logged in to the correct Entra tenant:
  ```bash
  az login --tenant <TENANT_ID>
  ```

---

## Run it

```bash
pwsh -File ./create-grafana-sso-sp.ps1 `
  -Product hrz `
  -Env dev `
  -Region usaz `
  -Seq 01 `
  -TenantId <TENANT_ID>
```

Optional parameters:
- `-NoRotate` – Skip secret creation (cannot retrieve existing secret values)
- `-SecretValidityDays 730` – Secret lifetime (default 365)
- `-AllowedGroupIds "<guid1>,<guid2>"` – Override allowed group IDs
- `-AllowedDomains "intterragroup.com"` – Override allowed domains
- `-OutputPath ./my-output.json` – Output location

---

## Output JSON

Default output file name:
- `grafana-sso-sp-<product>-<plane>-<region>-<env>-<seq>.json`

Inside the JSON, check `.settings`. It includes the exact keys you want to store:

Example (DEV):

- `DEV--OBS--GRAFANA-ENTRA-CLIENT-ID=<client id>`
- `DEV--OBS--GRAFANA-ENTRA-CLIENT-SECRET=<secret value>`
- `DEV--OBS--GRAFANA-ENTRA-ALLOWED-GROUP-IDS=225931d5-d049-41e4-8561-cd77c16eeac8`
- `DEV--OBS--GRAFANA-ENTRA-AUTH-URL=https://login.microsoftonline.com/<tenant id>/oauth2/v2.0/authorize`
- `DEV--OBS--GRAFANA-ENTRA-TOKEN-URL=https://login.microsoftonline.com/<tenant id>/oauth2/v2.0/token`
- `DEV--OBS--GRAFANA-ENTRA-ALLOWED-ORGANIZATIONS=<tenant id>`
- `DEV--OBS--GRAFANA-ENTRA-ALLOWED-DOMAINS=intterragroup.com`

---

## Manually create/update Key Vault secrets

Use the values from `.settings` to create/update secrets in your **env-specific Key Vault**.

Examples you referenced:
- HRZ dev: `kvt-hrz-dev-usaz-01`
- PUB prod: `kvt-pub-prod-cus-01`

Azure CLI example:

```bash
az keyvault secret set --vault-name <VAULT_NAME> --name "DEV--OBS--GRAFANA-ENTRA-CLIENT-ID" --value "<client id>"
az keyvault secret set --vault-name <VAULT_NAME> --name "DEV--OBS--GRAFANA-ENTRA-CLIENT-SECRET" --value "<secret value>"
# ...repeat for the rest of the keys in .settings
```

> The JSON output contains the client secret in plaintext. Treat it as **sensitive** and do not commit it to source control.

---

## Files

- `create-grafana-sso-sp.ps1` – script
- `README-grafana-sso.md` – this documentation

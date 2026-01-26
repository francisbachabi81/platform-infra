# create-gha-platform-infra-sp.ps1

Creates (or reuses) an **Entra ID App Registration + Service Principal** for **GitHub Actions OIDC**, creates **federated credentials** scoped to **GitHub Environments**, assigns **RBAC** at subscription + management group scope, and writes a **JSON output summary**.

---

## What this script does

When you run the script, it will:

1. **Validate inputs**
   - Ensures you provided the right subscription IDs for the selected plane (`nonprod` or `prod`).
   - Ensures `Product` and `ManagementGroupId` are provided.

2. **Ensure Azure CLI is in the correct tenant**
   - Checks `az account show` tenant.
   - If it doesn’t match `-TenantId`, it runs `az login --tenant <TenantId>`.

3. **Create or reuse the App Registration**
   - App registration display name:
     - `app-gha-<Product>-<Repo>-<Cloud>-<Plane>`
   - If the app already exists (same display name), it reuses it.

4. **Create or reuse the Service Principal**
   - Ensures the enterprise application (service principal) exists for the app.

5. **Create federated credentials for GitHub Environments**
   - Uses the **Environment** subject format:
     - `repo:<org>/<repo>:environment:<env>`
   - Issuer:
     - `https://token.actions.githubusercontent.com`
   - Audience:
     - `api://AzureADTokenExchange` (commercial)
     - `api://AzureADTokenExchangeUSGov` (gov)
   - If a federated credential already exists with the same name, it is **deleted and recreated** to guarantee correctness.

6. **Assign RBAC**
   - **Contributor** on required subscriptions
   - **Reader** on the provided Management Group

7. **Write output JSON**
   - Includes app IDs, federated credentials, and RBAC assignments

---

## Prerequisites

- PowerShell 7+
- Azure CLI (`az`)
- Logged in with:
  ```bash
  az login
  ```

### Required permissions
- Ability to create App Registrations / Service Principals
- Owner or User Access Administrator on target subscriptions
- Reader assignment rights on the management group

---

## Parameters

### Required
- `-Cloud` (`gov` | `commercial`)
- `-Plane` (`nonprod` | `prod`)
- `-TenantId`
- `-Product`
- `-ManagementGroupId`

### Plane-specific
**Nonprod**
- `-NonprodCoreSubId`
- `-DevSubId`
- `-QaSubId`

**Prod**
- `-ProdCoreSubId`
- `-ProdSubId`
- `-UatSubId`

### Optional
- `-Org` (default: `test`)
- `-Repo` (default: `platform-infra`)
- `-OutputJson`
- `-AzDebug`

---

## Example usage

### Nonprod (Gov)

```powershell
pwsh -File ./create-gha-platform-infra-sp.ps1 \
  -Cloud gov \
  -Plane nonprod \
  -TenantId "ed7990c3-61c2-477d-85e9-1a396c19ae94" \
  -Product "hrz" \
  -Org "intterra-io" -Repo "platform-infra" \
  -ManagementGroupId "2d14dd5f-6f19-40b5-86c6-c74fe435f1da" \
  -NonprodCoreSubId "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c" \
  -DevSubId "62ae6908-cbcb-40cb-8773-54bd318ff7f9" \
  -QaSubId "d4c1d472-722c-49c2-857f-4243441104c8"
```
### Prod (Gov)

```powershell
pwsh -File ./create-gha-platform-infra-sp.ps1 \
  -Cloud gov \
  -Plane prod \
  -TenantId "ed7990c3-61c2-477d-85e9-1a396c19ae94" \
  -Product "hrz" \
  -Org "intterra-io" -Repo "platform-infra" \
  -ManagementGroupId "57fc50f6-0f70-420b-bf12-7bced8705c33" \
  -ProdCoreSubId "641d3872-8322-4bdb-83ce-bfbc119fa3cd" \
  -UatSubId "4d2bdae0-9da9-4657-827d-d44867ec2f0a" \
  -ProdSubId "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
```

### Nonprod (Commercial)

```powershell
pwsh -File ./create-gha-platform-infra-sp.ps1 \
  -Cloud commercial \
  -Plane nonprod \
  -TenantId "dd58f16c-b85a-4d66-99e1-f86905453853" \
  -Product "pub" \
  -Org "intterra-io" -Repo "platform-infra" \
  -ManagementGroupId "dfc4ebbc-a6c7-4e02-87da-ee36f21e566f" \
  -NonprodCoreSubId "ee8a4693-54d4-4de8-842b-b6f35fc0674d" \
  -DevSubId "57f8aa30-981c-4764-94f6-6691c4d5c01c" \
  -QaSubId "647feab6-e53a-4db2-99ab-55d04a5997d7"
```

### Prod (Commercial)

```powershell
pwsh -File ./create-gha-platform-infra-sp.ps1 \
  -Cloud commercial \
  -Plane prod \
  -TenantId "dd58f16c-b85a-4d66-99e1-f86905453853" \
  -Product "pub" \
  -Org "intterra-io" -Repo "platform-infra" \
  -ManagementGroupId "c49201f7-7e9a-472a-b8c3-178bc77dff73" \
  -ProdCoreSubId "ec41aef1-269c-4633-8637-924c395ad181" \
  -UatSubId "11494ded-2cf5-44b7-9b1c-58fd64125c20" \
  -ProdSubId "7043433f-e23e-4206-9930-314695d94a6c"
```

---

## GitHub Actions configuration

Your GitHub workflow must:

```yaml
permissions:
  id-token: write
  contents: read
```

Environment names must match the federated credentials:
- `dev`, `qa`, `nonprod`
- `prod`, `uat`, `coreprod`

---

## Output

Default output file:
```
gha-oidc-<Product>-<Repo>-<Cloud>-<Plane>.json
```

Includes:
- App registration identifiers
- Federated credential details
- Role assignments

---

## Verification

```bash
az ad app federated-credential list --id <APP_OBJECT_ID> -o table
az role assignment list --assignee-object-id <SP_OBJECT_ID> --all -o table
```

---

## Naming summary

- **App registration**
  ```
  app-gha-<Product>-<Repo>-<Cloud>-<Plane>
  ```

- **Federated credential subject**
  ```
  repo:<org>/<repo>:environment:<env>
  ```

---

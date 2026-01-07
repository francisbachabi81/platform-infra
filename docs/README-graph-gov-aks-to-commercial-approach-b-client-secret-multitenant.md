# Gov AKS ➜ Commercial Entra ID (Graph) — Approach B: Client ID + Client Secret (Simple, but requires rotation)

This README describes how to let a **workload running in Azure Government AKS** (e.g., `identity-svc`) call **Microsoft Graph in a Commercial Entra ID tenant** using **client credentials with a client secret** stored in **Gov Key Vault** and injected into the pod.

> **Why this approach**
>
> - ✅ Fast to implement and easy to reason about  
> - ✅ Does not require enabling AKS Workload Identity  
> - ❌ Requires storing + rotating a secret  
> - ❌ Wider blast radius if the secret leaks

---

## What you are building

- **Commercial tenant**: App Registration with Graph **Application permissions** and a **client secret** (or cert).
- **Gov Key Vault**: stores `TENANT_ID`, `CLIENT_ID`, and `CLIENT_SECRET`.
- **Gov AKS / identity-svc**: reads those values via your injection mechanism and requests tokens from the **Commercial** token endpoint.

---

## Prerequisites

### Access / Roles

**Commercial Entra ID**
- Permission to create App Registrations and grant **admin consent**
- Permission to create and manage client secrets (or certs)

**Gov Key Vault**
- Permission to set secrets
- Your mechanism for injecting Key Vault values into AKS pods (CSI driver, external-secrets, Helm templates, etc.)

### Tooling
- `az` CLI (optional)
- `kubectl` (optional)

---

## Inputs you must collect

| Name | Where it comes from | Example |
|---|---|---|
| `COMMERCIAL_TENANT_ID` | Commercial Entra tenant | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `COMMERCIAL_APP_CLIENT_ID` | Commercial App Registration | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `COMMERCIAL_APP_CLIENT_SECRET` | Commercial App secret value | `******` |
| `K8S_NAMESPACE` | Your cluster | `identity` |

---

## Step 1 — Commercial tenant: create an App Registration

In **Commercial Entra ID**:

1. **Entra ID ➜ App registrations ➜ New registration**
2. Name: `sp-hrz-dev-usaz-identity-svc` (example)
3. Supported account types: usually **Single tenant**
4. Create

Record:
- Application (client) ID = `COMMERCIAL_APP_CLIENT_ID`
- Directory (tenant) ID = `COMMERCIAL_TENANT_ID`

---

## Step 2 — Add Microsoft Graph Application permissions

For “look up valid users” typical choices are:

- `User.Read.All` (**Application**)
- Optional: `Directory.Read.All` (**Application**) if needed

Then:
- Click **Grant admin consent**.

> Ensure these are **Application** permissions (not Delegated).

---

## Step 3 — Create a Client Secret (Commercial)

In the App Registration:

- **Certificates & secrets ➜ Client secrets ➜ New client secret**
- Set an expiration aligned to your rotation policy (e.g., 90/180/365 days)
- Copy the secret value immediately (you won’t see it again)

This becomes:
- `COMMERCIAL_APP_CLIENT_SECRET`

> **Security note**: Prefer certificates over secrets if you have a mature cert management process.

---

## Step 4 — Store values in Gov Key Vault

Using your env-prefix convention:

- `DEV--AZURE--TENANT--ID` = `COMMERCIAL_TENANT_ID`
- `DEV--AZURE--CLIENT--ID` = `COMMERCIAL_APP_CLIENT_ID`
- `DEV--AZURE--CLIENT--SECRET` = `COMMERCIAL_APP_CLIENT_SECRET`

### Example: Azure CLI (Gov Key Vault)

```bash
az keyvault secret set --vault-name <GOV_KV_NAME> --name "DEV--AZURE--TENANT--ID" --value "<COMMERCIAL_TENANT_ID>"
az keyvault secret set --vault-name <GOV_KV_NAME> --name "DEV--AZURE--CLIENT--ID" --value "<COMMERCIAL_APP_CLIENT_ID>"
az keyvault secret set --vault-name <GOV_KV_NAME> --name "DEV--AZURE--CLIENT--SECRET" --value "<COMMERCIAL_APP_CLIENT_SECRET>"
```

---

## Step 5 — Inject Key Vault secrets into the `identity-svc` pod

How you inject depends on your current approach. The end state should be environment variables (or config file) available to the container:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

Example Deployment env block:

```yaml
env:
- name: AZURE_TENANT_ID
  valueFrom: ...
- name: AZURE_CLIENT_ID
  valueFrom: ...
- name: AZURE_CLIENT_SECRET
  valueFrom: ...
```

If you’re using mounted files instead, map them into these env vars in your entrypoint or app config.

---

## Step 6 — App code: request token using ClientSecretCredential

### Token scope

Use:

```
https://graph.microsoft.com/.default
```

### Node.js example (Azure Identity SDK)

```js
import { ClientSecretCredential } from "@azure/identity";

const tenantId = process.env.AZURE_TENANT_ID;
const clientId = process.env.AZURE_CLIENT_ID;
const clientSecret = process.env.AZURE_CLIENT_SECRET;

const credential = new ClientSecretCredential(tenantId, clientId, clientSecret);

const token = await credential.getToken("https://graph.microsoft.com/.default");
console.log("token exp:", token.expiresOnTimestamp);
```

Then call Graph (example):

- `GET https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,mail`

> The token endpoint is Commercial (`login.microsoftonline.com`) because the tenant/app live in Commercial.

---

## Rotation strategy (required)

You should define:
- Secret lifetime (e.g., 90 or 180 days)
- Rotation process (manual or automated)
- Rollout order (create new secret ➜ update KV ➜ restart pods ➜ remove old secret)

### Recommended rotation procedure

1. Create a **new** client secret in Commercial app registration
2. Update the Gov Key Vault secret value `DEV--AZURE--CLIENT--SECRET`
3. Trigger a rollout restart of `identity-svc`:

```bash
kubectl -n identity rollout restart deploy/identity-svc
```

4. Validate token acquisition + Graph call success
5. Delete the **old** client secret in Commercial

> Keep overlap time long enough to roll across environments safely.

---

## Security & scoping notes

- Anyone with access to the secret can impersonate the app from anywhere (not just Gov AKS).
- Use K8s RBAC to restrict who can view injected secrets/config.
- Prefer Key Vault + CSI driver over Kubernetes Secrets if possible.
- Prefer certificate-based auth if your org can manage it properly.

---

## Validation / Smoke tests

### Confirm env vars are present

```bash
kubectl -n identity exec -it deploy/identity-svc -- printenv | egrep 'AZURE_(TENANT_ID|CLIENT_ID|CLIENT_SECRET)'
```

### Confirm Graph calls succeed
- Check app logs for token acquisition
- Ensure Graph returns `200`

---

## Common issues & troubleshooting

### 1) `invalid_client` / `AADSTS7000215`
- Wrong client secret (value copied incorrectly)
- Secret expired
- Using secret ID instead of secret value

### 2) Graph 403
- Missing Graph application permission
- Admin consent not granted
- Permission granted as Delegated instead of Application

### 3) TLS / authority confusion
- Ensure authority host is Commercial:
  - `https://login.microsoftonline.com/`

---

## What changes devs need to make
- Add env vars `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` via your KV injection
- Use `ClientSecretCredential` (or equivalent) in code
- Implement/agree on a secret rotation playbook

---

## Summary
This approach is straightforward and works without AKS Workload Identity, but it introduces secret storage and rotation overhead and expands the blast radius if the secret is compromised.

---

## Future Expansion — Supporting Multiple Entra ID Tenants (Approach B)

This approach can also support **multiple Commercial Entra ID tenants**, but with additional operational overhead due to **client secret management**.

### Recommended model: Multi-tenant App + Per-tenant Secrets

- Convert (or register) the Commercial App Registration as **multi-tenant**:
  - `signInAudience = AzureADMultipleOrgs`
- Each tenant:
  - Grants **admin consent** for required Microsoft Graph **Application permissions**
- For each tenant, generate:
  - A **client secret** (or certificate)
- Store secrets **per tenant** in Gov Key Vault.

Example Key Vault naming:
```
DEV--AZURE--TENANT--ID--TENANT1
DEV--AZURE--CLIENT--ID--TENANT1
DEV--AZURE--CLIENT--SECRET--TENANT1
```

### identity-svc changes
- Maintain a **tenant allowlist**.
- Select credentials dynamically based on tenant.
- Instantiate `ClientSecretCredential` using the selected tenant’s values.

### Security implications
- Secret sprawl increases with tenant count.
- Each secret must be:
  - Rotated
  - Audited
  - Scoped carefully
- Compromise of one secret affects that tenant only, but still allows off-cluster impersonation.

### When this approach makes sense
- Small, fixed number of tenants.
- Workload Identity cannot be enabled (policy or technical constraints).
- You already have a mature secret rotation pipeline.

### Strong recommendation
If multi-tenant support becomes a long-term requirement, **migrate to Approach A** to avoid exponential secret management complexity.

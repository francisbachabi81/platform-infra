# Gov AKS ➜ Commercial Entra ID (Graph) — Approach A: AKS Workload Identity (Recommended)

This README describes how to let a **workload running in Azure Government AKS** (e.g., `identity-svc`) call **Microsoft Graph in a Commercial Entra ID tenant** to look up users (or other directory data) using **client credentials** **without client secrets**, via **AKS Workload Identity + Federated Credentials**.

> **Why this approach**
>
> - ✅ No client secret to store or rotate  
> - ✅ Strong scoping: you can bind access to **one namespace + one ServiceAccount**  
> - ✅ Works across clouds/tenants: token endpoint is Commercial, workload runs in Gov  
> - ✅ Least operational overhead once set up

---

## What you are building

- **Commercial tenant**: an App Registration (service principal) with Microsoft Graph **Application permissions** (e.g., `User.Read.All`), and a **Federated Credential** that trusts the Gov AKS OIDC issuer for a specific K8s service account identity.
- **Gov AKS**: Workload Identity enabled + OIDC issuer enabled; `identity-svc` pods run with a specific Kubernetes **ServiceAccount** annotated with the Commercial app client ID.
- **identity-svc**: uses Azure Identity SDK (e.g., `DefaultAzureCredential`) to request tokens for `https://graph.microsoft.com/.default`.

---

## Prerequisites

### Access / Roles

**Gov subscription / AKS**
- Rights to update AKS cluster settings (OIDC issuer + Workload Identity)
- Rights to apply Kubernetes manifests (namespace, service account, deployment)

**Commercial Entra ID**
- Permission to create App Registrations and Service Principals
- Permission to grant **admin consent** for Microsoft Graph application permissions

### Tooling
- `az` CLI
- `kubectl`
- Optional: `jq`

---

## Inputs you must collect

| Name | Where it comes from | Example |
|---|---|---|
| `COMMERCIAL_TENANT_ID` | Commercial Entra tenant | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `COMMERCIAL_APP_CLIENT_ID` | Commercial App Registration | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `GOV_AKS_OIDC_ISSUER_URL` | Gov AKS (OIDC issuer URL) | `https://oidc.prod-xx...aks.azure.us/.../` |
| `K8S_NAMESPACE` | Your cluster | `identity` |
| `K8S_SERVICEACCOUNT` | Your manifests | `identity-svc` |

---

## Step 1 — Enable Workload Identity + OIDC issuer on Gov AKS

### Option 1: Terraform (preferred)

In your `azurerm_kubernetes_cluster`:

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  # ...
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}
```

Apply:

```bash
terraform apply
```

### Option 2: Azure CLI

> CLI property names may vary by CLI version. Prefer Terraform for consistency.

```bash
az aks update \
  -g <AKS_RG> \
  -n <AKS_NAME> \
  --enable-oidc-issuer \
  --enable-workload-identity
```

---

## Step 2 — Find `GOV_AKS_OIDC_ISSUER_URL`

```bash
az aks show -g <AKS_RG> -n <AKS_NAME> --query "oidcIssuerProfile.issuerUrl" -o tsv
```

Save it as:

```bash
export GOV_AKS_OIDC_ISSUER_URL="$(az aks show -g <AKS_RG> -n <AKS_NAME> --query "oidcIssuerProfile.issuerUrl" -o tsv)"
echo "$GOV_AKS_OIDC_ISSUER_URL"
```

---

## Step 3 — Create K8s namespace (if not already)

```bash
export K8S_NAMESPACE="identity"
kubectl get ns "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$K8S_NAMESPACE"
```

---

## Step 4 — Create a dedicated ServiceAccount for `identity-svc`

Create a ServiceAccount annotated with the **Commercial** App client ID.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: identity-svc
  namespace: identity
  annotations:
    azure.workload.identity/client-id: "<COMMERCIAL_APP_CLIENT_ID>"
```

Apply it:

```bash
kubectl apply -f serviceaccount.identity-svc.yaml
```

> **Important**
>
> - This annotation is what tells the Workload Identity webhook which client ID to use.
> - You can keep this strictly scoped to only the `identity-svc` ServiceAccount.

---

## Step 5 — Update the `identity-svc` Deployment to use Workload Identity

You need:
1. Pod template label `azure.workload.identity/use: "true"`
2. `serviceAccountName: identity-svc`
3. Environment variables for tenant + client id (optional to inject; many SDKs infer client ID via token file, but setting explicitly is common)

Example snippet:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: identity-svc
  namespace: identity
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: identity-svc
      containers:
      - name: identity-svc
        env:
        - name: AZURE_TENANT_ID
          value: "<COMMERCIAL_TENANT_ID>"
        - name: AZURE_CLIENT_ID
          value: "<COMMERCIAL_APP_CLIENT_ID>"
        # Optionally pin authority:
        # - name: AZURE_AUTHORITY_HOST
        #   value: "https://login.microsoftonline.com/"
```

Apply:

```bash
kubectl apply -f deployment.identity-svc.yaml
```

---

## Step 6 — Commercial tenant: create an App Registration for the workload

In **Commercial Entra ID**:

1. **Entra ID ➜ App registrations ➜ New registration**
2. Name: `sp-hrz-dev-usaz-identity-svc` (example)
3. Supported account types: usually **Single tenant** (your org)
4. Create

Record:
- `COMMERCIAL_APP_CLIENT_ID`
- Directory (tenant) ID = `COMMERCIAL_TENANT_ID`

### Add Microsoft Graph **Application permissions**

For “look up valid users” typical choices are:

- `User.Read.All` (**Application**)
- Optional: `Directory.Read.All` (**Application**) if you need more than user profile data (use sparingly)

Then:
- Click **Grant admin consent**.

> If you only need to read a subset of properties or avoid directory-wide read, consider alternate designs (e.g., controlled API, group-based lookups, etc.).

---

## Step 7 — Commercial tenant: add Federated Credential to the App

This is the critical binding that limits who can exchange tokens.

In the Commercial App Registration:

- **Certificates & secrets ➜ Federated credentials ➜ Add credential**
- Credential type: **Kubernetes**
- Issuer: `GOV_AKS_OIDC_ISSUER_URL`
- Namespace: `K8S_NAMESPACE`
- Service account: `K8S_SERVICEACCOUNT`
- Audience: `api://AzureADTokenExchange`

The resulting **Subject** should match:

```
system:serviceaccount:<K8S_NAMESPACE>:<K8S_SERVICEACCOUNT>
```

Example:

```
system:serviceaccount:identity:identity-svc
```

---

## Step 8 — Configure the app to request Graph tokens (no secret)

### Token scope

Use:

```
https://graph.microsoft.com/.default
```

### Node.js example (Azure Identity SDK)

```js
import { DefaultAzureCredential } from "@azure/identity";

const credential = new DefaultAzureCredential();

// Graph scope for client credentials
const scope = "https://graph.microsoft.com/.default";

const token = await credential.getToken(scope);
console.log("got token exp:", token.expiresOnTimestamp);
```

Then call Graph:

- `GET https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,mail`

> The token will be issued by the **Commercial** tenant because `AZURE_TENANT_ID` points there and the app registration lives there.

---

## Step 9 — Key Vault (Gov) values to inject into the pod

Even with Workload Identity, it’s common to inject the **tenant** and **client ID** from Key Vault.

Create/ensure these values exist (names per your convention):

- `DEV--AZURE--TENANT--ID` = `COMMERCIAL_TENANT_ID`
- `DEV--AZURE--CLIENT--ID` = `COMMERCIAL_APP_CLIENT_ID`

No secret required.

### Example: env vars from mounted secret values

How you inject depends on your platform (CSI driver, external secrets operator, etc.). Typical env var names:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`

---

## Security & scoping notes

- **Scoped to a ServiceAccount**: only pods with the correct ServiceAccount and label get token injection.
- **Federated credential enforces subject match**: even if another pod copies the annotation, it must use the same SA identity (and be allowed to run it).
- **Use RBAC** in K8s to control who can create/patch service accounts and deployments.
- **Prefer least Graph permissions** and avoid `Directory.Read.All` unless truly needed.

---

## Validation / Smoke tests

### Confirm SA exists and is annotated

```bash
kubectl -n "$K8S_NAMESPACE" get sa "$K8S_SERVICEACCOUNT" -o yaml | sed -n '1,120p'
```

### Confirm pods have label and SA

```bash
kubectl -n "$K8S_NAMESPACE" get pod -l app=identity-svc -o jsonpath='{range .items[*]}{.metadata.name}{"  SA="}{.spec.serviceAccountName}{"  label="}{.metadata.labels.azure\.workload\.identity/use}{"\n"}{end}'
```

### Exec into pod and check token envs

```bash
kubectl -n "$K8S_NAMESPACE" exec -it deploy/identity-svc -- printenv | egrep 'AZURE_(TENANT_ID|CLIENT_ID|AUTHORITY_HOST)'
```

### If you have curl + token test endpoint in app logs
Look for:
- successful token acquisition
- Graph 200 responses

---

## Common issues & troubleshooting

### 1) `AADSTS70021: No matching federated identity record found`
- Subject mismatch: ensure `system:serviceaccount:<ns>:<sa>` matches
- Wrong issuer URL: must match AKS `oidcIssuerProfile.issuerUrl` exactly
- Wrong audience: should be `api://AzureADTokenExchange`

### 2) Access denied calling Graph (403)
- Missing Graph application permission
- Admin consent not granted
- Permission granted as *Delegated* instead of *Application*

### 3) Pod not getting projected token / no identity behavior
- Missing pod label: `azure.workload.identity/use: "true"`
- Using wrong ServiceAccount
- Workload Identity not enabled on the cluster
- Webhook not installed/enabled (AKS managed add-on behavior typically handles this)

---

## What changes devs need to make
- Add a dedicated ServiceAccount for `identity-svc`
- Add pod label `azure.workload.identity/use: "true"`
- Ensure deployment uses that ServiceAccount
- App code uses `DefaultAzureCredential` + Graph `.default` scope
- Read `AZURE_TENANT_ID` / `AZURE_CLIENT_ID` from configuration (Key Vault injection is fine)

---

## Summary
With Workload Identity, your Gov-hosted `identity-svc` can securely authenticate to **Commercial Entra ID** and call **Graph** without managing client secrets, while keeping access scoped to a specific Kubernetes ServiceAccount.

---

## Future Expansion — Supporting Multiple Entra ID Tenants (Approach A)

This approach **continues to work** if we later need to authenticate users or query Microsoft Graph across **multiple Commercial Entra ID tenants**.

### Recommended model: Multi-tenant App + Single Workload Identity

- Keep **one AKS Workload Identity** bound to the `identity-svc` Kubernetes ServiceAccount.
- Convert (or register) the Commercial App Registration as **multi-tenant**:
  - `signInAudience = AzureADMultipleOrgs`
- Each external tenant:
  - Creates a **Service Principal** for the app in their tenant
  - Grants **admin consent** for the required Microsoft Graph **Application permissions**
- `identity-svc` dynamically requests tokens from the **target tenant’s authority**:
  ```
  https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token
  ```

### What does *not* change
- No client secrets are introduced.
- Federated credentials remain bound to:
  ```
  system:serviceaccount:<namespace>:<serviceaccount>
  ```
- Only pods using that ServiceAccount can acquire tokens.

### Required app changes
- Maintain an **allowlist of supported tenant IDs** (config, DB, or Key Vault).
- Select the authority host dynamically based on tenant context.
- Validate:
  - Token issuer (`iss`)
  - Tenant ID (`tid`)
  - Audience (`aud`)

### Operational considerations
- Admin consent is required **per tenant**.
- Graph permissions must remain consistent across tenants.
- Logging and auditing should include tenant ID context.

### When to consider per-tenant apps instead
- Different tenants require different Graph permissions.
- Regulatory or contractual isolation is required.
- You want separate consent and audit boundaries.

In those cases, create **one Commercial app registration per tenant**, each with its own federated credential referencing the same AKS OIDC issuer and ServiceAccount.

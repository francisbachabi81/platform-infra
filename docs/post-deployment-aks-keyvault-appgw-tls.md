# Pre- and Post-Deployment: TLS Certificate Flow from AKS to Key Vault to Application Gateway (RBAC)

## Overview (READ FIRST)

Before configuring **Application Gateway** to consume TLS certificates from **Azure Key Vault**, you must first **extract the certificate from AKS (cert-manager)** and **push it into Key Vault**.

This initial step ensures:
- Application Gateway has a valid certificate to reference
- RBAC permissions can be validated early
- Listener configuration will succeed without errors

> Certificates are **issued and renewed by cert-manager inside AKS**.  
> Application Gateway **does not renew certificates** — it only consumes the latest version from Key Vault.

The sections below are ordered to reflect the **correct operational flow**.

---

## Step 0: Grab Certificate from AKS and Push to Key Vault (Manual Bootstrap)

These steps are typically required **once per environment** (DEV / QA / PROD) to bootstrap the certificate into Key Vault.  
Subsequent renewals should be automated.

### 0.1 Set Azure Subscription

```bash
az account set --subscription df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c
```

---

### 0.2 Get AKS Credentials

```bash
az aks get-credentials   --resource-group rg-hrz-np-usaz-core-01   --name aks-hrz-np-usaz-01   --overwrite-existing
```

If using Entra ID authentication:

```bash
kubelogin convert-kubeconfig -l azurecli
```

---

### 0.3 Verify Cluster Access

```bash
kubectl get deployments --all-namespaces=true
```

---

### 0.4 Extract TLS Certificate and Key from AKS Secret

> Namespace: `dev`  
> Secret: `api-gateway-tls`

```bash
kubectl get secret api-gateway-tls -n dev -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret api-gateway-tls -n dev -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
```

---

### 0.5 Convert to PFX (PKCS#12)

```bash
openssl pkcs12 -export   -in tls.crt   -inkey tls.key   -out cert.pfx   -passout pass:
```

---

### 0.6 Import Certificate into Key Vault

```bash
az account set --subscription df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c

az keyvault certificate import   --vault-name kvt-hrz-np-usaz-core-01   --name appgw-gateway-cert-horizon-dev   --file cert.pfx   --password ""
```

---

# Post-Deployment: Configure Application Gateway to Pull TLS Certificates from Key Vault (RBAC)

## Purpose
This document describes the **post-deployment steps** required to configure an **Azure Application Gateway (WAF_v2)** to retrieve an HTTPS certificate from **Azure Key Vault** using **Azure RBAC** and a **User Assigned Managed Identity (UAMI)**.

Certificates are assumed to be:
- Issued and renewed by **cert-manager inside AKS**
- Exported as **Key Vault secrets (PFX)**
- Referenced by **Application Gateway HTTPS listeners**

Although the example below uses **DEV**, the same steps apply to **QA** and **PROD** with naming changes only.

---

## Architecture Overview

AKS (cert-manager)  
→ AKS (api-gateway)  
→ Azure Key Vault (RBAC enabled)  
→ Application Gateway (WAF_v2)  
→ HTTPS Listener / TLS termination

---

## Prerequisites

- Application Gateway **WAF_v2** already exists
- Key Vault:
  - Uses **Azure RBAC authorization**
  - Contains a **secret-backed certificate (PFX)**
- A **User Assigned Managed Identity (UAMI)** exists
- Azure CLI authenticated to the correct subscription
- You have **Owner** or **User Access Administrator** permissions

---

## Variables to Update per Environment

| Item | DEV Example | Notes |
|---|---|---|
| App Gateway RG | rg-hrz-np-usaz-appgw-01 | Change per env |
| App Gateway Name | agw-hrz-np-usaz-01 | Change per env |
| Key Vault Name | kvt-hrz-np-usaz-core-01 | Change per Core/Hub KV |
| Certificate Secret | appgw-gateway-cert-horizon-dev | Certificate name only |
| UAMI Resource ID | /subscriptions/.../userAssignedIdentities/... | Core identity |

```bash
RG_APPGW="rg-hrz-np-usaz-net-01"
APPGW_NAME="agw-hrz-np-usaz-01"

UAMI_ID="/subscriptions/df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c/resourceGroups/rg-hrz-np-usaz-core-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-hrz-np-usaz-core-01"

KV_NAME="kvt-hrz-np-usaz-core-01"
CERT_SECRET_NAME="appgw-gateway-cert-horizon-dev"
APPGW_SSL_CERT_NAME="$CERT_SECRET_NAME"
```

---

## Step-by-Step Configuration (Azure CLI)

### 1. Assign User Assigned Identity to Application Gateway

```bash
az network application-gateway identity assign   -g "$RG_APPGW"   --gateway-name "$APPGW_NAME"   --identity "$UAMI_ID"
```

---

### 2. Get the Unversioned Secret ID

```bash
SECRET_ID_VERSIONED="$(az keyvault secret show   --vault-name "$KV_NAME"   --name "$CERT_SECRET_NAME"   --query id -o tsv)"

SECRET_ID_UNVERSIONED="$(echo "$SECRET_ID_VERSIONED" | sed -E 's#/[^/]+$##')"
```

---

### 3. Create or Update the SSL Certificate on Application Gateway

```bash
az network application-gateway ssl-cert create   -g "$RG_APPGW"   --gateway-name "$APPGW_NAME"   -n "$APPGW_SSL_CERT_NAME"   --key-vault-secret-id "$SECRET_ID_UNVERSIONED"   || az network application-gateway ssl-cert update     -g "$RG_APPGW"     --gateway-name "$APPGW_NAME"     -n "$APPGW_SSL_CERT_NAME"     --key-vault-secret-id "$SECRET_ID_UNVERSIONED"
```

---

### 4. Bind the Certificate to the HTTPS Listener

1. Open **Application Gateway**
2. Navigate to **Listeners**
3. Select the HTTPS listener
4. Choose the SSL certificate created above
5. Save changes

---

## Common Errors & Fixes

### "Key vault doesn't allow access to the managed identity"
- Ensure Key Vault uses **Azure RBAC authorization**
- Ensure **Key Vault Secrets User** role is assigned to the App Gateway identity
- Ensure the App Gateway identity is attached

---

## Notes for QA / PROD

- Same process, naming only differs
- Strongly recommended to automate certificate sync using cert-manager + CronJob
- Application Gateway will automatically reload certificates when Key Vault secret versions change

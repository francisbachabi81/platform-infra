# Azure Front Door Config Stack (`afd-config`)
# Test
This stack manages **Azure Front Door (AFD) Standard/Premium runtime configuration** separately from the `shared-network` stack.

It is intentionally scoped to *high‑churn, application‑level routing concerns* such as:
- origins
- routes
- custom domains
- TLS configuration
- WAF association

while keeping the **AFD shell and network primitives stable** in `shared-network`.

---

## Why this stack exists

The `shared-network` stack is frequently redeployed to manage:
- VNets / subnets
- NSGs / UDRs
- DNS zones
- core connectivity

Azure Front Door configuration changes much more often and carries higher blast radius if redeployed accidentally.

To reduce risk and drift:

- **`shared-network`** owns the *AFD shell*
- **`afd-config`** owns the *AFD runtime configuration*

This mirrors the same split used for `app-gateway-config`.

---

## Ownership model

### `shared-network` owns (baseline / shell)

- `azurerm_cdn_frontdoor_profile`
- `azurerm_cdn_frontdoor_endpoint`
- Network primitives (VNets, subnets, NSGs, DNS zones)
- Optional managed identity on the AFD profile

**Required outputs from `shared-network`:**

```hcl
output "afd" {
  value = {
    profile = {
      id           = azurerm_cdn_frontdoor_profile.this.id
      name         = azurerm_cdn_frontdoor_profile.this.name
      principal_id = try(azurerm_cdn_frontdoor_profile.this.identity[0].principal_id, null)
    }
    endpoint = {
      id       = azurerm_cdn_frontdoor_endpoint.this.id
      name     = azurerm_cdn_frontdoor_endpoint.this.name
      hostname = azurerm_cdn_frontdoor_endpoint.this.host_name
    }
  }
}
```

---

### `afd-config` owns (runtime configuration)

- Origin groups
- Origins
- Routes
- Custom domains
- TLS bindings (Managed or Customer certs)
- Optional rule sets / rules
- Optional WAF policy + security policy association

🚫 **DNS records are intentionally excluded**.

---

## Traffic flow overview

`afd-config` supports **two primary traffic paths** (PUB) and one (HRZ).

---

## Flow 1: Public application traffic (AFD → App Gateway → AKS)

```
Client
  |
  v
Azure Front Door
  |
  v
Application Gateway
  |
  v
Ingress / API Gateway (AKS)
  |
  v
Backend services
```

- TLS terminates at AFD
- App Gateway is the AFD origin
- AKS hosts the backend workloads

---

## Flow 2: Public layers / static assets (PUB) (AFD → Blob Storage)

```
Client
  |
  v
Azure Front Door
  |
  v
Azure Blob Storage
```

Used for public static content (PUB product), e.g. `publiclayers.<env>.public.intterra.io`.

**Important note about private containers:** a Blob container set to *private* cannot be fetched anonymously just because it’s behind AFD. You still need an authorization mechanism (SAS, user delegation SAS, AAD auth via an app/service, or a “public” container). AFD isn’t an auth proxy for Storage by itself.

---

## Certificates & Key Vault

- Managed certs: Azure‑managed
- Customer certs: stored in core Key Vault
- AFD uses a **User Assigned Managed Identity** with `Key Vault Secrets User`

Works for **Standard and Premium**.

---

## WAF behavior

- Optional
- Standard: custom rules only
- Premium: custom + managed rule sets

---

## Manual public DNS (intentionally outside Terraform)

Public DNS is managed manually for AFD custom domains to avoid accidental cutovers.

For each environment:

- Create/verify a DNS record that maps the public hostname to the AFD endpoint hostname (`*.azurefd.net`).
- Complete any required domain validation for AFD custom domains (TXT/CNAME steps Azure provides).

Example intent:

- `public.dev.public.intterra.io` → AFD endpoint hostname
- `publiclayers.dev.public.intterra.io` → AFD endpoint hostname

> Do **not** point AFD origins at `*.azurefd.net` or your public custom domains (that can create loops).  
> Origins should point at a stable origin target you control (App Gateway public IP/FQDN, or private origin DNS for Premium).

---

## Origin strategy (Standard vs Premium)

The same `afd-config` module supports two origin connectivity patterns, depending on AFD SKU and environment.

### Standard (nonprod typical)

- Origin is **publicly reachable** (e.g., AppGW public IP/FQDN or a dedicated public “origin” hostname)
- No Private Link required
- Used for dev/qa where you’re keeping AFD Standard

### Premium (prod typical)

- Origin can be reached via **Private Link**
- You typically point AFD origins at **private** targets (AppGW private frontend IP, private endpoints, etc.)
- Requires **Private DNS** so AFD can resolve origin hostnames inside the private network

---

## Private DNS (Premium) — recommended pattern

When moving prod to **AFD Premium with Private Link**, introduce a dedicated private origin DNS zone and keep it consistent across envs:

### Private DNS zone

```
origin.public.intterra.io
```

### Records (examples)

| Record | Target |
|---|---|
| `dev.origin.public.intterra.io` | AppGW private frontend IP (dev) |
| `qa.origin.public.intterra.io` | AppGW private frontend IP (qa) |
| `prod.origin.public.intterra.io` | AppGW private frontend IP (prod) |

### How it is used

- AFD **origin.host_name**: `<env>.origin.public.intterra.io`
- AFD **origin_host_header**: `<env>.origin.public.intterra.io`
- App Gateway listener: `<env>.origin.public.intterra.io` (private listener / private frontend)

This gives you a clean way to:
- run Standard in dev/qa using public origins
- run Premium in prod using private origins
- keep naming consistent and avoid reusing public hostnames for origin routing

> Naming note: use whatever subdomain convention you want (`dev.origin.public.intterra.io`, `public.dev.origin.public.intterra.io`, etc.). The key is that the hostname you use as the origin resolves privately and matches the certificate on the origin.

---

## Route uniqueness gotcha (why `/*` collisions happen)

AFD endpoints enforce uniqueness for the combination:

- Endpoint hostname (including default domain if linked)
- Path pattern (e.g., `/*`)
- Protocol (HTTP/HTTPS)

If you create multiple routes that all attach to the same endpoint and are effectively linked to the **default domain** as well, you can hit:

> “Hostname … Path pattern /* Protocol Https cannot be added … as this combination already exists …”

**Fix:** set `link_to_default_domain = false` on routes that should only apply to your custom domains, and ensure each route is attached to at least one `cdn_frontdoor_custom_domain_id`.

---

## Run order

1. Apply `shared-network` (creates AFD profile/endpoint baseline).
2. Apply `core` (if required for Key Vault).
3. Apply `afd-config` (creates routes/domains/WAF config).
4. Perform/verify manual public DNS.

---

## Stack layout

```
afd-config/
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  README.md
  env/
    dev.tfvars
    qa.tfvars
    uat.tfvars
    prod.tfvars
```

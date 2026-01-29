# Azure Front Door Config Stack (`afd-config`)

This stack manages **Azure Front Door (AFD) Standard/Premium runtime configuration** separately from the `shared-network` stack.

## Why this exists

`shared-network` is frequently redeployed to make network changes (NSGs, routes, DNS zones, etc.).  
AFD, however, is a high‑churn configuration surface (routes, custom domains, origins, WAF) where redeploying the entire network stack can create **unwanted drift** or accidental changes.

So we split responsibilities:

- **`shared-network`** = *AFD shell + foundational network resources*
- **`afd-config`** = *AFD runtime configuration*

This mirrors the existing pattern used for `app-gateway-config`.

---

## Ownership model

### `shared-network` owns (baseline / shell)

- `azurerm_cdn_frontdoor_profile` (AFD profile)
- `azurerm_cdn_frontdoor_endpoint` (AFD endpoint)
- DNS zones (but **not** the AFD records — those are manual; see below)
- Network primitives (VNets, subnets, NSGs, etc.)

**Required outputs from `shared-network`:**

`afd-config` expects `shared-network` remote state to provide:

- `outputs.afd.profile.id`
- `outputs.afd.profile.principal_id` *(only required if using Key Vault customer certs)*
- `outputs.afd.endpoint.id`
- `outputs.afd.endpoint.hostname`

Example output shape:

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

### `afd-config` owns (runtime config)

- Origin groups
- Origins (typically pointing at App Gateway frontend)
- Routes
- Rule sets / rules (optional)
- Custom domains + TLS bindings (managed cert or customer cert)
- Front Door WAF policy + security policy association (optional)
- **NO DNS records** (manual by design)

---

## Manual DNS (intentionally outside Terraform)

DNS is managed manually for AFD custom domains.

Reason: some environments use **apex zones** like `dev.public.intterra.io`, and Azure DNS cannot create a **CNAME at zone apex** (`@`). Alias behavior varies and is best handled as a controlled change.

### What you do manually

For each environment:

- Create/verify the DNS record that maps the public hostname to the AFD endpoint.
- Complete any required domain validation for the AFD custom domain.

Example intent:

- `dev.public.intterra.io` → AFD endpoint hostname (e.g., `xxxx.z01.azurefd.net`)
- `qa.public.intterra.io`  → AFD endpoint hostname

> **Do not** point the origin at `dev.public.intterra.io` (that can cause loops).  
> Origins should point at **App Gateway public IP/FQDN** (or another stable origin target), while `origin_host_header` carries the app hostname.

---

## App Gateway as origin

If AFD fronts App Gateway:

- `origin.host_name` should be **App Gateway public IP** or a **stable origin FQDN** you control (recommended).
- `origin.origin_host_header` should match what App Gateway expects for listener selection.

### Staged hostname migration

Today, App Gateway may expect:

- `public.dev.public.intterra.io`

Later, you may want it to expect:

- `dev.public.intterra.io`

This is handled by:
1. Add the **new hostname** to App Gateway listeners/certs first.
2. Flip AFD `origin_host_header` to the new hostname.
3. Remove the old hostname after validation.

---

## Remote state inputs

`afd-config` reads:

- `shared-network` remote state (for AFD shell IDs)
- `core` remote state (for Key Vault info when using customer certs)

Backend keys follow the existing convention:

- `shared-network/${product}/${plane_full}/terraform.tfstate`
- `core/${product}/${plane_code}/terraform.tfstate`

Where:
- `plane_full` is `nonprod` or `prod`
- `plane_code` is `np` or `pr`

---

## Run order

1. Apply `shared-network` (creates AFD profile/endpoint baseline).
2. Apply `core` (if required for Key Vault).
3. Apply `afd-config` (creates routes/domains/WAF config).
4. Perform/verify manual DNS.

---

## Safety checks built in

`afd-config` uses Terraform `check` blocks to fail fast if:
- the AFD shell outputs are missing from shared-network state
- customer certs are configured but Key Vault data can’t be resolved

---

## Files in this stack

Typical layout:

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

---

## Notes / gotchas

- AFD custom domains often require DNS propagation/validation; first apply may need a retry after DNS updates.
- If using customer certs from Key Vault, ensure the AFD profile identity has `Key Vault Secrets User` at the vault scope.

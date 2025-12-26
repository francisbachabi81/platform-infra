# App Gateway Config Stack

This stack manages **all runtime configuration** of a shared Azure Application Gateway (AGW) **without owning the gateway resource itself**.

It is designed to work alongside the `shared-network` stack, which creates the *base* Application Gateway, subnet, public IP, and User Assigned Managed Identity (UAMI).

---

## What this stack owns

This stack manages **only runtime configuration**, applied in-place using **AzAPI PATCH**:

- Backend address pools  
- Health probes  
- Backend HTTP settings  
- Frontend ports  
- HTTP and HTTPS listeners  
- Redirect configurations  
- Request routing rules  
- SSL certificates sourced from **Azure Key Vault**  
- Key Vault RBAC for the AGW UAMI (Key Vault Secrets User)

The Application Gateway **resource**, subnet, public IP, and UAMI are **owned by `shared-network`**.

---

## Why this split works

Terraform cannot safely split ownership of nested Application Gateway configuration blocks across multiple stacks using `azurerm_application_gateway`.

To avoid drift and resource contention:

- **`shared-network`**
  - Creates the Application Gateway shell
  - Sets `lifecycle.ignore_changes` on all runtime configuration blocks

- **`app-gateway-config` (this stack)**
  - Applies runtime configuration using **AzAPI PATCH**
  - Never recreates or replaces the gateway

✅ Result:  
Both stacks remain independent and can be deployed safely without fighting each other.

---

## Environment & plane resolution

This stack supports both **explicit plane selection** and **automatic plane derivation**:

- `env = dev | qa` → `plane = nonprod`
- `env = uat | prod` → `plane = prod`
- If `plane` is explicitly provided, it takes precedence

This logic ensures the correct remote state is read for each environment.

---

## Remote state dependencies

### Required: shared-network

This stack reads from `shared-network` to obtain:

- Application Gateway ID & name  
- Application Gateway UAMI (principal_id)

Expected outputs (names are auto-detected):

- `app_gateway` **or** `application_gateway`
- `appgw_uami` **or** `uami_appgw` **or** `uami`

Example in tfvars:

```hcl
shared_network_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/hrz/nonprod/terraform.tfstate"
}
```

---

### Required for SSL: core stack (Key Vault)

SSL certificates are sourced from **Azure Key Vault**, which is expected to be created by the `core` stack.

This stack reads:

- `core_key_vault.id`
- `core_key_vault.vault_uri`

Example in tfvars:

```hcl
core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/hrz/np/terraform.tfstate"
}
```

---

## SSL certificates (multiple supported)

Each HTTPS listener can have **its own certificate**.

Certificates are defined as a map, keyed by certificate name:

```hcl
ssl_certificates = {
  appgw-gateway-cert-horizon-dev = {
    secret_name    = "appgw-gateway-cert-horizon-dev"
    secret_version = null  # use latest
  }
}
```

### Alternative: explicit secret IDs (bypasses vault_uri lookup)

```hcl
ssl_certificates = {
  appgw-gateway-cert-horizon-dev = {
    key_vault_secret_id = "https://<kv>.vault.usgovcloudapi.net/secrets/appgw-gateway-cert-horizon-dev/<version>"
  }
}
```

> Using `secret_version = null` allows seamless certificate rotation.

---

## HTTPS listeners must reference existing certs

Each HTTPS listener **must reference a certificate key** defined in `ssl_certificates`:

```hcl
listeners = {
  listener-dev-https = {
    protocol             = "Https"
    frontend_port_name   = "feport-443"
    frontend_ip_configuration_name = "feip"
    host_name            = "dev.example.com"
    ssl_certificate_name = "appgw-gateway-cert-horizon-dev"
    require_sni          = true
  }
}
```

Guardrails will fail the plan if a listener references a non-existent cert.

---

## Deployment

```bash
cd stacks/app-gateway-config
terraform init
terraform plan  -var-file=tfvars/nonprod.hrz.tfvars
terraform apply -var-file=tfvars/nonprod.hrz.tfvars
```

Repeat per environment (`nonprod`, `prod`) using environment-specific tfvars.

---

## Adding a new app / listener

1. Add a backend pool
2. Add a probe
3. Add backend HTTP settings
4. Add frontend port (if needed)
5. Add HTTP/HTTPS listener
6. Add routing rule
7. (Optional) Add redirect configuration
8. (HTTPS) Add SSL certificate entry

All configuration is **environment-scoped via tfvars**.

---

## Certificate rotation

Recommended approach:

1. Upload a new version of the certificate to Key Vault (same secret name)
2. Keep `secret_version = null`
3. Run `terraform apply`

Application Gateway will pick up the latest version automatically.

---

## Ownership rules (important)

- ❌ Do **not** add runtime config back into `shared-network`
- ❌ Do **not** manage SSL certs directly on the AGW
- ✅ `shared-network` owns infrastructure
- ✅ `app-gateway-config` owns runtime behavior

---

## Summary

This stack provides:

- Safe multi-environment AGW runtime configuration
- Independent deployments per env
- Clean separation of concerns
- Zero drift with shared-network
- First-class Key Vault–backed SSL support

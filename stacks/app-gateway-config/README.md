# App Gateway Config Stack

This stack manages **all runtime configuration** of the shared Application Gateway (AGW):

- Backend pools
- Probes
- Backend HTTP settings
- Frontend ports
- Listeners (HTTP/HTTPS)
- Request routing rules
- SSL cert binding from Key Vault

The **Application Gateway resource itself** (plus subnet/public IP and its User Assigned Managed Identity) is created by **stacks/shared-network**.

## Why this split works

Terraform cannot safely split ownership of nested AGW configuration blocks across two stacks using `azurerm_application_gateway`.
To prevent drift:

- `shared-network` creates the AGW with **placeholder** config and sets `lifecycle.ignore_changes` on all runtime blocks.
- This stack uses **AzAPI PATCH** to update the AGW configuration in-place, while `shared-network` ignores those changes.

> Result: the stacks stay distinct, and `shared-network` runs do not fight `app-gateway-config`.

## Remote state inputs

This stack reads:

- `app_gateway` output from `shared-network` (AGW id/name)
- `appgw_uami` output from `shared-network` (UAMI principalId)
- `appgw_ssl_key_vault` output from `shared-network` (Key Vault id/URI), **or** `key_vault` from `core_state` if you wire that instead

In your `.tfvars`, set:

```hcl
shared_network_state = {
  resource_group_name  = "rg-STATE"
  storage_account_name = "stterraformstate"
  container_name       = "tfstate"
  key                  = "shared-network/dev.hrz.tfstate"
}

# Optional fallback (if shared-network does not output appgw_ssl_key_vault yet)
# core_state = {
#   resource_group_name  = "rg-STATE"
#   storage_account_name = "stterraformstate"
#   container_name       = "tfstate"
#   key                  = "platform-app/dev.hrz.tfstate"  # or your core stack
# }
```

## SSL certificate from Key Vault

This stack grants the AGW UAMI **Key Vault Secrets User** on the Key Vault scope (RBAC mode).

You can provide the SSL secret in one of two ways:

1) **Preferred:** full secret id (includes version)

```hcl
ssl_key_vault_secret_id = "https://<kv>.vault.azure.net/secrets/<name>/<version>"
ssl_certificate_name    = "kv-ssl"
```

2) Provide secret name (+ optional version) and the stack will build the URI using the Key Vault `vault_uri`:

```hcl
ssl_secret_name      = "agw-dev-cert"
ssl_secret_version   = null  # latest
ssl_certificate_name = "kv-ssl"
```

> If you omit `ssl_secret_version`, Key Vault will always serve the **latest** version. That’s convenient for rotation.

## Deploy

Example (dev):

```bash
cd stacks/app-gateway-config
terraform init
terraform plan  -var-file=tfvars/dev.tfvars
terraform apply -var-file=tfvars/dev.tfvars
```

Repeat for `qa.tfvars` and `prod.tfvars`.

## Add a backend + listener

1. Add/adjust a backend pool under `backend_pools`.
2. Add/update a probe under `probes`.
3. Add an http setting under `backend_http_settings`.
4. Add a listener under `listeners`.
5. Add a routing rule under `routing_rules`.

All are declared in `.tfvars` so per-environment overrides are simple.

## Certificate rotation

Recommended approach:

- Update the Key Vault secret with a **new version** (same secret name).
- Keep `ssl_secret_version = null` so AGW always pulls latest.
- Run `terraform apply` in this stack.

If you pin versions:

- Set `ssl_secret_version` to the new version and apply.

## Drift avoidance rules

- Do **not** add listeners/pools/rules back into `shared-network`.
- `shared-network` should only own: subnet, PIP, AGW shell, UAMI.
- `app-gateway-config` owns all runtime configuration and KV RBAC for SSL.


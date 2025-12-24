terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  env_norm   = var.env == null ? null : lower(var.env)
  plane_norm = var.plane == null ? null : lower(var.plane)

  env_effective = coalesce(
    local.env_norm,
    local.plane_norm == "nonprod" ? "dev" :
    local.plane_norm == "prod"    ? "prod" :
    "dev"
  )

  plane_effective = coalesce(
    local.plane_norm,
    contains(["dev", "qa"], local.env_effective) ? "nonprod" : "prod"
  )

  plane_full = local.plane_effective
  plane_code = local.plane_effective == "nonprod" ? "np" : "pr"

  activity_alert_location = "Global"
  ag_name_default         = "ag-obs-${var.product}-${local.env_effective}-${var.region}-01"
}

# -------------------------------------------------------------------
# Remote state
# -------------------------------------------------------------------
data "terraform_remote_state" "shared_network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.shared_network_state.resource_group_name
    storage_account_name = var.shared_network_state.storage_account_name
    container_name       = var.shared_network_state.container_name
    key                  = "shared-network/${var.product}/${local.plane_full}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "core" {
  count   = var.core_state == null ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = var.core_state.resource_group_name
    storage_account_name = var.core_state.storage_account_name
    container_name       = var.core_state.container_name
    key                  = "core/${var.product}/${local.plane_code}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  # ------------------------------------------------------------
  # Output-compat helpers
  # (Supports either old or new output names without hard failing)
  # ------------------------------------------------------------

  shared_outputs = try(data.terraform_remote_state.shared_network.outputs, {})

  # AppGW output might be "app_gateway" or "application_gateway" depending on the shared stack
  shared_appgw = coalesce(
    try(local.shared_outputs.app_gateway, null),
    try(local.shared_outputs.application_gateway, null),
    null
  )

  shared_uami = coalesce(
    try(local.shared_outputs.appgw_uami, null),
    try(local.shared_outputs.uami_appgw, null),
    try(local.shared_outputs.uami, null),
    null
  )

  # KV output name can vary

  shared_kv = lookup(local.shared_outputs, "appgw_ssl_key_vault", null)

  core_outputs = var.core_state == null ? {} : try(data.terraform_remote_state.core[0].outputs, {})
  core_kv = (
  can(local.core_outputs.core_key_vault) ? local.core_outputs.core_key_vault :
  can(local.core_outputs.key_vault)      ? local.core_outputs.key_vault :
  null
)

  # ------------------------------------------------------------
  # Safe "first non-null" selection (does NOT throw like coalesce())
  # ------------------------------------------------------------
  _kv_id_candidates  = compact([try(local.shared_kv.id, null), try(local.core_kv.id, null)])
  _kv_uri_candidates = compact([try(local.shared_kv.vault_uri, null), try(local.core_kv.vault_uri, null)])

  kv_id  = try(local._kv_id_candidates[0], null)
  kv_uri = try(local._kv_uri_candidates[0], null)

  agw_id   = try(local.shared_appgw.id, null)
  agw_name = try(local.shared_appgw.name, null)

  uami_principal_id = try(local.shared_uami.principal_id, null)

  agw_ready = local.agw_id != null && trimspace(local.agw_id) != ""

  # ------------------------------------------------------------
  # SSL secret id (either direct URI or build from vault_uri + name + version)
  # ------------------------------------------------------------
  ssl_secret_id = (
    var.ssl_key_vault_secret_id != null ? var.ssl_key_vault_secret_id :
    (
      var.ssl_secret_name != null && local.kv_uri != null ?
      (
        var.ssl_secret_version != null ?
        "${trim(local.kv_uri, "/")}/secrets/${var.ssl_secret_name}/${var.ssl_secret_version}" :
        "${trim(local.kv_uri, "/")}/secrets/${var.ssl_secret_name}"
      ) :
      null
    )
  )

  # "Do we intend to configure anything?" (helps us fail-fast if AGW isn't found)
  wants_config = (
    length(var.backend_pools) > 0 ||
    length(var.probes) > 0 ||
    length(var.backend_http_settings) > 0 ||
    length(var.frontend_ports) > 0 ||
    length(var.listeners) > 0 ||
    length(var.redirect_configurations) > 0 ||
    length(var.routing_rules) > 0 ||
    local.ssl_secret_id != null
  )

  # ------------------------------------------------------------
  # Build runtime config lists only when we have AGW id
  # ------------------------------------------------------------

  _backend_pools = local.agw_ready ? [
    for name, b in var.backend_pools : {
      name       = name
      properties = {
        backendAddresses = concat(
          [for ip in try(b.ip_addresses, []) : { ipAddress = ip }],
          [for fqdn in try(b.fqdns, [])      : { fqdn      = fqdn }]
        )
      }
    }
  ] : []

  _probes = local.agw_ready ? [
    for name, p in var.probes : {
      name       = name
      properties = {
        protocol           = p.protocol
        host               = try(p.host, null)
        path               = p.path
        interval           = try(p.interval, 30)
        timeout            = try(p.timeout, 30)
        unhealthyThreshold = try(p.unhealthy_threshold, 3)
        pickHostNameFromBackendHttpSettings = try(p.pick_host_name_from_backend_http_settings, false)
        match = {
          statusCodes = try(p.match_status_codes, ["200-399"])
        }
      }
    }
  ] : []

  _http_settings = local.agw_ready ? [
    for name, s in var.backend_http_settings : {
      name       = name
      properties = merge(
        {
          port                = s.port
          protocol            = s.protocol
          requestTimeout      = try(s.request_timeout, 20)
          cookieBasedAffinity = try(s.cookie_based_affinity, "Disabled")
          pickHostNameFromBackendAddress = try(s.pick_host_name_from_backend_address, false)
        },
        try(s.probe_name, null) != null ? {
          probe = { id = "${local.agw_id}/probes/${s.probe_name}" }
        } : {},
        try(s.host_name, null) != null ? {
          hostName = s.host_name
        } : {}
      )
    }
  ] : []

  _frontend_ports = local.agw_ready ? [
    for name, port in var.frontend_ports : {
      name       = name
      properties = { port = port }
    }
  ] : []

  _ssl_certs = (local.agw_ready && local.ssl_secret_id != null) ? [
    {
      name       = var.ssl_certificate_name
      properties = { keyVaultSecretId = local.ssl_secret_id }
    }
  ] : []

  _listeners = local.agw_ready ? [
    for name, l in (local.agw_ready ? var.listeners : {}) : {
      name       = name
      properties = merge(
        {
          protocol = l.protocol
          frontendIPConfiguration = { id = "${local.agw_id}/frontendIPConfigurations/${l.frontend_ip_configuration_name}" }
          frontendPort            = { id = "${local.agw_id}/frontendPorts/${l.frontend_port_name}" }
          hostName                = try(l.host_name, null)
          requireServerNameIndication = try(l.require_sni, false)
        },
        l.protocol == "Https" ? {
          sslCertificate = {
            id = "${local.agw_id}/sslCertificates/${coalesce(try(l.ssl_certificate_name, null), var.ssl_certificate_name)}"
          }
        } : {}
      )
    }
  ] : []

  _redirects = local.agw_ready ? [
    for name, r in var.redirect_configurations : {
      name       = name
      properties = {
        redirectType       = try(r.redirect_type, "Permanent")
        targetListener     = { id = "${local.agw_id}/httpListeners/${r.target_listener_name}" }
        includePath        = try(r.include_path, true)
        includeQueryString = try(r.include_query_string, true)
      }
    }
  ] : []

  _rules = local.agw_ready ? [
    for r in (local.agw_ready ? var.routing_rules : []) : {
      name       = r.name
      properties = merge(
        {
          ruleType     = try(r.rule_type, "Basic")
          priority     = r.priority
          httpListener = { id = "${local.agw_id}/httpListeners/${r.http_listener_name}" }
        },
        try(r.redirect_configuration_name, null) != null ? {
          redirectConfiguration = { id = "${local.agw_id}/redirectConfigurations/${r.redirect_configuration_name}" }
        } : {
          backendAddressPool  = { id = "${local.agw_id}/backendAddressPools/${r.backend_address_pool_name}" }
          backendHttpSettings = { id = "${local.agw_id}/backendHttpSettingsCollection/${r.backend_http_settings_name}" }
        }
      )
    }
  ] : []

  azapi_body = local.agw_ready ? {
    properties = {
      backendAddressPools           = local._backend_pools
      backendHttpSettingsCollection = local._http_settings
      probes                        = local._probes
      frontendPorts                 = local._frontend_ports
      sslCertificates               = local._ssl_certs
      httpListeners                 = local._listeners
      redirectConfigurations        = local._redirects
      requestRoutingRules           = local._rules
    }
  } : null
}

# -------------------------------------------------------------------
# Optional guardrails (recommended)
# Fail early if you intend to configure but AGW id isn't available.
# -------------------------------------------------------------------
check "shared_network_has_agw" {
  assert {
    condition = !(local.wants_config && !local.agw_ready)
    error_message = "app-gateway-config wants to apply runtime config, but shared-network remote state did not provide an Application Gateway id. Verify shared-network outputs and shared_network_state.key."
  }
}

check "kv_required_when_ssl_used" {
  assert {
    condition = !(local.ssl_secret_id != null && local.kv_id == null && var.ssl_key_vault_secret_id == null)
    error_message = "SSL secret name/version was provided but no Key Vault URI/id could be resolved from shared-network or core state. Provide ssl_key_vault_secret_id or ensure KV outputs exist."
  }
}

# -------------------------------------------------------------------
# RBAC: allow the AGW UAMI to GET secrets from the Key Vault (RBAC vault)
# -------------------------------------------------------------------
resource "azurerm_role_assignment" "uami_kv_secrets_user" {
  count                = (local.kv_id != null && local.uami_principal_id != null) ? 1 : 0
  scope                = local.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.uami_principal_id
}

# -------------------------------------------------------------------
# Application Gateway runtime configuration via AzAPI PATCH
# -------------------------------------------------------------------
resource "azapi_update_resource" "agw_config" {
  count       = local.agw_ready ? 1 : 0
  type        = "Microsoft.Network/applicationGateways@2023-09-01"
  resource_id = local.agw_id

  body = jsonencode(local.azapi_body)

  depends_on = [
    azurerm_role_assignment.uami_kv_secrets_user
  ]
}
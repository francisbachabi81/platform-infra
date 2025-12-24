terraform {
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

# -------------------------------------------------------------------
# Remote state
# -------------------------------------------------------------------
data "terraform_remote_state" "shared_network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.shared_network_state.resource_group_name
    storage_account_name = var.shared_network_state.storage_account_name
    container_name       = var.shared_network_state.container_name
    key                  = var.shared_network_state.key
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
    key                  = var.core_state.key
    use_azuread_auth     = true
  }
}

locals {
  shared_appgw = try(data.terraform_remote_state.shared_network.outputs.app_gateway, null)
  shared_uami  = try(data.terraform_remote_state.shared_network.outputs.appgw_uami, null)
  shared_kv    = try(data.terraform_remote_state.shared_network.outputs.appgw_ssl_key_vault, null)

  core_kv = var.core_state == null ? null : try(data.terraform_remote_state.core[0].outputs.core_key_vault, null)

  kv_id  = coalesce(try(local.shared_kv.id, null), try(local.core_kv.id, null))
  kv_uri = coalesce(try(local.shared_kv.vault_uri, null), try(local.core_kv.vault_uri, null))

  agw_id   = try(local.shared_appgw.id, null)
  agw_name = try(local.shared_appgw.name, null)

  uami_principal_id = try(local.shared_uami.principal_id, null)

  ssl_secret_id = (
    var.ssl_key_vault_secret_id != null ? var.ssl_key_vault_secret_id :
    (var.ssl_secret_name != null && local.kv_uri != null ? (
      var.ssl_secret_version != null ? "${trim(local.kv_uri, "/")}/secrets/${var.ssl_secret_name}/${var.ssl_secret_version}" :
      "${trim(local.kv_uri, "/")}/secrets/${var.ssl_secret_name}"
    ) : null)
  )

  _redirects = [
    for name, r in var.redirect_configurations : {
      name       = name
      properties = {
        redirectType       = try(r.redirect_type, "Permanent")
        targetListener     = { id = "${local.agw_id}/httpListeners/${r.target_listener_name}" }
        includePath        = try(r.include_path, true)
        includeQueryString = try(r.include_query_string, true)
      }
    }
  ]
}

# -------------------------------------------------------------------
# RBAC: allow the AGW UAMI to GET secrets from the Key Vault
# -------------------------------------------------------------------
# NOTE: For KV RBAC mode, this role is sufficient for reading secret versions.
resource "azurerm_role_assignment" "uami_kv_secrets_user" {
  count                = (local.kv_id != null && local.uami_principal_id != null) ? 1 : 0
  scope                = local.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.uami_principal_id
}

# -------------------------------------------------------------------
# Application Gateway runtime configuration via AzAPI PATCH
# This stack owns *all* runtime config (pools, listeners, rules, probes, ssl)
# -------------------------------------------------------------------
locals {
  # Build backend pools
  _backend_pools = [
    for name, b in var.backend_pools : {
      name       = name
      properties = {
        backendAddresses = concat(
          [for ip in try(b.ip_addresses, []) : { ipAddress = ip }],
          [for fqdn in try(b.fqdns, [])        : { fqdn      = fqdn }]
        )
      }
    }
  ]

  # Build probes
  _probes = [
    for name, p in var.probes : {
      name       = name
      properties = {
        protocol          = p.protocol
        host              = p.host
        path              = p.path
        interval          = p.interval
        timeout           = p.timeout
        unhealthyThreshold = p.unhealthy_threshold
        pickHostNameFromBackendHttpSettings = try(p.pick_host_name_from_backend_http_settings, false)
        match = {
          statusCodes = try(p.match_status_codes, ["200-399"])
        }
      }
    }
  ]

  # Build HTTP settings
    _http_settings = [
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
    ]

  # Build frontend ports
  _frontend_ports = [
    for name, port in var.frontend_ports : {
      name       = name
      properties = { port = port }
    }
  ]

  # SSL certificates
  _ssl_certs = local.ssl_secret_id == null ? [] : [
    {
      name       = var.ssl_certificate_name
      properties = { keyVaultSecretId = local.ssl_secret_id }
    }
  ]

  # Listeners
  _listeners = [
    for name, l in var.listeners : {
      name       = name
      properties = merge(
        {
          protocol = l.protocol
          frontendIPConfiguration = { id = "${local.agw_id}/frontendIPConfigurations/${l.frontend_ip_configuration_name}" }
          frontendPort            = { id = "${local.agw_id}/frontendPorts/${l.frontend_port_name}" }
          hostName = try(l.host_name, null)
          requireServerNameIndication = try(l.require_sni, false)
        },
        l.protocol == "Https" ? { sslCertificate = { id = "${local.agw_id}/sslCertificates/${coalesce(try(l.ssl_certificate_name, null), var.ssl_certificate_name)}" } } : {}
      )
    }
  ]

  # Request routing rules
    _rules = [
      for r in var.routing_rules : {
        name       = r.name
        properties = merge(
          {
            ruleType     = try(r.rule_type, "Basic")
            priority     = r.priority
            httpListener = { id = "${local.agw_id}/httpListeners/${r.http_listener_name}" }
          },
          # Redirect rule (no backend pool/settings)
          try(r.redirect_configuration_name, null) != null ? {
            redirectConfiguration = { id = "${local.agw_id}/redirectConfigurations/${r.redirect_configuration_name}" }
          } : {
            backendAddressPool  = { id = "${local.agw_id}/backendAddressPools/${r.backend_address_pool_name}" }
            backendHttpSettings = { id = "${local.agw_id}/backendHttpSettingsCollection/${r.backend_http_settings_name}" }
          }
        )
      }
    ]

    azapi_body = {
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
    }
}

resource "azapi_update_resource" "agw_config" {
  count       = local.agw_id == null ? 0 : 1
  type        = "Microsoft.Network/applicationGateways@2023-09-01"
  resource_id = local.agw_id

  body = jsonencode(local.azapi_body)

  depends_on = [
    azurerm_role_assignment.uami_kv_secrets_user
  ]
}

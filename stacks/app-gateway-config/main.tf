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

provider "azapi" {
  use_msi = false
  use_cli = true
}

locals {
  env_norm   = var.env   == null ? null : lower(trimspace(var.env))
  plane_norm = var.plane == null ? null : lower(trimspace(var.plane))

  env_is_nonprod = local.env_norm != null && contains(["dev", "qa"], local.env_norm)

  plane_full = coalesce(
    local.plane_norm,
    local.env_is_nonprod ? "nonprod" : "prod"
  )

  plane_code = local.plane_full == "nonprod" ? "np" : "pr"
}

# Remote state
data "terraform_remote_state" "shared_network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.shared_network_state.resource_group_name
    storage_account_name = var.shared_network_state.storage_account_name
    container_name       = var.shared_network_state.container_name
    key = "shared-network/${var.product}/${local.plane_full}/terraform.tfstate"
    use_azuread_auth = true
  }
}

data "terraform_remote_state" "core" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.core_state.resource_group_name
    storage_account_name = var.core_state.storage_account_name
    container_name       = var.core_state.container_name
    key = "core/${var.product}/${local.plane_code}/terraform.tfstate"
    use_azuread_auth = true
  }
}

locals {
  waf_policy_ids = {
    for k, p in azurerm_web_application_firewall_policy.this :
    k => p.id
  }

  shared_outputs = try(data.terraform_remote_state.shared_network.outputs, {})

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

  core_outputs   = try(data.terraform_remote_state.core.outputs, {})

  core_kv = (
    lookup(local.core_outputs, "core_key_vault", null) != null ? lookup(local.core_outputs, "core_key_vault", null) :
    lookup(local.core_outputs, "core_kvt", null)       != null ? lookup(local.core_outputs, "core_kvt", null) :
    null
  )

  kv_id  = try(local.core_kv.id, null)
  kv_uri = try(local.core_kv.vault_uri, null)

  agw_id   = try(local.shared_appgw.id, null)
  agw_name = try(local.shared_appgw.name, null)

  uami_principal_id = try(local.shared_uami.principal_id, null)

  agw_ready = local.agw_id != null && trimspace(local.agw_id) != ""

  shared_resource_groups = try(local.shared_outputs.resource_groups, {})
  hub_rg_name = try(local.shared_resource_groups.hub.name, null)

  # SSL: cert_name => Key Vault secret URI
  ssl_cert_secret_ids = {
    for cert_name, c in var.ssl_certificates :
    cert_name => (
      try(c.key_vault_secret_id, null) != null ? c.key_vault_secret_id :
      (
        try(c.secret_name, null) != null && local.kv_uri != null ?
        (
          try(c.secret_version, null) != null ?
          "${trim(local.kv_uri, "/")}/secrets/${c.secret_name}/${c.secret_version}" :
          "${trim(local.kv_uri, "/")}/secrets/${c.secret_name}"
        ) :
        null
      )
    )
  }

  ssl_secret_to_cert_name = {
    for sid in distinct([
      for _, sid in local.ssl_cert_secret_ids :
      sid if sid != null && trimspace(sid) != ""
    ]) :
    sid => (
      # first cert_name that maps to this sid
      [for cert_name, s in local.ssl_cert_secret_ids : cert_name if s == sid][0]
    )
  }

  # Build sslCertificates objects
  # _ssl_certs = [
  #   for cert_name, sid in local.ssl_cert_secret_ids : {
  #     name       = cert_name
  #     properties = { keyVaultSecretId = sid }
  #   }
  #   if local.agw_ready && sid != null && trimspace(sid) != ""
  # ]
  _ssl_certs = [
    for sid, cert_name in local.ssl_secret_to_cert_name : {
      name       = cert_name
      properties = { keyVaultSecretId = sid }
    }
    if local.agw_ready
  ]

  wants_config = (
    length(var.backend_pools) > 0 ||
    length(var.probes) > 0 ||
    length(var.backend_http_settings) > 0 ||
    length(var.frontend_ports) > 0 ||
    length(var.listeners) > 0 ||
    length(var.redirect_configurations) > 0 ||
    length(var.routing_rules) > 0 ||
    length(local._ssl_certs) > 0
  )

  # Runtime config lists
  _backend_pools = [
    for name, b in (local.agw_ready ? var.backend_pools : tomap({})) : {
      name       = name
      properties = {
        backendAddresses = concat(
          [for ip in try(b.ip_addresses, []) : { ipAddress = ip }],
          [for fqdn in try(b.fqdns, [])      : { fqdn      = fqdn }]
        )
      }
    }
  ]

  _probes = [
    for name, p in (local.agw_ready ? var.probes : tomap({})) : {
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
  ]

  _http_settings = [
    for name, s in (local.agw_ready ? var.backend_http_settings : tomap({})) : {
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

  _frontend_ports = [
    for name, port in (local.agw_ready ? var.frontend_ports : tomap({})) : {
      name       = name
      properties = { port = port }
    }
  ]

  _listeners = [
    for name, l in (local.agw_ready ? var.listeners : tomap({})) : {
      name = name
      properties = merge(
        {
          protocol                    = l.protocol
          frontendIPConfiguration      = { id = "${local.agw_id}/frontendIPConfigurations/${l.frontend_ip_configuration_name}" }
          frontendPort                = { id = "${local.agw_id}/frontendPorts/${l.frontend_port_name}" }
          hostName                    = try(l.host_name, null)
          requireServerNameIndication = try(l.require_sni, false)
        },
        try(l.waf_policy_key, null) != null ? {
          firewallPolicy = { id = local.waf_policy_ids[l.waf_policy_key] }
        } : {},
        l.protocol == "Https" ? {
          sslCertificate = {
            id = "${local.agw_id}/sslCertificates/${l.ssl_certificate_name}"
          }
        } : {}
      )
    }
  ]

  _redirects = [
    for name, r in (local.agw_ready ? var.redirect_configurations : tomap({})) : {
      name       = name
      properties = {
        redirectType       = try(r.redirect_type, "Permanent")
        targetListener     = { id = "${local.agw_id}/httpListeners/${r.target_listener_name}" }
        includePath        = try(r.include_path, true)
        includeQueryString = try(r.include_query_string, true)
      }
    }
  ]

  _rules = [
    for r in (local.agw_ready ? var.routing_rules : tolist([])) : {
      name = r.name
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
  ]

  azapi_body = local.agw_ready ? {
    properties = merge(
      length(local._backend_pools) > 0 ? { backendAddressPools = local._backend_pools } : {},
      length(local._http_settings) > 0 ? { backendHttpSettingsCollection = local._http_settings } : {},
      length(local._probes) > 0 ? { probes = local._probes } : {},
      length(local._frontend_ports) > 0 ? { frontendPorts = local._frontend_ports } : {},
      length(local._ssl_certs) > 0 ? { sslCertificates = local._ssl_certs } : {},
      length(local._listeners) > 0 ? { httpListeners = local._listeners } : {},
      length(local._redirects) > 0 ? { redirectConfigurations = local._redirects } : {},
      length(local._rules) > 0 ? { requestRoutingRules = local._rules } : {}
    )
  } : null

  ssl_cert_names_in_payload = toset([for c in local._ssl_certs : c.name])
  https_listeners_need_certs = {
    for name, l in var.listeners :
    name => l.ssl_certificate_name
    if try(l.protocol, "") == "Https"
  }
}

# Guardrails
check "shared_network_has_agw" {
  assert {
    condition     = !(local.wants_config && !local.agw_ready)
    error_message = "app-gateway-config wants to apply runtime config, but shared-network remote state did not provide an Application Gateway id. Verify shared-network outputs and shared_network_state.key."
  }
}

check "no_duplicate_ssl_cert_secrets" {
  assert {
    condition = length(values(local.ssl_secret_to_cert_name)) == length(distinct(values(local.ssl_cert_secret_ids)))
    error_message = "Duplicate SSL cert detected: multiple ssl_certificates entries resolve to the same Key Vault secret. Define the cert once and reuse its ssl_certificate_name across listeners (wildcard/shared), or use different secrets for distinct certs."
  }
}

check "core_kv_required_when_ssl_certs_defined" {
  assert {
    condition = !(
      length(var.ssl_certificates) > 0
      && (local.kv_uri == null || trimspace(local.kv_uri) == "")
      && anytrue([for _, c in var.ssl_certificates : try(c.key_vault_secret_id, null) == null])
    )
    error_message = "ssl_certificates provided but kv_uri could not be resolved from core state. Either fix core outputs (core_key_vault.vault_uri) or provide key_vault_secret_id for each ssl certificate."
  }
}

check "ssl_certificates_have_resolved_secret_ids" {
  assert {
    condition = !(
      length(var.ssl_certificates) > 0
      &&
      anytrue([
        for _, sid in local.ssl_cert_secret_ids :
        sid == null || trimspace(sid) == ""
      ])
    )
    error_message = "One or more ssl_certificates could not resolve a Key Vault secret ID (null/empty). Check key_vault_secret_id or secret_name/secret_version and kv_uri."
  }
}

check "https_listeners_reference_existing_ssl_certs" {
  assert {
    condition = !(
      length(local.https_listeners_need_certs) > 0
      &&
      anytrue([
        for _, cert_name in local.https_listeners_need_certs :
        cert_name == null || trimspace(cert_name) == "" || !contains(local.ssl_cert_names_in_payload, cert_name)
      ])
    )
    error_message = "One or more HTTPS listeners reference an ssl_certificate_name that is not present in ssl_certificates payload. Ensure var.listeners[*].ssl_certificate_name matches a key in var.ssl_certificates."
  }
}

# allow the AGW UAMI to GET secrets from the Key Vault (RBAC vault)
resource "azurerm_role_assignment" "uami_kv_secrets_user" {
  count                = (local.kv_id != null && local.uami_principal_id != null) ? 1 : 0
  scope                = local.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.uami_principal_id
}

# Application Gateway runtime configuration via AzAPI
resource "azapi_update_resource" "agw_config" {
  count       = local.agw_ready && local.wants_config ? 1 : 0
  type        = "Microsoft.Network/applicationGateways@2023-09-01"
  resource_id = local.agw_id

  body = jsonencode(local.azapi_body)

  depends_on = [
    azurerm_role_assignment.uami_kv_secrets_user
  ]
}

resource "azurerm_web_application_firewall_policy" "this" {
  for_each            = var.waf_policies
  name = "waf-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  resource_group_name = local.hub_rg_name
  location            = var.location

  policy_settings {
    enabled = true
    mode    = each.value.mode
  }

  managed_rules {
    managed_rule_set {
      type    = each.value.managed_rule_set.type
      version = each.value.managed_rule_set.version
    }
  }

  # Block non-VPN traffic when URI matches restricted paths
  custom_rules {
    name      = "blockNonvpnRestrictedPaths"
    priority  = 10
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator = "BeginsWith"
      match_values = each.value.restricted_paths
    }

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      match_values       = each.value.vpn_cidrs
      negation_condition = true # NOT in VPN range
    }
  }
}

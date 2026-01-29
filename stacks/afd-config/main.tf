provider "azurerm" {
  features {}
}

locals {
  env_norm   = var.env == null ? null : lower(trimspace(var.env))
  plane_norm = var.plane == null ? null : lower(trimspace(var.plane))

  env_is_np  = local.env_norm != null && contains(["dev", "qa"], local.env_norm)
  plane_full = coalesce(local.plane_norm, local.env_is_np ? "nonprod" : "prod")
  plane_code = local.plane_full == "nonprod" ? "np" : "pr"
}

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
  shared_outputs = try(data.terraform_remote_state.shared_network.outputs, {})
  core_outputs   = try(data.terraform_remote_state.core.outputs, {})

  frontdoor = try(local.shared_outputs.frontdoor, null)

  afd_profile_id    = try(local.frontdoor.profile_id, null)
  afd_endpoint_id   = try(local.frontdoor.endpoint_id, null)
  afd_profile_name  = try(local.frontdoor.profile_name, null)
  afd_endpoint_name = try(local.frontdoor.endpoint_name, null)
  afd_sku_name      = try(local.frontdoor.sku_name, null)

  afd_profile_principal_id = try(local.frontdoor.profile_principal_id, null)

  # Core KV lookup (match your existing output naming patterns)
  core_kv = (
    lookup(local.core_outputs, "core_key_vault", null) != null ? lookup(local.core_outputs, "core_key_vault", null) :
    lookup(local.core_outputs, "core_kvt", null) != null ? lookup(local.core_outputs, "core_kvt", null) :
    null
  )

  kv_id  = try(local.core_kv.id, null)
  kv_uri = try(local.core_kv.vault_uri, null)

  afd_ready = (
    local.afd_profile_id != null &&
    local.afd_endpoint_id != null
  )

  wants_config = (
    length(var.origin_groups) > 0 ||
    length(var.origins) > 0 ||
    length(var.routes) > 0 ||
    length(var.custom_domains) > 0 ||
    length(var.rule_sets) > 0 ||
    length(var.rules) > 0 ||
    var.waf_policy != null ||
    length(var.customer_certificates) > 0
  )
}

check "shared_network_has_afd_shell" {
  assert {
    condition     = !(local.wants_config && !local.afd_ready)
    error_message = "afd-config wants to apply config, but shared-network remote state did not provide afd.profile.id and afd.endpoint.id. Add shared-network outputs (afd object) and verify shared_network_state key."
  }
}

check "kv_required_when_customer_certs_defined" {
  assert {
    condition     = !(length(var.customer_certificates) > 0 && (local.kv_id == null || local.kv_uri == null))
    error_message = "customer_certificates provided but core Key Vault could not be resolved from core remote state."
  }
}

# Key Vault access for Front Door Profile Identity (for certs)
resource "azurerm_role_assignment" "afd_profile_kv_secrets_user" {
  count                = (local.kv_id != null && local.afd_profile_principal_id != null && length(var.customer_certificates) > 0) ? 1 : 0
  scope                = local.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.afd_profile_principal_id
}

# Customer certs -> AFD secrets -> Custom domains TLS binding
# Expect these to be *Key Vault certificate IDs* (recommended) or secret IDs if you standardize that way.
# For each certificate we create an azurerm_cdn_frontdoor_secret.
resource "azurerm_cdn_frontdoor_secret" "customer_cert" {
  for_each = (local.afd_ready ? var.customer_certificates : {})

  name                     = "afdsec-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_profile_id = local.afd_profile_id

  secret {
    customer_certificate {
      key_vault_certificate_id = each.value.key_vault_certificate_id
    }
  }

  depends_on = [azurerm_role_assignment.afd_profile_kv_secrets_user]
}

# Origin Groups
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  for_each = (local.afd_ready ? var.origin_groups : {})

  name                     = "og-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_profile_id = local.afd_profile_id

  load_balancing {
    additional_latency_in_milliseconds = try(each.value.additional_latency_in_ms, 0)
    sample_size                        = try(each.value.sample_size, 4)
    successful_samples_required        = try(each.value.successful_samples_required, 3)
  }

  # health_probe has required fields -> render explicitly with safe defaults
  health_probe {
    interval_in_seconds = try(each.value.probe.interval_in_seconds, 30)
    path                = try(each.value.probe.path, "/")
    protocol            = try(each.value.probe.protocol, "Https")
    request_type        = try(each.value.probe.request_type, "GET")
  }
}

# Origins
resource "azurerm_cdn_frontdoor_origin" "this" {
  for_each = (local.afd_ready ? var.origins : {})

  name                          = "or-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this[each.value.origin_group_key].id

  enabled                        = try(each.value.enabled, true)
  host_name                      = each.value.host_name
  http_port                      = try(each.value.http_port, 80)
  https_port                     = try(each.value.https_port, 443)
  origin_host_header             = try(each.value.origin_host_header, each.value.host_name)
  priority                       = try(each.value.priority, 1)
  weight                         = try(each.value.weight, 1000)
  certificate_name_check_enabled = each.value.certificate_name_check_enabled
}

# Rule sets
resource "azurerm_cdn_frontdoor_rule_set" "this" {
  for_each = (local.afd_ready ? var.rule_sets : {})

  name                     = "rs-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_profile_id = local.afd_profile_id
}

# NOTE: Rules are complex; keep this minimal skeleton.
# You can expand actions/conditions as you standardize your patterns.
resource "azurerm_cdn_frontdoor_rule" "this" {
  for_each = (local.afd_ready ? var.rules : {})

  name                      = each.key
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.this[each.value.rule_set_key].id
  order                     = each.value.order
  behavior_on_match         = try(each.value.behavior_on_match, "Continue")

  actions {
    # URL Redirect (destination_hostname is REQUIRED)
    dynamic "url_redirect_action" {
      for_each = try(each.value.url_redirect, null) == null ? [] : [each.value.url_redirect]
      content {
        redirect_type        = try(url_redirect_action.value.redirect_type, "Moved")
        destination_hostname = url_redirect_action.value.destination_hostname

        destination_path     = try(url_redirect_action.value.destination_path, null)
        query_string         = try(url_redirect_action.value.query_string, null)
        destination_fragment = try(url_redirect_action.value.destination_fragment, null)
      }
    }

    # Response headers
    dynamic "response_header_action" {
      for_each = try(each.value.response_headers, [])
      content {
        header_action = response_header_action.value.action
        header_name   = response_header_action.value.name
        value         = try(response_header_action.value.value, null)
      }
    }
  }

  conditions {
    # HTTP → HTTPS redirect condition
    dynamic "request_scheme_condition" {
      for_each = try(each.value.match_https_only, false) ? [1] : []
      content {
        operator         = "Equal"
        match_values     = ["HTTP"]
        negate_condition = false
      }
    }
  }
}

# Custom Domains
resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each = (local.afd_ready ? var.custom_domains : {})

  name                     = "cd-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_profile_id = local.afd_profile_id
  host_name                = each.value.host_name

  tls {
    certificate_type = each.value.certificate_type

    # For managed certs:
    minimum_tls_version = try(each.value.minimum_tls_version, "TLS12")

    # For customer certs:
    cdn_frontdoor_secret_id = (
      each.value.certificate_type == "CustomerCertificate"
      ? azurerm_cdn_frontdoor_secret.customer_cert[each.value.customer_certificate_key].id
      : null
    )
  }
}

# Routes
resource "azurerm_cdn_frontdoor_route" "this" {
  for_each = (local.afd_ready ? var.routes : {})

  name                          = "rt-${var.product}-${local.plane_code}-${var.region}-${each.key}-01"
  cdn_frontdoor_endpoint_id     = local.afd_endpoint_id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this[each.value.origin_group_key].id
  cdn_frontdoor_origin_ids      = [for ok in each.value.origin_keys : azurerm_cdn_frontdoor_origin.this[ok].id]

  enabled                = try(each.value.enabled, true)
  forwarding_protocol    = try(each.value.forwarding_protocol, "HttpsOnly")
  https_redirect_enabled = try(each.value.https_redirect_enabled, true)

  patterns_to_match   = try(each.value.patterns_to_match, ["/*"])
  supported_protocols = try(each.value.supported_protocols, ["Http", "Https"])

  # Attach domains (so the hostnames work)
  cdn_frontdoor_custom_domain_ids = [
    for dk in coalesce(try(each.value.custom_domain_keys, null), []) :
    azurerm_cdn_frontdoor_custom_domain.this[dk].id
  ]

  # Optional: attach rule sets
  cdn_frontdoor_rule_set_ids = [
    for rk in coalesce(try(each.value.rule_set_keys, null), []) :
    azurerm_cdn_frontdoor_rule_set.this[rk].id
  ]
}

locals {
  waf_name = substr(
    replace("wafafd${var.product}${local.plane_code}${var.region}01", "/[^0-9A-Za-z]/", ""),
    0,
    128
  )
}

# WAF (Front Door) + Security Policy association
resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  count = (local.afd_ready && var.waf_policy != null) ? 1 : 0

  name                = local.waf_name
  resource_group_name = var.waf_resource_group_name
  sku_name            = var.waf_policy.sku_name

  enabled = true
  mode    = var.waf_policy.mode

  managed_rule {
    type    = var.waf_policy.managed_rule.type
    version = var.waf_policy.managed_rule.version
    action  = "Block"
  }

  dynamic "custom_rule" {
    for_each = try(var.waf_policy.custom_rules, [])
    content {
      name     = custom_rule.value.name
      enabled  = true
      priority = custom_rule.value.priority
      type     = "MatchRule"
      action   = custom_rule.value.action

      match_condition {
        match_variable     = custom_rule.value.match_variable
        operator           = custom_rule.value.operator
        match_values       = custom_rule.value.match_values
        negation_condition = try(custom_rule.value.negation_condition, false)
        transforms         = try(custom_rule.value.transforms, [])
      }
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  count = (local.afd_ready && var.waf_policy != null) ? 1 : 0

  name                     = "sp-${var.product}-${local.plane_code}-${var.region}-01"
  cdn_frontdoor_profile_id = local.afd_profile_id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this[0].id

      association {
        dynamic "domain" {
          for_each = var.waf_policy.associated_custom_domain_keys
          content {
            cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.this[domain.value].id
          }
        }

        patterns_to_match = try(var.waf_policy.patterns_to_match, ["/*"])
      }
    }
  }
}
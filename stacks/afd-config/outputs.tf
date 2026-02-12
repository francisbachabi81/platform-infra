output "afd" {
  description = "AFD shell identifiers (profile/endpoint) resolved from shared-network remote state."
  value = {
    profile = {
      id       = local.afd_profile_id
      name     = local.afd_profile_name
      sku_name = local.afd_sku_name
    }
    endpoint = {
      id       = local.afd_endpoint_id
      name     = local.afd_endpoint_name
      hostname = try(local.frontdoor.endpoint_hostname, null)
    }
  }
}

output "afd_profile_identity" {
  description = "AFD profile identity info (what afd-config attempted to attach)."
  value = {
    needs_profile_identity = local.needs_profile_identity
    uai = local.needs_profile_identity ? {
      id                  = azurerm_user_assigned_identity.afd_kv[0].id
      name                = azurerm_user_assigned_identity.afd_kv[0].name
      principal_id        = azurerm_user_assigned_identity.afd_kv[0].principal_id
      client_id           = azurerm_user_assigned_identity.afd_kv[0].client_id
      resource_group_name = azurerm_user_assigned_identity.afd_kv[0].resource_group_name
    } : null
  }
}

output "origin_groups" {
  description = "Origin groups created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_origin_group.this : k => v.id }
}

output "origins" {
  description = "Origins created by afd-config (key => origin id), merged from pls+std."
  value = merge(
    { for k, v in azurerm_cdn_frontdoor_origin.pls : k => v.id },
    { for k, v in azurerm_cdn_frontdoor_origin.std : k => v.id }
  )
}

output "origins_pls" {
  description = "PLS origins only (key => origin id)."
  value       = { for k, v in azurerm_cdn_frontdoor_origin.pls : k => v.id }
}

output "origins_std" {
  description = "Standard origins only (key => origin id)."
  value       = { for k, v in azurerm_cdn_frontdoor_origin.std : k => v.id }
}

output "custom_domains" {
  description = "Custom domains created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_custom_domain.this : k => v.id }
}

output "routes" {
  description = "Front Door routes (key => route id)."
  value = merge(
    { for k, v in azurerm_cdn_frontdoor_route.this_std : k => v.id },
    { for k, v in azurerm_cdn_frontdoor_route.this_pls : k => v.id }
  )
}

output "waf_policy_id" {
  description = "Front Door WAF policy ID (if enabled)."
  value       = try(azurerm_cdn_frontdoor_firewall_policy.this[0].id, null)
}

output "security_policy_id" {
  description = "Front Door security policy ID (if enabled)."
  value       = try(azurerm_cdn_frontdoor_security_policy.this[0].id, null)
}

#Debug
# output "debug_shared_network_state_config" {
#   value = {
#     rg  = var.shared_network_state.resource_group_name
#     sa  = var.shared_network_state.storage_account_name
#     ctn = var.shared_network_state.container_name
#     key = "shared-network/${var.product}/${local.plane_full}/terraform.tfstate"
#   }
# }

# output "debug_core_state_config" {
#   value = {
#     rg  = var.core_state.resource_group_name
#     sa  = var.core_state.storage_account_name
#     ctn = var.core_state.container_name
#     key = "core/${var.product}/${local.plane_code}/terraform.tfstate"
#   }
# }

# output "debug_shared_outputs_keys" {
#   value = keys(local.shared_outputs)
# }

# output "debug_shared_frontdoor_object" {
#   value = local.frontdoor
# }

# output "debug_afd_ready" {
#   value = {
#     afd_profile_id    = local.afd_profile_id
#     afd_endpoint_id   = local.afd_endpoint_id
#     afd_profile_name  = local.afd_profile_name
#     afd_endpoint_name = local.afd_endpoint_name
#     afd_sku_name      = local.afd_sku_name
#     afd_ready         = local.afd_ready
#   }
# }

# output "debug_core_outputs_keys" {
#   value = keys(local.core_outputs)
# }

# output "debug_core_kv_object" {
#   value = local.core_kv
# }

# output "debug_kv" {
#   value = {
#     kv_id  = local.kv_id
#     kv_uri = local.kv_uri
#   }
# }

# output "debug_counts" {
#   value = {
#     needs_customer_certs   = local.needs_customer_certs
#     needs_profile_identity = local.needs_profile_identity
#     role_assignment_count  = (local.kv_id != null && local.needs_profile_identity) ? 1 : 0
#     uai_count              = local.needs_profile_identity ? 1 : 0
#     identity_patch_count   = local.needs_profile_identity ? 1 : 0
#   }
# }

output "afd" {
  description = "AFD shell identifiers from shared-network remote state (profile/endpoint)."
  value = {
    profile = {
      id           = local.afd_profile_id
      name         = local.afd_profile_name
      principal_id = local.afd_profile_principal_id
      sku_name     = local.afd_sku_name
    }
    endpoint = {
      id   = local.afd_endpoint_id
      name = local.afd_endpoint_name
      # hostname is not currently exposed by shared-network output; keep null-safe
      hostname = try(local.frontdoor.endpoint_hostname, null)
    }
  }
}

output "origin_groups" {
  description = "Origin groups created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_origin_group.this : k => v.id }
}

output "origins" {
  description = "Origins created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_origin.this : k => v.id }
}

output "custom_domains" {
  description = "Custom domains created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_custom_domain.this : k => v.id }
}

output "routes" {
  description = "Routes created by afd-config."
  value       = { for k, v in azurerm_cdn_frontdoor_route.this : k => v.id }
}

output "waf_policy_id" {
  description = "Front Door WAF policy ID (if enabled)."
  value       = try(azurerm_cdn_frontdoor_firewall_policy.this[0].id, null)
}

output "security_policy_id" {
  description = "Front Door security policy ID (if enabled)."
  value       = try(azurerm_cdn_frontdoor_security_policy.this[0].id, null)
}
########################################
# vnet consolidation for outputs
########################################
locals {
  # hub key matches your lane
  _hub_key = local.is_nonprod ? "nphub" : "prhub"

  # nonprod branch is only evaluated when local.is_nonprod is true, so [0] is safe
  _vnet_map_nonprod = local.is_nonprod ? {
    (local._hub_key) = { id = module.vnet_hub.id,       subnets = module.vnet_hub.subnet_ids }
    dev              = { id = module.vnet_dev[0].id,    subnets = module.vnet_dev[0].subnet_ids }
    qa               = { id = module.vnet_qa[0].id,     subnets = module.vnet_qa[0].subnet_ids }
  } : {}

  _vnet_map_prod = local.is_prod ? {
    (local._hub_key) = { id = module.vnet_hub.id,       subnets = module.vnet_hub.subnet_ids }
    prod             = { id = module.vnet_prod[0].id,   subnets = module.vnet_prod[0].subnet_ids }
    uat              = { id = module.vnet_uat[0].id,    subnets = module.vnet_uat[0].subnet_ids }
  } : {}

  vnet_map_consolidated = merge(local._vnet_map_nonprod, local._vnet_map_prod)

  # friendly-key projection for env stacks
  vnets_env_keyed = {
    for k, m in local.vnet_map_consolidated :
    (k == "nphub" ? "nonprod_hub" :
     k == "prhub" ? "prod_hub"    :
     k == "dev"   ? "dev_spoke"   :
     k == "qa"    ? "qa_spoke"    :
     k == "prod"  ? "prod_spoke"  :
     k == "uat"   ? "uat_spoke"   : k) => m
  }
}

# private dns
output "private_dns_zone_ids" {
  description = "map of private dns zone names to ids"
  value       = module.pdns.zone_ids
}

output "private_dns_zone_ids_by_name" {
  description = "same as private_dns_zone_ids but keyed by zone name"
  value       = module.pdns.zone_ids_by_name
}

# app gateway public ips (null if not created)
output "appgw_nonprod_public_ip" {
  description = "public ip of nonprod app gateway (null if not created)"
  value       = (local.is_nonprod && length(module.appgw) > 0) ? module.appgw[0].frontend_public_ip : null
}

output "appgw_prod_public_ip" {
  description = "public ip of prod app gateway (null if not created)"
  value       = (local.is_prod && length(module.appgw) > 0) ? module.appgw[0].frontend_public_ip : null
}

# vnets and subnets (works for either lane)
output "vnets" {
  description = "per-plane vnet ids and subnet ids, keyed for env stacks"
  value       = local.vnets_env_keyed
}

output "vnet_map" {
  description = "all vnet outputs keyed by consolidated module keys (nphub/dev/qa/prhub/prod/uat)"
  value       = local.vnet_map_consolidated
}

# debug helpers
output "debug_vnet_nonprod_hub_subnet_ids" {
  description = "subnet ids for the nonprod hub (empty when not created)"
  value       = try(local.vnet_map_consolidated["nphub"].subnets, {})
}

output "debug_vnet_dev_spoke_subnet_ids" {
  description = "subnet ids for the dev spoke (empty when not created)"
  value       = try(local.vnet_map_consolidated["dev"].subnets, {})
}

output "debug_vnet_qa_spoke_subnet_ids" {
  description = "subnet ids for the qa spoke (empty when not created)"
  value       = try(local.vnet_map_consolidated["qa"].subnets, {})
}

# public dns
output "public_name_servers" {
  description = "ns records per public zone for the active lane"
  value       = { for z, res in azurerm_dns_zone.public : z => res.name_servers }
}

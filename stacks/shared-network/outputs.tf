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
  value = {
    for k, m in module.vnet :
    (k == "nphub" ? "nonprod_hub" :
      k == "prhub" ? "prod_hub" :
      k == "dev" ? "dev_spoke" :
      k == "qa" ? "qa_spoke" :
      k == "prod" ? "prod_spoke" :
      k == "uat" ? "uat_spoke" : k) => {
      id      = m.id
      subnets = m.subnet_ids
    }
  }
}

output "vnet_map" {
  description = "all vnet outputs keyed by consolidated module keys (nphub/dev/qa/prhub/prod/uat)"
  value       = { for k, m in module.vnet : k => { id = m.id, subnets = m.subnet_ids } }
}

# debug helpers
output "debug_vnet_nonprod_hub_subnet_ids" {
  description = "subnet ids for the nonprod hub (empty when not created)"
  value       = try(module.vnet["nphub"].subnet_ids, {})
}

output "debug_vnet_dev_spoke_subnet_ids" {
  description = "subnet ids for the dev spoke (empty when not created)"
  value       = try(module.vnet["dev"].subnet_ids, {})
}

output "debug_vnet_qa_spoke_subnet_ids" {
  description = "subnet ids for the qa spoke (empty when not created)"
  value       = try(module.vnet["qa"].subnet_ids, {})
}

# public dns
output "public_name_servers" {
  description = "ns records per public zone for the active lane"
  value       = { for z, res in azurerm_dns_zone.public : z => res.name_servers }
}
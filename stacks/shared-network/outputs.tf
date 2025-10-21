output "meta" {
  value = {
    product        = var.product
    plane_code     = local.plane_code
    lane           = local.lane
    region_code    = var.region
    location       = var.location
    hub_subscription_id = var.hub_subscription_id
    hub_tenant_id       = var.hub_tenant_id
  }
}

output "features" {
  value = {
    is_nonprod             = local.is_nonprod
    is_prod                = local.is_prod
    create_vpn_gateway     = var.create_vpn_gateway
    create_vpng_public_ip  = var.create_vpng_public_ip
    create_app_gateway     = var.create_app_gateway
    appgw_public_ip_enabled = var.appgw_public_ip_enabled
    create_dns_resolver    = var.create_dns_resolver
    fd_create_frontdoor    = var.fd_create_frontdoor
    appgw_enabled          = local.appgw_enabled
  }
}

output "resource_groups" {
  value = {
    hub  = { name = (local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg), id = try(module.rg_hub.id, null) }
    dev  = try({ name = var.dev_spoke.rg,  id = module.rg_dev[0].id },  null)
    qa   = try({ name = var.qa_spoke.rg,   id = module.rg_qa[0].id },   null)
    prod = try({ name = var.prod_spoke.rg, id = module.rg_prod[0].id }, null)
    uat  = try({ name = var.uat_spoke.rg,  id = module.rg_uat[0].id },  null)
  }
}

# consolidated vnets + subnets for downstream stacks
locals {
  _hub_key = local.is_nonprod ? "nphub" : "prhub"

  _vnet_map_nonprod = local.is_nonprod ? {
    (local._hub_key) = { id = module.vnet_hub.id,     name = module.vnet_hub.name,     subnets = module.vnet_hub.subnet_ids }
    dev              = { id = module.vnet_dev[0].id,  name = module.vnet_dev[0].name,  subnets = module.vnet_dev[0].subnet_ids }
    qa               = { id = module.vnet_qa[0].id,   name = module.vnet_qa[0].name,   subnets = module.vnet_qa[0].subnet_ids }
  } : {}

  _vnet_map_prod = local.is_prod ? {
    (local._hub_key) = { id = module.vnet_hub.id,     name = module.vnet_hub.name,     subnets = module.vnet_hub.subnet_ids }
    prod             = { id = module.vnet_prod[0].id, name = module.vnet_prod[0].name, subnets = module.vnet_prod[0].subnet_ids }
    uat              = { id = module.vnet_uat[0].id,  name = module.vnet_uat[0].name,  subnets = module.vnet_uat[0].subnet_ids }
  } : {}

  vnet_map_consolidated = merge(local._vnet_map_nonprod, local._vnet_map_prod)

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

output "vnets" {
  value = local.vnets_env_keyed
}

output "vnet_map" {
  value = local.vnet_map_consolidated
}

output "private_dns" {
  value = {
    zone_ids         = try(module.pdns.zone_ids, {})
    zone_ids_by_name = try(module.pdns.zone_ids_by_name, {})
  }
}

output "vpn_gateway" {
  value = try({
    id              = module.vpng[0].id
    name            = module.vpng[0].name
    resource_group  = (local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg)
    public_ip_id    = try(azurerm_public_ip.vpngw[0].id, null)
    public_ip       = try(azurerm_public_ip.vpngw[0].ip_address, null)
    gateway_subnet_id = local.vpng_gateway_subnet_id
    sku             = var.vpn_sku
  }, null)
}

output "app_gateway" {
  value = try({
    id                 = module.appgw[0].id
    name               = module.appgw[0].name
    resource_group     = (local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg)
    public_ip          = try(module.appgw[0].frontend_public_ip, null)
    subnet_id          = local.appgw_subnet_id
    sku_name           = var.appgw_sku_name
    sku_tier           = var.appgw_sku_tier
    capacity           = var.appgw_capacity
    waf_policy_id      = try(module.waf[0].id, null)
    nsg_id             = try(azurerm_network_security_group.appgw_nsg[0].id, null)
  }, null)
}

output "dns_private_resolver" {
  value = try({
    id                 = module.dns_resolver[0].id
    name               = local.dnsr_name
    resource_group     = local.dnsr_hub_rg
    hub_vnet_id        = local.dnsr_hub_vnet_id
    inbound_subnet_id  = local.dnsr_inbound_sid
    outbound_subnet_id = local.dnsr_outbound_sid
    vnet_links         = local.dnsr_ruleset_links
  }, null)
}

output "public_dns" {
  value = {
    zones        = toset(var.public_dns_zones)
    name_servers = { for z, res in azurerm_dns_zone.public : z => res.name_servers }
  }
}

output "frontdoor" {
  value = try({
    profile_name  = local.fd_profile_name
    endpoint_name = local.fd_endpoint_name
    # IDs are module-defined; will be null if not exposed
    profile_id    = try(module.fd[0].profile_id, null)
    endpoint_id   = try(module.fd[0].endpoint_id, null)
    sku_name      = var.fd_sku_name
  }, null)
}

output "network_watcher" {
  value = {
    id   = try(azurerm_network_watcher.hub.id, null)
    name = try(azurerm_network_watcher.hub.name, null)
    rg   = (local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg)
  }
}

# convenience projections for common subnet lookups
output "subnet_ids_by_env" {
  value = {
    hub   = try(module.vnet_hub.subnet_ids, {})
    dev   = try(module.vnet_dev[0].subnet_ids, {})
    qa    = try(module.vnet_qa[0].subnet_ids, {})
    prod  = try(module.vnet_prod[0].subnet_ids, {})
    uat   = try(module.vnet_uat[0].subnet_ids, {})
  }
}

# small helpers (null-safe for lane)
output "appgw_public_ip" {
  value = (
    local.appgw_enabled && var.appgw_public_ip_enabled && try(length(module.appgw) > 0, false)
  ) ? try(module.appgw[0].frontend_public_ip, null) : null
}

output "hub_ids" {
  value = {
    rg_id   = try(module.rg_hub.id, null)
    vnet_id = try(module.vnet_hub.id, null)
  }
}
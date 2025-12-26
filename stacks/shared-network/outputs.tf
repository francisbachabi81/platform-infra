output "meta" {
  value = {
    product            = var.product
    plane_code         = local.plane_code
    lane               = local.lane
    region_code        = var.region
    location           = var.location
    hub_subscription_id = var.hub_subscription_id
    hub_tenant_id       = var.hub_tenant_id
  }
}

output "features" {
  value = {
    is_nonprod              = local.is_nonprod
    is_prod                 = local.is_prod
    create_vpn_gateway      = var.create_vpn_gateway
    create_vpng_public_ip   = var.create_vpng_public_ip
    create_app_gateway      = var.create_app_gateway
    appgw_public_ip_enabled = var.appgw_public_ip_enabled
    create_dns_resolver     = var.create_dns_resolver
    fd_create_frontdoor     = var.fd_create_frontdoor
    appgw_enabled           = local.appgw_enabled
  }
}

output "resource_groups" {
  value = {
    hub  = { name = local.hub_rg_name,  id = try(module.rg_hub.id, null) }
    dev  = try({ name = local.dev_rg_name,  id = module.rg_dev[0].id },  null)
    qa   = try({ name = local.qa_rg_name,   id = module.rg_qa[0].id },   null)
    prod = try({ name = local.prod_rg_name, id = module.rg_prod[0].id }, null)
    uat  = try({ name = local.uat_rg_name,  id = module.rg_uat[0].id },  null)
    dev_core  = try({ name = local.dev_rg_name_core,  id = module.rg_dev_core[0].id },  null)
    qa_core   = try({ name = local.qa_rg_name_core,   id = module.rg_qa_core[0].id },   null)
    prod_core = try({ name = local.prod_rg_name_core, id = module.rg_prod_core[0].id }, null)
    uat_core  = try({ name = local.uat_rg_name_core,  id = module.rg_uat_core[0].id },  null)
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
    id               = module.vpng[0].id
    name             = module.vpng[0].name
    resource_group   = local.vpng_hub_rg
    public_ip_id     = try(azurerm_public_ip.vpngw[0].id, null)
    public_ip        = try(azurerm_public_ip.vpngw[0].ip_address, null)
    gateway_subnet_id = local.vpng_gateway_subnet_id
    sku              = var.vpn_sku
  }, null)
}

output "app_gateway" {
  value = try({
    id             = azurerm_application_gateway.appgw[0].id
    name           = azurerm_application_gateway.appgw[0].name
    resource_group = local.appgw_hub_rg
    public_ip      = try(azurerm_public_ip.appgw[0].ip_address, null)

    sku_name       = var.appgw_sku_name
    sku_tier       = var.appgw_sku_tier
    capacity       = var.appgw_capacity

    waf_policy_id  = try(module.waf[0].id, null)
    nsg_id         = try(azurerm_network_security_group.appgw_nsg[0].id, null)

    subnet_id      = local.appgw_subnet_id

    frontends = {
      public = {
        enabled      = local.appgw_enabled && var.appgw_public_ip_enabled
        feip_name    = "feip-public"
        public_ip_id = try(azurerm_public_ip.appgw[0].id, null)
        public_ip    = (local.appgw_enabled && var.appgw_public_ip_enabled) ? try(azurerm_public_ip.appgw[0].ip_address, null) : null
      }

      private = {
        enabled   = local.appgw_enabled
        feip_name = "feip-private"
        private_ip = try(var.appgw_private_frontend_ip, null)
      }
    }
  }, null)
}

output "appgw_uami" {
  description = "User-assigned managed identity for Application Gateway (for Key Vault access)."
  value = try({
    id           = azurerm_user_assigned_identity.appgw[0].id
    name         = azurerm_user_assigned_identity.appgw[0].name
    principal_id = azurerm_user_assigned_identity.appgw[0].principal_id
    client_id    = azurerm_user_assigned_identity.appgw[0].client_id
  }, null)
}

output "appgw_public_ip_id" {
  description = "Public IP resource id used by Application Gateway (null for private-only)."
  value       = try(azurerm_public_ip.appgw[0].id, null)
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

output "network_watchers" {
  value = {
    hub = try({
      id   = azurerm_network_watcher.hub[0].id
      name = azurerm_network_watcher.hub[0].name
      rg   = local.hub_rg_name
    }, null)

    dev = try({
      id   = azurerm_network_watcher.dev[0].id
      name = azurerm_network_watcher.dev[0].name
      rg   = local.dev_rg_name
    }, null)

    qa = try({
      id   = azurerm_network_watcher.qa[0].id
      name = azurerm_network_watcher.qa[0].name
      rg   = local.qa_rg_name
    }, null)

    prod = try({
      id   = azurerm_network_watcher.prod[0].id
      name = azurerm_network_watcher.prod[0].name
      rg   = local.prod_rg_name
    }, null)

    uat = try({
      id   = azurerm_network_watcher.uat[0].id
      name = azurerm_network_watcher.uat[0].name
      rg   = local.uat_rg_name
    }, null)
  }
}

output "subnet_ids_by_env" {
  value = {
    hub  = try(module.vnet_hub.subnet_ids, {})
    dev  = try(module.vnet_dev[0].subnet_ids, {})
    qa   = try(module.vnet_qa[0].subnet_ids, {})
    prod = try(module.vnet_prod[0].subnet_ids, {})
    uat  = try(module.vnet_uat[0].subnet_ids, {})
  }
}

output "appgw_public_ip" {
  value = (local.appgw_enabled && var.appgw_public_ip_enabled) ? try(azurerm_public_ip.appgw[0].ip_address, null) : null
}

output "hub_ids" {
  value = {
    rg_id   = try(module.rg_hub.id, null)
    vnet_id = try(module.vnet_hub.id, null)
  }
}

output "nsg_ids_by_env" {
  value = {
    hub  = try(module.nsg_hub.nsg_ids, {})
    dev  = try(module.nsg_dev[0].nsg_ids, {})
    qa   = try(module.nsg_qa[0].nsg_ids, {})
    prod = try(module.nsg_prod[0].nsg_ids, {})
    uat  = try(module.nsg_uat[0].nsg_ids, {})
  }
}

output "vnet_ids_by_env" {
  value = {
    hub  = compact([try(local.vnet_map_consolidated[local._hub_key].id, null)])
    dev  = compact([try(local.vnet_map_consolidated["dev"].id, null)])
    qa   = compact([try(local.vnet_map_consolidated["qa"].id, null)])
    prod = compact([try(local.vnet_map_consolidated["prod"].id, null)])
    uat  = compact([try(local.vnet_map_consolidated["uat"].id, null)])
  }
}

# output "vnet_ids_by_env" {
#   value = {
#     hub  = try(local.vnet_map_consolidated[local._hub_key].id, null)
#     dev  = try(local.vnet_map_consolidated["dev"].id, null)
#     qa   = try(local.vnet_map_consolidated["qa"].id, null)
#     prod = try(local.vnet_map_consolidated["prod"].id, null)
#     uat  = try(local.vnet_map_consolidated["uat"].id, null)
#   }
# }

output "vnet_ids" {
  value = {
    hub  = module.vnet_hub.id
    dev  = try(module.vnet_dev[0].id, null)
    qa   = try(module.vnet_qa[0].id, null)
    uat  = try(module.vnet_uat[0].id, null)
    prod = try(module.vnet_prod[0].id, null)
  }
}
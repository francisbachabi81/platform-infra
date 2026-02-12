locals {
  appgw_pl_targets_struct = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] }
    if can(regex("appgw-pl$", k))
  }

  appgw_pl_hub = { for k, v in local.appgw_pl_targets_struct : k => v if can(regex("^hub-", k)) }

  appgw_pl_targets_hub = var.appgw_private_link_enabled ? local.appgw_pl_hub : {}

  appgw_pl_priority_band_base = 1200

  appgw_pl_rule_priority = {
    allow_afdb_https = local.appgw_pl_priority_band_base + 0 # 1200
    allow_afdb_http  = local.appgw_pl_priority_band_base + 1 # 1201

    allow_azure_lb  = local.appgw_pl_priority_band_base + 10 # 1210
    allow_vnet_vnet = local.appgw_pl_priority_band_base + 20 # 1220

    deny_other_https = local.appgw_pl_priority_band_base + 90 # 1290
    deny_other_http  = local.appgw_pl_priority_band_base + 91 # 1291
  }

  appgw_pl_rule_name = {
    allow_afdb_https = "allow-appgwpl-ingress-afd-backend-https"
    allow_afdb_http  = "allow-appgwpl-ingress-afd-backend-http"

    allow_azure_lb  = "allow-appgwpl-ingress-azure-loadbalancer"
    allow_vnet_vnet = "allow-appgwpl-ingress-vnet-to-vnet"

    deny_other_https = "deny-appgwpl-ingress-any-https"
    deny_other_http  = "deny-appgwpl-ingress-any-http"
  }
}

# AppGW PrivateLink NSG Rules - HUB
resource "azurerm_network_security_rule" "appgwpl_allow_https_from_afd_backend_hub" {
  for_each                    = local.appgw_pl_targets_hub
  name                        = local.appgw_pl_rule_name.allow_afdb_https
  priority                    = local.appgw_pl_rule_priority.allow_afdb_https
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}

resource "azurerm_network_security_rule" "appgwpl_allow_http_from_afd_backend_hub" {
  for_each                    = local.appgw_pl_targets_hub
  name                        = local.appgw_pl_rule_name.allow_afdb_http
  priority                    = local.appgw_pl_rule_priority.allow_afdb_http
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}

resource "azurerm_network_security_rule" "appgwpl_allow_azure_lb_hub" {
  for_each                    = local.appgw_pl_targets_hub
  name                        = local.appgw_pl_rule_name.allow_azure_lb
  priority                    = local.appgw_pl_rule_priority.allow_azure_lb
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}

resource "azurerm_network_security_rule" "appgwpl_deny_https_other_hub" {
  for_each                    = local.appgw_pl_targets_hub
  name                        = local.appgw_pl_rule_name.deny_other_https
  priority                    = local.appgw_pl_rule_priority.deny_other_https
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}

resource "azurerm_network_security_rule" "appgwpl_deny_http_other_hub" {
  for_each                    = local.appgw_pl_targets_hub
  name                        = local.appgw_pl_rule_name.deny_other_http
  priority                    = local.appgw_pl_rule_priority.deny_other_http
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}

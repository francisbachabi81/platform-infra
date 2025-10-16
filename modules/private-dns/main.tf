resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# locals {
#   link_keyed = {
#     for l in var.vnet_links :
#     "${l.name}-${substr(md5(l.zone),0,4)}-${substr(md5(l.vnet_id),0,4)}" => l
#   }
# }

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  # for_each                  = { for l in var.vnet_links : l.name => l }
  # for_each                  = local.link_keyed
  for_each                  = var.vnet_links
  name                      = each.value.name
  resource_group_name       = var.resource_group_name
  private_dns_zone_name     = each.value.zone
  virtual_network_id        = each.value.vnet_id
  registration_enabled      = false

  # make links wait for the zone resources
  depends_on = [
    azurerm_private_dns_zone.zones
  ]
}
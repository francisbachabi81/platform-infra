resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each                  = var.vnet_links
  name                      = each.value.name
  resource_group_name       = var.resource_group_name
  private_dns_zone_name     = each.value.zone
  virtual_network_id        = each.value.vnet_id
  registration_enabled      = false

  depends_on = [
    azurerm_private_dns_zone.zones
  ]
}
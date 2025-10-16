resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnet_nsgs
  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each                  = var.subnet_nsgs
  subnet_id                 = each.value.subnet_id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}
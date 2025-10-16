resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnet_nsgs
  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# locals {
#   # Only associate when a subnet_id is present
#   assoc_map = {
#     for k, v in var.subnet_nsgs :
#     k => v
#     if try(v.subnet_id, null) != null && v.subnet_id != ""
#   }
# }

locals {
  assoc_map = {
    for k, v in var.subnet_nsgs :
    k => {
      subnet_id = try(v.subnet_id, null)
      nsg_id    = azurerm_network_security_group.nsg[k].id
    }
    if try(v.subnet_id, null) != null
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each                  = local.assoc_map
  subnet_id                 = each.value.subnet_id
  network_security_group_id = each.value.nsg_id
}
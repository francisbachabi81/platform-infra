output "id" {
  value       = azurerm_virtual_network.this.id
  description = "VNet resource ID."
}

output "name" {
  value       = azurerm_virtual_network.this.name
  description = "VNet name."
}

output "resource_group_name" {
  value       = azurerm_virtual_network.this.resource_group_name
  description = "Resource group of the VNet."
}

output "address_space" {
  value       = azurerm_virtual_network.this.address_space
  description = "VNet address space."
}

output "subnet_ids" {
  value       = { for k, s in azurerm_subnet.subnets : k => s.id }
  description = "Map of subnet name => subnet ID."
}

output "subnet_names" {
  value       = keys(azurerm_subnet.subnets)
  description = "List of subnet names."
}

output "subnet_pls_policies_enabled" {
  value = {
    for k, s in var.subnets :
    k => try(s.private_link_service_network_policies_enabled, true)
  }
}
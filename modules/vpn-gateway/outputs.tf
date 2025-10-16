output "id" {
  description = "Virtual Network Gateway ID."
  value       = azurerm_virtual_network_gateway.this.id
}

output "name" {
  description = "Virtual Network Gateway name."
  value       = azurerm_virtual_network_gateway.this.name
}

output "public_ip_id" {
  description = "Associated Public IP resource ID."
  value       = azurerm_virtual_network_gateway.this.ip_configuration[0].public_ip_address_id
}

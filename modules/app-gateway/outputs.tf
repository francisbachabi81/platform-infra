output "id" {
  value = azurerm_application_gateway.agw.id
}

output "frontend_public_ip" {
  value = try(azurerm_public_ip.pip[0].ip_address, null)
}

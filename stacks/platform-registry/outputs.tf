output "resource_group_name" {
  description = "Name of the resource group that contains the ACR."
  value       = azurerm_resource_group.rg.name
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = module.acr.name
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = module.acr.id
}

output "acr_login_server" {
  description = "Login server (FQDN) of the Azure Container Registry."
  value       = module.acr.login_server
}
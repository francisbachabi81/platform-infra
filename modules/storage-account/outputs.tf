output "id" {
  value = azurerm_storage_account.sa.id
}

output "name" {
  value = azurerm_storage_account.sa.name
}

output "primary_access_key" {
  value     = azurerm_storage_account.sa.primary_access_key
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_storage_account.sa.resource_group_name
}

output "location" {
  value = azurerm_storage_account.sa.location
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.sa.primary_blob_endpoint
}

output "primary_file_endpoint" {
  value = azurerm_storage_account.sa.primary_file_endpoint
}

output "blob_private_endpoint_id" {
  value = try(azurerm_private_endpoint.blob.id, null)
}

output "file_private_endpoint_id" {
  value = try(azurerm_private_endpoint.file.id, null)
}

# output "cmk_identity_id" {
#   value = try(azurerm_user_assigned_identity.cmk[0].id, null)
# }

# output "cmk_identity_principal_id" {
#   value = try(azurerm_user_assigned_identity.cmk[0].principal_id, null)
# }

output "network_public_access_enabled" {
  value = azurerm_storage_account.sa.public_network_access_enabled
}

output "network_default_action" {
  value = try(azurerm_storage_account.sa.network_rules[0].default_action, null)
}

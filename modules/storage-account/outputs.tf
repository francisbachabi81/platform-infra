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

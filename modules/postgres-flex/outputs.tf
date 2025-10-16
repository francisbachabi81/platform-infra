output "id" {
  value       = azurerm_postgresql_flexible_server.pg.id
  description = "Server resource ID."
}

output "name" {
  value       = azurerm_postgresql_flexible_server.pg.name
  description = "Server name (auto-suffixed when replica_enabled & auto_replica_name)."
}

output "fqdn" {
  value       = azurerm_postgresql_flexible_server.pg.fqdn
  description = "Server FQDN."
}

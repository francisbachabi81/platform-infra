# output "id" {
#   description = "Cluster resource ID."
#   value       = azurerm_cosmosdb_postgresql_cluster.this.id
# }

# output "name" {
#   description = "Cluster name."
#   value       = azurerm_cosmosdb_postgresql_cluster.this.name
# }

output "id"   { value = local.cluster_id }
output "name" { value = local.cluster_name }

output "private_endpoint_id" {
  description = "Coordinator Private Endpoint ID (if created)."
  value       = try(azurerm_private_endpoint.pe[0].id, null)
}

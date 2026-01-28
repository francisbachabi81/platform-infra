output "id" {
  value       = azapi_resource.cluster.id
  description = "Elastic cluster resource ID."
}

output "name" {
  value       = azapi_resource.cluster.name
  description = "Elastic cluster name."
}

output "resource_group_name" {
  value       = var.resource_group_name
  description = "Resource group name."
}

# Best-effort: AzAPI returns a JSON response; properties vary by API version.
# Expose the full response so callers can pick what they need.
output "response" {
  value       = azapi_resource.cluster.output
  description = "Full AzAPI response (JSON)."
}

output "private_endpoint_id" {
  value       = try(azurerm_private_endpoint.pe[0].id, null)
  description = "Private Endpoint ID (if created)."
}

output "private_endpoint_ip_addresses" {
  value       = try(azurerm_private_endpoint.pe[0].private_service_connection[0].private_ip_address, null)
  description = "Private endpoint IP (if created)."
}
output "id" {
  description = "Service Bus Namespace ID."
  value       = azurerm_servicebus_namespace.this.id
}

output "name" {
  description = "Service Bus Namespace name."
  value       = azurerm_servicebus_namespace.this.name
}

output "fqdn" {
  description = "Namespace endpoint FQDN."
  value       = "sb://${azurerm_servicebus_namespace.this.name}.servicebus.windows.net/"
}

output "pe_id" {
  description = "Private Endpoint ID (null when not created)."
  value       = try(azurerm_private_endpoint.sb[0].id, null)
}

output "manage_policy_id" {
  description = "Namespace-level SAS policy ID (Manage)."
  value       = try(azurerm_servicebus_namespace_authorization_rule.manage[0].id, null)
}

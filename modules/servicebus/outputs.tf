locals {
  sb_dns_suffix = lower(var.cloud) == "usgovernment" ? "servicebus.usgovcloudapi.net" : "servicebus.windows.net"
}

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
  value       = "sb://${azurerm_servicebus_namespace.this.name}.${local.sb_dns_suffix}/"
}

output "pe_id" {
  description = "Private Endpoint ID (null when not created)."
  value       = try(azurerm_private_endpoint.sb[0].id, null)
}

# return all auth rules as a map (keyed by your input map keys)
output "authorization_rule_ids" {
  description = "Namespace-level authorization rule IDs keyed by authorization_rules map key."
  value       = { for k, r in azurerm_servicebus_namespace_authorization_rule.auth : k => r.id }
}

output "id" {
  description = "Private DNS Resolver ID."
  value       = azurerm_private_dns_resolver.this.id
}

output "inbound_endpoint_id" {
  description = "Inbound endpoint ID."
  value       = azurerm_private_dns_resolver_inbound_endpoint.inbound.id
}

output "outbound_endpoint_id" {
  description = "Outbound endpoint ID."
  value       = azurerm_private_dns_resolver_outbound_endpoint.outbound.id
}

output "ruleset_id" {
  description = "Forwarding ruleset ID (null when no rules)."
  value       = try(azurerm_private_dns_resolver_dns_forwarding_ruleset.rs[0].id, null)
}

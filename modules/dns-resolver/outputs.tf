output "id" {
  description = "Private DNS Resolver ID."
  value       = azurerm_private_dns_resolver.this.id
}

output "inbound_endpoint_id" {
  description = "Inbound endpoint ID."
  value       = azurerm_private_dns_resolver_inbound_endpoint.inbound.id
}

output "outbound_endpoint_id" {
  description = "ID of the outbound endpoint (if created)"
  value       = try(azurerm_private_dns_resolver_outbound_endpoint.outbound[0].id, null)
}

output "ruleset_id" {
  description = "ID of the DNS forwarding ruleset (if created)"
  value       = try(azurerm_private_dns_resolver_dns_forwarding_ruleset.rs[0].id, null)
}
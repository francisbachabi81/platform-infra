output "zone_ids" {
  description = "Map of zone name => zone resource ID."
  value       = { for name, z in azurerm_private_dns_zone.zones : name => z.id }
}

output "zone_ids_by_name" {
  description = "Same as zone_ids (kept for consumer parity)."
  value       = { for z in azurerm_private_dns_zone.zones : z.name => z.id }
}

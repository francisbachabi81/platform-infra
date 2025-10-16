output "profile_id" {
  value       = azurerm_cdn_frontdoor_profile.this.id
  description = "Front Door profile resource ID."
}

output "profile_name" {
  value       = azurerm_cdn_frontdoor_profile.this.name
  description = "Front Door profile name."
}

output "endpoint_id" {
  value       = azurerm_cdn_frontdoor_endpoint.this.id
  description = "Front Door endpoint resource ID."
}

output "endpoint_name" {
  value       = azurerm_cdn_frontdoor_endpoint.this.name
  description = "Front Door endpoint name."
}

output "endpoint_hostname" {
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
  description = "Front Door endpoint hostname."
}

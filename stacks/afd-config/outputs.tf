# shared-network/outputs.tf (add these)

output "afd" {
  value = {
    profile = {
      id           = azurerm_cdn_frontdoor_profile.this.id
      name         = azurerm_cdn_frontdoor_profile.this.name
      principal_id = try(azurerm_cdn_frontdoor_profile.this.identity[0].principal_id, null)
    }
    endpoint = {
      id       = azurerm_cdn_frontdoor_endpoint.this.id
      name     = azurerm_cdn_frontdoor_endpoint.this.name
      hostname = azurerm_cdn_frontdoor_endpoint.this.host_name
    }
  }
}

output "dns_zones" {
  # adapt to your actual zone resources
  value = {
    public_intterra_io = {
      name                = azurerm_dns_zone.public_intterra_io.name
      resource_group_name = azurerm_dns_zone.public_intterra_io.resource_group_name
      id                  = azurerm_dns_zone.public_intterra_io.id
    }
  }
}
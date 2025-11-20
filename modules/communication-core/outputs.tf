output "acs" {
  value = {
    id   = azurerm_communication_service.this.id
    name = azurerm_communication_service.this.name
  }
}

output "email_service" {
  value = {
    id   = azurerm_email_communication_service.this.id
    name = azurerm_email_communication_service.this.name
  }
}

output "email_domain" {
  value = {
    id               = azurerm_email_communication_service_domain.this.id
    name             = azurerm_email_communication_service_domain.this.name
    domain_management = azurerm_email_communication_service_domain.this.domain_management
  }
}
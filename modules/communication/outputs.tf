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

output "email_domain_azure_managed" {
  value = {
    id               = azurerm_email_communication_service_domain.azure_managed.id
    name             = azurerm_email_communication_service_domain.azure_managed.name
    domain_management = azurerm_email_communication_service_domain.azure_managed.domain_management
  }
}

output "email_domain_custom" {
  value = var.enable_custom_domain ? {
    id               = azurerm_email_communication_service_domain.custom[0].id
    name             = azurerm_email_communication_service_domain.custom[0].name
    domain_management = azurerm_email_communication_service_domain.custom[0].domain_management
  } : null
}


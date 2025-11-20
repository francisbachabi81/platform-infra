# Azure Communication Service
resource "azurerm_communication_service" "this" {
  name                = var.acs_name
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = var.tags
}

# Email Communication Service
resource "azurerm_email_communication_service" "this" {
  name                = var.email_service_name
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = var.tags
}

# Email domain (Azure-managed or custom)
resource "azurerm_email_communication_service_domain" "this" {
  name             = var.email_domain_name
  email_service_id = azurerm_email_communication_service.this.id

  # For now we default to Azure-managed domain. If you later pass a real
  # custom domain, you can make this conditional via a variable.
  domain_management = "AzureManaged"
}

# Associate the email domain with the ACS resource
resource "azurerm_communication_service_email_domain_association" "this" {
  communication_service_id = azurerm_communication_service.this.id
  email_service_domain_id  = azurerm_email_communication_service_domain.this.id
}
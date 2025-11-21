resource "azurerm_communication_service" "this" {
  name                = var.acs_name
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = merge(var.tags, { component = "communication-service" })
}

resource "azurerm_email_communication_service" "this" {
  name                = var.email_service_name
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = merge(var.tags, { component = "email-service" })
}

# Azure-managed domain (always created & associated immediately)
resource "azurerm_email_communication_service_domain" "azure_managed" {
  name                    = "AzureManagedDomain" # required literal
  email_service_id      = azurerm_email_communication_service.this.id
  domain_management = "AzureManaged"
  # no DNS records required for Azure-managed domain
}

resource "azurerm_communication_service_email_domain_association" "azure_managed" {
  communication_service_id = azurerm_communication_service.this.id
  email_service_domain_id  = azurerm_email_communication_service_domain.azure_managed.id

  depends_on = [
    azurerm_email_communication_service_domain.azure_managed
  ]
}
# Customer-managed domain (optional, no association by default)
resource "azurerm_email_communication_service_domain" "custom" {
  count                   = var.enable_custom_domain ? 1 : 0
  name                    = var.custom_domain_name
  email_service_id      = azurerm_email_communication_service.this.id
  domain_management = "CustomerManaged"
  # Important: you'll use the verification_records output to set DNS
  # records in your DNS zone *before* turning on associate_custom_domain.
}

# Optional association for the custom domain (only after DNS is ready)
resource "azurerm_communication_service_email_domain_association" "custom" {
  count = var.enable_custom_domain && var.associate_custom_domain ? 1 : 0

  communication_service_id = azurerm_communication_service.this.id
  email_service_domain_id  = azurerm_email_communication_service_domain.custom[0].id

  depends_on = [
    azurerm_email_communication_service_domain.custom
  ]
}

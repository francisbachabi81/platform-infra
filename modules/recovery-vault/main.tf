terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_recovery_services_vault" "rsv" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku                           = var.sku
  soft_delete_enabled           = var.soft_delete_enabled
  storage_mode_type             = var.storage_mode_type
  cross_region_restore_enabled  = var.cross_region_restore_enabled

  tags = var.tags
}

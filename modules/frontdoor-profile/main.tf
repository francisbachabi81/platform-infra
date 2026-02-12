terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  rg_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

resource "azapi_resource" "profile" {
  type      = "Microsoft.Cdn/profiles@2023-05-01"
  name      = var.profile_name
  parent_id = local.rg_id
  location  = "global"

  # azapi expects JSON for body
  body = jsonencode({
    sku = {
      name = var.sku_name
    }
  })

  tags = var.tags

  lifecycle {
    ignore_changes = [
      identity, 
    ]
  }
}

resource "azapi_resource" "endpoint" {
  type      = "Microsoft.Cdn/profiles/afdEndpoints@2023-05-01"
  name      = var.endpoint_name
  parent_id = azapi_resource.profile.id
  location  = "global"

  body = jsonencode({
    properties = {}
  })

  tags = var.tags
}

data "azapi_resource" "endpoint_read" {
  type        = "Microsoft.Cdn/profiles/afdEndpoints@2023-05-01"
  resource_id = azapi_resource.endpoint.id
  depends_on  = [azapi_resource.endpoint]
}
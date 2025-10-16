# app service plan
resource "azurerm_service_plan" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  os_type                       = var.os_type
  sku_name                      = var.sku_name
  worker_count                  = var.worker_count
  maximum_elastic_worker_count  = var.maximum_elastic_worker_count
  tags                          = var.tags
}

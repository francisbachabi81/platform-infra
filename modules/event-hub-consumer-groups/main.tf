resource "azurerm_eventhub_consumer_group" "cgs" {
  for_each           = toset(var.consumer_group_names)
  name               = each.value
  namespace_name     = var.namespace_name
  eventhub_name      = var.eventhub_name
  resource_group_name = var.resource_group_name
  user_metadata      = try(var.consumer_group_metadata[each.value], null)
}

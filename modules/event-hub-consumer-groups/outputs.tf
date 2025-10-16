output "consumer_group_ids" {
  value = { for k, v in azurerm_eventhub_consumer_group.cgs : k => v.id }
}

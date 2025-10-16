output "namespace_id" {
  value = azurerm_eventhub_namespace.ns.id
}

output "namespace_name" {
  value = azurerm_eventhub_namespace.ns.name
}

output "eventhub_name" {
  value = azurerm_eventhub.hub.name
}

output "private_endpoint_id" {
  value = try(azurerm_private_endpoint.pe[0].id, null)
}

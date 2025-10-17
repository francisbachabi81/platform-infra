output "ids" {
  value = {
    law  = azurerm_log_analytics_workspace.plane.id
    appi = azurerm_application_insights.plane.id
    rsv  = azurerm_recovery_services_vault.plane.id
  }
}

output "names" {
  value = {
    law  = azurerm_log_analytics_workspace.plane.name
    appi = azurerm_application_insights.plane.name
    rsv  = azurerm_recovery_services_vault.plane.name
  }
}

output "observability" {
  value = {
    law_workspace_id         = azurerm_log_analytics_workspace.plane.id
    appi_resource_id         = azurerm_application_insights.plane.id
    appi_connection_string   = azurerm_application_insights.plane.connection_string
    appi_instrumentation_key = azurerm_application_insights.plane.instrumentation_key
  }
  sensitive = true
}
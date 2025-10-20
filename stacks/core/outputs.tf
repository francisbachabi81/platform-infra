# outputs.tf

output "ids" {
  value = {
    law  = try(one(azurerm_log_analytics_workspace.plane[*].id), null)
    appi = try(one(azurerm_application_insights.plane[*].id),   null)
    rsv  = try(one(azurerm_recovery_services_vault.plane[*].id), null)
  }
}

output "names" {
  value = {
    law  = try(one(azurerm_log_analytics_workspace.plane[*].name), null)
    appi = try(one(azurerm_application_insights.plane[*].name),     null)
    rsv  = try(one(azurerm_recovery_services_vault.plane[*].name),  null)
  }
}

output "observability" {
  value = {
    law_workspace_id         = try(one(azurerm_log_analytics_workspace.plane[*].id),                 null)
    appi_resource_id         = try(one(azurerm_application_insights.plane[*].id),                    null)
    appi_connection_string   = try(one(azurerm_application_insights.plane[*].connection_string),     null)
    appi_instrumentation_key = try(one(azurerm_application_insights.plane[*].instrumentation_key),   null)
  }
  sensitive = true
}
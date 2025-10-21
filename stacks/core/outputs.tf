output "meta" {
  value = {
    product      = var.product
    plane        = local.plane_full
    plane_code   = local.plane_code
    region_code  = var.region
    location     = var.location
    subscription = var.subscription_id
    tenant       = var.tenant_id
    rg_core_name = local.rg_name_core
  }
}

output "features" {
  value = {
    enable_public_features = local.enable_public_features
    enable_hrz_features    = local.enable_hrz_features
    create_scope_both      = local.create_scope_both

    create_rg_core_platform = var.create_rg_core_platform
    create_log_analytics    = var.create_log_analytics
    create_application_insights = var.create_application_insights
    create_recovery_vault   = var.create_recovery_vault

    rg_core_platform_created = try(length(module.rg_core_platform) > 0, false)
    law_created              = try(length(azurerm_log_analytics_workspace.plane) > 0, false)
    appi_created             = try(length(azurerm_application_insights.plane) > 0, false)
    rsv_created              = try(length(azurerm_recovery_services_vault.plane) > 0, false)
  }
}

output "resource_group" {
  value = {
    id   = try(module.rg_core_platform[0].id, null)
    name = local.rg_name_core
  }
}

output "ids" {
  value = {
    law  = try(one(azurerm_log_analytics_workspace.plane[*].id), null)
    appi = try(one(azurerm_application_insights.plane[*].id),    null)
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

output "log_analytics" {
  value = {
    id               = try(one(azurerm_log_analytics_workspace.plane[*].id), null)
    name             = try(one(azurerm_log_analytics_workspace.plane[*].name), null)
    sku              = try(var.law_sku, null)
    retention_in_days = try(var.law_retention_days, null)
  }
}

output "application_insights" {
  value = {
    id     = try(one(azurerm_application_insights.plane[*].id), null)
    name   = try(one(azurerm_application_insights.plane[*].name), null)
    internet_ingestion_enabled = try(var.appi_internet_ingestion_enabled, null)
    internet_query_enabled     = try(var.appi_internet_query_enabled, null)
  }
}

output "recovery_services_vault" {
  value = {
    id   = try(one(azurerm_recovery_services_vault.plane[*].id), null)
    name = try(one(azurerm_recovery_services_vault.plane[*].name), null)
    sku  = "Standard"
  }
}

output "observability" {
  value = {
    law_workspace_id         = try(one(azurerm_log_analytics_workspace.plane[*].id),               null)
    appi_resource_id         = try(one(azurerm_application_insights.plane[*].id),                  null)
    appi_connection_string   = try(one(azurerm_application_insights.plane[*].connection_string),   null)
    appi_instrumentation_key = try(one(azurerm_application_insights.plane[*].instrumentation_key), null)
  }
  sensitive = true
}
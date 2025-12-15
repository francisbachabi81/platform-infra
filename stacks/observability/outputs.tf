output "meta" {
  value = {
    product    = var.product
    env        = var.env
    plane      = local.plane_full
    plane_code = local.plane_code
  }
}

output "targets" {
  value = {
    kv_ids        = try(keys(local.kv_map),        [])
    sa_ids        = try(keys(local.sa_map),        [])
    sbns_ids      = try(keys(local.sbns_map),      [])
    ehns_ids      = try(keys(local.ehns_map),      [])
    pg_ids        = try(keys(local.pg_map),        [])
    redis_ids     = try(keys(local.redis_map),     [])
    rsv_ids       = try(keys(local.rsv_map),       [])
    appi_ids      = try(keys(local.appi_map),      [])
    vpng_ids      = try(keys(local.vpng_map),      [])
    funcapp_ids   = try(keys(local.fa_map),        [])
    webapp_ids    = try(keys(local.web_map),       [])
    appgw_ids     = try(keys(local.appgw_map),     [])
    frontdoor_ids = try(keys(local.afd_map),       [])
    aks_ids       = try(keys(local.aks_map),       [])
    nsg_ids       = try(keys(local.nsg_map),       [])
    law_id        = local.law_id
  }
}

output "action_group_id" {
  value = local.ag_id
}

output "diagnostic_setting_ids" {
  value = {
    kv    = [for _, v in azurerm_monitor_diagnostic_setting.kv    : v.id]
    sa    = [for _, v in azurerm_monitor_diagnostic_setting.sa    : v.id]
    sbns  = [for _, v in azurerm_monitor_diagnostic_setting.sbns  : v.id]
    ehns  = [for _, v in azurerm_monitor_diagnostic_setting.ehns  : v.id]
    pg    = [for _, v in azurerm_monitor_diagnostic_setting.pg    : v.id]
    redis = [for _, v in azurerm_monitor_diagnostic_setting.redis : v.id]
    rsv   = [for _, v in azurerm_monitor_diagnostic_setting.rsv   : v.id]
    appi  = [for _, v in azurerm_monitor_diagnostic_setting.appi  : v.id]
    vpng  = [for _, v in azurerm_monitor_diagnostic_setting.vpng  : v.id]
    fa    = [for _, v in azurerm_monitor_diagnostic_setting.fa    : v.id]
    web   = [for _, v in azurerm_monitor_diagnostic_setting.web   : v.id]
    appgw = [for _, v in azurerm_monitor_diagnostic_setting.appgw : v.id]
    afd   = [for _, v in azurerm_monitor_diagnostic_setting.afd   : v.id]
    aks   = [for _, v in azurerm_monitor_diagnostic_setting.aks   : v.id]
    nsg   = [for _, v in azurerm_monitor_diagnostic_setting.nsg   : v.id]
  }
}

output "nsg_diag_categories_debug" {
  value = {
    for k, v in data.azurerm_monitor_diagnostic_categories.nsg :
    k => {
      log_category_types = try(v.log_category_types, [])
      metrics            = try(v.metrics, [])
    }
  }
}

output "cost_exports_storage" {
  value = var.enable_cost_exports ? {
    id        = try(azurerm_storage_account.cost_exports[0].id, null)
    name      = try(azurerm_storage_account.cost_exports[0].name, null)
    container = var.cost_exports_container_name
    root      = var.cost_exports_root_folder
  } : null
}

output "cost_exports_execute_examples" {
  value = var.enable_cost_exports ? {
    # Example: execute the DEV manual export for a given custom month
    dev_manual_execute = "az rest --method post --url \"https://management.azure.com/subscriptions/${local.dev_sub}/providers/Microsoft.CostManagement/exports/ce-${var.product}-dev-${var.region}-manual-custom/execute?api-version=2025-03-01\" --body '{\"timePeriod\":{\"from\":\"2025-11-01T00:00:00Z\",\"to\":\"2025-11-30T23:59:59Z\"}}'"
  } : null
}

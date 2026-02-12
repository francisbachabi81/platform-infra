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
    kv_ids        = try(keys(local.kv_map), [])
    sa_ids        = try(keys(local.sa_map), [])
    sbns_ids      = try(keys(local.sbns_map), [])
    ehns_ids      = try(keys(local.ehns_map), [])
    pg_ids        = try(keys(local.pg_map), [])
    redis_ids     = try(keys(local.redis_map), [])
    rsv_ids       = try(keys(local.rsv_map), [])
    appi_ids      = try(keys(local.appi_map), [])
    vpng_ids      = try(keys(local.vpng_map), [])
    funcapp_ids   = try(keys(local.fa_map), [])
    webapp_ids    = try(keys(local.web_map), [])
    appgw_ids     = try(keys(local.appgw_map), [])
    frontdoor_ids = try(keys(local.afd_map), [])
    aks_ids       = try(keys(local.aks_map), [])
    nsg_ids       = try(keys(local.nsg_map), [])
    vnet_ids      = distinct(flatten([for _, v in local.vnet_ids_by_env_effective : v]))
    law_id        = local.law_id
  }
}

output "action_group_id" {
  value = local.ag_id
}

output "diagnostic_setting_ids" {
  value = {
    # kv    = [for _, v in azurerm_monitor_diagnostic_setting.kv    : v.id]
    kv_env  = try([for _, v in azurerm_monitor_diagnostic_setting.kv_env : v.id], [])
    kv_core = try([for _, v in azurerm_monitor_diagnostic_setting.kv_core : v.id], [])
    # Subscription diag
    sub_env = try([for v in azurerm_monitor_diagnostic_setting.sub_env : v.id], [])
    sa      = [for _, v in azurerm_monitor_diagnostic_setting.sa : v.id]
    sbns    = [for _, v in azurerm_monitor_diagnostic_setting.sbns : v.id]
    ehns    = [for _, v in azurerm_monitor_diagnostic_setting.ehns : v.id]
    pg      = [for _, v in azurerm_monitor_diagnostic_setting.pg : v.id]
    redis   = [for _, v in azurerm_monitor_diagnostic_setting.redis : v.id]
    rsv     = [for _, v in azurerm_monitor_diagnostic_setting.rsv : v.id]
    appi    = [for _, v in azurerm_monitor_diagnostic_setting.appi : v.id]
    vpng    = [for _, v in azurerm_monitor_diagnostic_setting.vpng : v.id]
    fa      = [for _, v in azurerm_monitor_diagnostic_setting.fa : v.id]
    web     = [for _, v in azurerm_monitor_diagnostic_setting.web : v.id]
    appgw   = [for _, v in azurerm_monitor_diagnostic_setting.appgw : v.id]
    afd     = [for _, v in azurerm_monitor_diagnostic_setting.afd : v.id]
    aks     = [for _, v in azurerm_monitor_diagnostic_setting.aks : v.id]
    # nsg   = [for _, v in azurerm_monitor_diagnostic_setting.nsg   : v.id]
    nsg       = try([for _, v in azurerm_monitor_diagnostic_setting.nsg : v.id], [])
    appgw_nsg = try([for v in azurerm_monitor_diagnostic_setting.appgw_nsg : v.id], [])
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

output "vnet_flow_log_ids" {
  value = concat(
    [for _, v in azurerm_network_watcher_flow_log.vnet_core : v.id],
    [for _, v in azurerm_network_watcher_flow_log.vnet_dev : v.id],
    [for _, v in azurerm_network_watcher_flow_log.vnet_qa : v.id],
    [for _, v in azurerm_network_watcher_flow_log.vnet_prod : v.id],
    [for _, v in azurerm_network_watcher_flow_log.vnet_uat : v.id],
  )
}
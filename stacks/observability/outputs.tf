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

output "debug_nsg_flowlogs_v2" {
  value = {
    # Raw inputs
    var_env   = var.env
    var_plane = var.plane

    # Effective env / plane
    env_effective   = local.env_effective
    plane_effective = local.plane_effective
    plane_code      = local.plane_code

    # Target env sets for flow logs
    nsg_flowlog_env_sets = local.nsg_flowlog_env_sets
    nsg_flowlog_env_keys = local.nsg_flowlog_env_keys

    # NSG IDs collected from shared-network
    nsg_flowlog_ids       = local.nsg_flowlog_ids
    nsg_flowlog_ids_count = length(local.nsg_flowlog_ids)

    # Subscription IDs actually present in the NSG IDs
    nsg_subscription_ids_distinct = distinct([
      for id in local.nsg_flowlog_ids :
      element(split(id, "/"), 2)
    ])

    # Final map used for for_each on azurerm_network_watcher_flow_log.nsg
    nsg_flowlog_map       = try(local.nsg_flowlog_map, null)
    nsg_flowlog_map_keys  = try(keys(local.nsg_flowlog_map), null)
    nsg_flowlog_map_count = try(length(local.nsg_flowlog_map), null)

    # Gate flag
    nsg_flowlogs_enabled = try(local.nsg_flowlogs_enabled, null)

    # Network watcher naming we’ll use
    network_watcher_name_env = local.network_watcher_name_env
    network_watcher_rg_env   = local.network_watcher_rg_env

    # What the module thinks env/core subscriptions are
    sub_env_resolved  = local.sub_env_resolved
    sub_core_resolved = local.sub_core_resolved

    # LAW + storage account resolution (for traffic analytics)
    law_id              = local.law_id
    nsg_flow_logs_sa_id = local.nsg_flow_logs_sa_id
  }
}

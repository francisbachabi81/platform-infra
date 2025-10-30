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
    law_id        = local.law_id
  }
}

output "action_group_id" {
  value = local.ag_id
}

output "diagnostic_setting_ids" {
  value = {
    kv     = [for k, v in azurerm_monitor_diagnostic_setting.kv     : v.id]
    sa     = [for k, v in azurerm_monitor_diagnostic_setting.sa     : v.id]
    sbns   = [for k, v in azurerm_monitor_diagnostic_setting.sbns   : v.id]
    ehns   = [for k, v in azurerm_monitor_diagnostic_setting.ehns   : v.id]
    pg     = [for k, v in azurerm_monitor_diagnostic_setting.pg     : v.id]
    redis  = [for k, v in azurerm_monitor_diagnostic_setting.redis  : v.id]
    rsv    = [for k, v in azurerm_monitor_diagnostic_setting.rsv    : v.id]
    appi   = [for k, v in azurerm_monitor_diagnostic_setting.appi   : v.id]
    vpng   = [for k, v in azurerm_monitor_diagnostic_setting.vpng   : v.id]
    fa     = [for k, v in azurerm_monitor_diagnostic_setting.fa     : v.id]
    web    = [for k, v in azurerm_monitor_diagnostic_setting.web    : v.id]
    appgw  = [for k, v in azurerm_monitor_diagnostic_setting.appgw  : v.id]
    afd    = [for k, v in azurerm_monitor_diagnostic_setting.afd    : v.id]
    aks    = [for k, v in azurerm_monitor_diagnostic_setting.aks    : v.id]
  }
}

output "debug_obs_env_scope" {
  value = {
    env_subscription_id  = local.env_sub
    env_tenant_id        = local.env_tenant
    rg_app_name          = local.rg_app_name
  }
  sensitive = true
}

output "debug_obs_core_scope" {
  value = {
    core_subscription_id = local.core_sub
    core_tenant_id       = local.core_tenant
  }
  sensitive = true
}

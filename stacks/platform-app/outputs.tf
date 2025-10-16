# ids
output "ids" {
  description = "primary resource ids created by this stack"
  value = {
    kv1    = local.kv1_id
    sa1    = local.sa1_id
    cosmos = local.cosmos1_id

    rsv1 = local.rsv1_id
    aks1 = local.aks_id
    acr1 = local.acr_id

    cdbpg1 = try(module.cdbpg1[0].id, null)  # if you keep cdbpg module elsewhere

    law  = local.law_id
    appi = try(azurerm_application_insights.obs_env[0].id,
               azurerm_application_insights.obs_hub[0].id, null)
  }
}

# names
output "names" {
  description = "common resource names"
  value = {
    kv1     = local.kv1_name
    sa1     = local.sa1_name
    cosmos1 = local.cosmos1_name

    rsv1 = local.rsv1_name
    aks1 = local.aks_name
    acr1 = try(module.acr1_env[0].name, module.acr1_hub[0].name, null)

    law  = try(azurerm_log_analytics_workspace.obs_env[0].name,
               azurerm_log_analytics_workspace.obs_hub[0].name, null)
    appi = try(azurerm_application_insights.obs_env[0].name,
               azurerm_application_insights.obs_hub[0].name, null)
  }
}

# endpoints (non-secret)
output "endpoints" {
  description = "non-secret endpoints or hostnames"
  value = {
    acr_login_server  = local.acr_loginserver
    cdbpg_coordinator = try(module.cdbpg1[0].coordinator_hostname, null)
  }
}

# feature flags (what actually got created)
output "features" {
  description = "which optional components were requested/created"
  value = {
    create_servicebus = try(var.create_servicebus, false)
    servicebus_sku    = try(var.servicebus_sku, null)

    aks1_created   = local.aks_id != null
    acr1_created   = local.acr_id != null
    rsv1_created   = local.rsv1_id != null
    cdbpg1_created = try(length(module.cdbpg1) > 0, false)
    obs_created    = local.law_id != null
  }
}

# aks summary
output "aks" {
  description = "aks cluster created in this environment"
  value = (local.aks_id == null ? null : {
    id   = local.aks_id
    name = local.aks_name
  })
}

# cosmos db for postgresql (citus) summary (kept as you had)
output "cdbpg" {
  description = "cosmos db for postgresql (citus) details (no passwords)"
  value = try({
    id                        = module.cdbpg1[0].id
    name                      = module.cdbpg1[0].name
    coordinator_hostname      = try(module.cdbpg1[0].coordinator_hostname, null)
    node_count                = try(module.cdbpg1[0].node_count, null)
    citus_version             = try(module.cdbpg1[0].citus_version, null)
    private_endpoint_id       = try(module.cdbpg1[0].private_endpoint_id, null)
    private_dns_zone_group_id = try(module.cdbpg1[0].private_dns_zone_group_id, null)
  }, null)
}

output "fd_endpoint_hostname" {
  description = "Front Door endpoint hostname (null if not created)."
  value       = length(module.fd) > 0 ? module.fd[0].endpoint_hostname : null
}

output "postgres" {
  description = "postgres flexible server (no secrets)"
  value = (local.pg_id == null ? null : {
    id                  = local.pg_id
    name                = local.pg_name
    fqdn                = local.pg_fqdn
    private_dns_zone_id = try(local.pg_private_zone_id, null)
  })
}

output "redis" {
  description = "azure cache for redis (no secrets)"
  value = (local.redis_id == null ? null : {
    id       = local.redis_id
    name     = local.redis_name
    hostname = local.redis_hostname
    sku_name = var.redis_sku_name
  })
}
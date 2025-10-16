# ids
output "ids" {
  description = "primary resource ids created by this stack"
  value = {
    kv1    = try(module.kv1[0].id, null)
    sa1    = try(module.sa1.id, null)
    cosmos = try(module.cosmos1.id, null)

    rsv1   = try(module.rsv1[0].id, null)
    aks1   = try(module.aks1[0].id, null)
    acr1   = try(module.acr1[0].id, null)
    sbns1  = try(module.sbns1[0].id, null)
    cdbpg1 = try(module.cdbpg1[0].id, null)

    law  = try(azurerm_log_analytics_workspace.obs[0].id, null)
    appi = try(azurerm_application_insights.obs[0].id, null)
    # postgres = try(module.postgres.id, null)
    # redis    = try(module.redis1.id, null)
  }
}

# names
output "names" {
  description = "common resource names"
  value = {
    kv1     = try(module.kv1[0].name, null)
    sa1     = try(module.sa1.name, null)
    cosmos1 = try(module.cosmos1.name, null)

    rsv1   = try(module.rsv1[0].name, null)
    aks1   = try(module.aks1[0].name, null)
    acr1   = try(module.acr1[0].name, null)
    sbns1  = try(module.sbns1[0].name, null)
    cdbpg1 = try(module.cdbpg1[0].name, null)

    law  = try(azurerm_log_analytics_workspace.obs[0].name, null)
    appi = try(azurerm_application_insights.obs[0].name, null)
    # postgres = try(module.postgres.name, null)
    # redis    = try(module.redis1.name, null)
  }
}

# endpoints (non-secret)
output "endpoints" {
  description = "non-secret endpoints or hostnames"
  value = {
    acr_login_server  = try(module.acr1[0].login_server, null)
    sb_namespace_fqdn = try(module.sbns1[0].fqdn, null)
    cdbpg_coordinator = try(module.cdbpg1[0].coordinator_hostname, null)
    # postgres_fqdn   = try(module.postgres.fqdn, null)
    # redis_hostname  = try(module.redis1.hostname, null)
  }
}

# feature flags (what actually got created)
output "features" {
  description = "which optional components were requested/created"
  value = {
    create_servicebus = try(var.create_servicebus, false)
    servicebus_sku    = try(var.servicebus_sku, null)

    aks1_created   = try(length(module.aks1) > 0, false)
    acr1_created   = try(length(module.acr1) > 0, false)
    rsv1_created   = try(length(module.rsv1) > 0, false)
    sbns1_created  = try(length(module.sbns1) > 0, false)
    cdbpg1_created = try(length(module.cdbpg1) > 0, false)
    obs_created    = try(length(azurerm_log_analytics_workspace.obs) > 0, false)
  }
}

# aks summary (id + name)
output "aks" {
  description = "aks cluster created in this environment"
  value = try({
    id   = module.aks1[0].id
    name = module.aks1[0].name
  }, null)
}

# service bus summary
output "servicebus" {
  description = "service bus namespace details (no keys)"
  value = try({
    id                            = module.sbns1[0].id
    name                          = module.sbns1[0].name
    sku                           = var.servicebus_sku
    capacity                      = var.servicebus_capacity
    public_network_access_enabled = try(module.sbns1[0].public_network_access_enabled, null)
    sas_policy_name               = try(module.sbns1[0].sas_policy_name, null)
    sas_policy_id                 = try(module.sbns1[0].sas_policy_id, null)
  }, null)
}

# citus summary (non-secret)
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
  value = try({
    id                  = module.postgres[0].id
    name                = module.postgres[0].name
    fqdn                = try(module.postgres[0].fqdn, null)
    private_dns_zone_id = try(module.postgres[0].private_dns_zone_id, null)
  }, null)
}

output "redis" {
  description = "azure cache for redis (no secrets)"
  value = try({
    id       = module.redis1[0].id
    name     = module.redis1[0].name
    hostname = try(module.redis1[0].hostname, null)
    sku_name = try(var.redis_sku_name, null)
  }, null)
}
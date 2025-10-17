#############################
# ids
#############################
output "ids" {
  description = "primary resource ids created by this stack"
  value = {
    kv1       = try(module.kv1[0].id, null)
    sa1       = try(module.sa1[0].id, null)
    cosmos    = try(module.cosmos1[0].id, null)

    rsv1      = try(module.rsv1[0].id, null)       # shared (hub) via provider alias
    aks1      = try(module.aks1[0].id, null)       # hub in dev, env in uat/prod (same module name)

    sbns1     = try(module.sbns1[0].id, null)      # Service Bus namespace (env)
    eventhub  = try(module.eventhub[0].id, null)   # Event Hub (env)

    law       = try(azurerm_log_analytics_workspace.obs[0].id, null)
    appi      = try(azurerm_application_insights.obs[0].id, null)

    postgres  = try(module.postgres[0].id, null)
    redis     = try(module.redis1[0].id, null)
    cdbpg1    = try(module.cdbpg1[0].id, null)
  }
}

#############################
# names
#############################
output "names" {
  description = "common resource names"
  value = {
    kv1         = try(module.kv1[0].name, null)
    sa1         = try(module.sa1[0].name, null)
    cosmos1     = try(module.cosmos1[0].name, null)

    rsv1        = try(module.rsv1[0].name, null)
    aks1        = try(module.aks1[0].name, null)

    sbns1       = try(module.sbns1[0].name, null)
    eventhub_ns = try(module.eventhub[0].namespace_name, null)
    eventhub    = try(module.eventhub[0].eventhub_name, null)

    law         = try(azurerm_log_analytics_workspace.obs[0].name, null)
    appi        = try(azurerm_application_insights.obs[0].name, null)

    postgres    = try(module.postgres[0].name, null)
    redis       = try(module.redis1[0].name, null)
    cdbpg1      = try(module.cdbpg1[0].name, null)
  }
}

#############################
# endpoints (non-secret)
#############################
output "endpoints" {
  description = "non-secret endpoints or hostnames"
  value = {
    sb_namespace_fqdn  = null                                       # set if your servicebus module outputs it
    eventhub_namespace = try(module.eventhub[0].namespace_name, null)
    postgres_fqdn      = try(module.postgres[0].fqdn, null)
    redis_hostname     = try(module.redis1[0].hostname, null)
  }
}

#############################
# feature flags (what actually got created)
#############################
output "features" {
  description = "which optional components were requested/created"
  value = {
    create_servicebus = try(var.create_servicebus, false)
    servicebus_sku    = try(var.servicebus_sku, null)

    aks1_created      = try(length(module.aks1) > 0, false)
    rsv1_created      = try(length(module.rsv1) > 0, false)
    sbns1_created     = try(length(module.sbns1) > 0, false)
    eventhub_created  = try(length(module.eventhub) > 0, false)
    obs_created       = try(length(azurerm_log_analytics_workspace.obs) > 0, false)
    postgres_created  = try(length(module.postgres) > 0, false)
    redis_created     = try(length(module.redis1) > 0, false)
    cdbpg_created     = try(length(module.cdbpg1) > 0, false)
  }
}

#############################
# aks summary (id + name)
#############################
output "aks" {
  description = "AKS cluster (hub in dev; env in uat/prod; null in qa)"
  value = try({
    id   = module.aks1[0].id
    name = module.aks1[0].name
  }, null)
}

#############################
# service bus summary
#############################
output "servicebus" {
  description = "service bus namespace details (no keys)"
  value = try({
    id       = module.sbns1[0].id
    name     = try(module.sbns1[0].name, null)
    sku      = var.servicebus_sku
    capacity = var.servicebus_capacity
  }, null)
}

#############################
# postgres (no secrets)
#############################
output "postgres" {
  description = "postgres flexible server (no secrets)"
  value = try({
    id                  = module.postgres[0].id
    name                = module.postgres[0].name
    fqdn                = try(module.postgres[0].fqdn, null)
    private_dns_zone_id = try(module.postgres[0].private_dns_zone_id, null)
  }, null)
}

#############################
# redis (no secrets)
#############################
output "redis" {
  description = "azure cache for redis (no secrets)"
  value = try({
    id       = module.redis1[0].id
    name     = module.redis1[0].name
    hostname = try(module.redis1[0].hostname, null)
    sku_name = try(var.redis_sku_name, null)
  }, null)
}

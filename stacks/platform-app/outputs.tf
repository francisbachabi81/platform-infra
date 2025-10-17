#############################
# ids
#############################
output "ids" {
  description = "primary resource ids created by this stack"
  value = {
    kv1    = try(module.kv1[0].id, null)
    sa1    = try(module.sa1[0].id, null)
    cosmos = try(module.cosmos1[0].id, null)

    # Shared (hub) vs env variants supported
    rsv1 = try(module.rsv1_hub[0].id, module.rsv1[0].id, null)
    acr1 = try(module.acr1_hub[0].id, module.acr1[0].id, null)

    # AKS is shared (hub) in dev, env-specific in uat/prod
    aks1 = try(
      local.aks_id,
      module.aks1_hub[0].id,
      module.aks1_env[0].id,
      null
    )

    # Messaging
    sbns1    = try(module.sbns1[0].id, null)
    eventhub = try(module.eventhub[0].id, null)

    # Observability
    law  = try(azurerm_log_analytics_workspace.obs[0].id, null)
    appi = try(azurerm_application_insights.obs[0].id, null)

    # Data plane
    postgres = try(module.postgres[0].id, null)
    redis    = try(module.redis1[0].id, null)
    cdbpg1   = try(module.cdbpg1[0].id, null)
  }
}

#############################
# names
#############################
output "names" {
  description = "common resource names"
  value = {
    kv1        = try(module.kv1[0].name, null)
    sa1        = try(module.sa1[0].name, null)
    cosmos1    = try(module.cosmos1[0].name, null)

    rsv1       = try(module.rsv1_hub[0].name, module.rsv1[0].name, null)
    acr1       = try(module.acr1_hub[0].name, module.acr1[0].name, null)

    # AKS name from local or module variants
    aks1       = try(
      local.aks_name,
      module.aks1_hub[0].name,
      module.aks1_env[0].name,
      null
    )

    sbns1       = try(module.sbns1[0].name, null)
    eventhub_ns = try(module.eventhub[0].namespace_name, null)
    eventhub    = try(module.eventhub[0].eventhub_name, null)

    law   = try(azurerm_log_analytics_workspace.obs[0].name, null)
    appi  = try(azurerm_application_insights.obs[0].name, null)

    postgres = try(module.postgres[0].name, null)
    redis    = try(module.redis1[0].name, null)
    cdbpg1   = try(module.cdbpg1[0].name, null)
  }
}

#############################
# endpoints (non-secret)
#############################
output "endpoints" {
  description = "non-secret endpoints or hostnames"
  value = {
    acr_login_server   = try(module.acr1_hub[0].login_server, module.acr1[0].login_server, null)
    sb_namespace_fqdn  = null  # populate if your servicebus module exposes it
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

    # AKS can be hub or env
    aks1_created = (
      try(length(module.aks1_hub) > 0, false) ||
      try(length(module.aks1_env) > 0, false)
    )

    # ACR/RSV can be hub or env depending on your config
    acr1_created = (
      try(length(module.acr1_hub) > 0, false) ||
      try(length(module.acr1) > 0, false)
    )
    rsv1_created = (
      try(length(module.rsv1_hub) > 0, false) ||
      try(length(module.rsv1) > 0, false)
    )

    sbns1_created    = try(length(module.sbns1) > 0, false)
    eventhub_created = try(length(module.eventhub) > 0, false)
    obs_created      = try(length(azurerm_log_analytics_workspace.obs) > 0, false)
    postgres_created = try(length(module.postgres) > 0, false)
    redis_created    = try(length(module.redis1) > 0, false)
    cdbpg_created    = try(length(module.cdbpg1) > 0, false)
  }
}

#############################
# aks summary (id + name)
#############################
output "aks" {
  description = "AKS cluster (hub in dev; env in uat/prod; null in qa)"
  value = try({
    id   = try(local.aks_id,   module.aks1_hub[0].id,  module.aks1_env[0].id)
    name = try(local.aks_name, module.aks1_hub[0].name, module.aks1_env[0].name)
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

# ids
output "ids" {
  description = "primary resource ids created by this stack"
  value = {
    kv1    = try(module.kv1_env[0].id, null)
    sa1    = try(module.sa1_env[0].id, null)
    cosmos = try(module.cosmos1_env[0].id, null)

    rsv1   = try(module.rsv1_hub[0].id, null)
    aks1   = try(module.aks1_hub[0].id, null)
    # acr1   = try(module.acr1_hub[0].id, null)
    sbns1  = try(module.eventhub_env[0].id, null)

    law  = try(azurerm_log_analytics_workspace.obs_hub[0].id, azurerm_log_analytics_workspace.obs_env[0].id, null)
    appi = try(azurerm_application_insights.obs_hub[0].id, azurerm_application_insights.obs_env[0].id, null)

    # Optional
    postgres = try(module.postgres_env[0].id, null)
    redis    = try(module.redis1_env[0].id, null)
  }
}

# names
output "names" {
  description = "common resource names"
  value = {
    kv1     = try(module.kv1_env[0].name, null)
    sa1     = try(module.sa1_env[0].name, null)
    cosmos1 = try(module.cosmos1_env[0].name, null)

    rsv1   = try(module.rsv1_hub[0].name, null)
    aks1   = try(module.aks1_hub[0].name, null)
    # acr1   = try(module.acr1_hub[0].name, null)
    sbns1  = try(module.eventhub_env[0].namespace_name, null)

    law  = try(azurerm_log_analytics_workspace.obs_hub[0].name, azurerm_log_analytics_workspace.obs_env[0].name, null)
    appi = try(azurerm_application_insights.obs_hub[0].name, azurerm_application_insights.obs_env[0].name, null)

    postgres = try(module.postgres_env[0].name, null)
    redis    = try(module.redis1_env[0].name, null)
  }
}

# endpoints (non-secret)
output "endpoints" {
  description = "non-secret endpoints or hostnames"
  value = {
    # acr_login_server  = try(module.acr1_hub[0].login_server, null)
    sb_namespace_fqdn = null # event-hub module may expose fqdn if implemented
    postgres_fqdn     = try(module.postgres_env[0].fqdn, null)
    redis_hostname    = try(module.redis1_env[0].hostname, null)
  }
}

# feature flags (what actually got created)
output "features" {
  description = "which optional components were requested/created"
  value = {
    create_servicebus = try(var.create_servicebus, false)
    servicebus_sku    = try(var.servicebus_sku, null)

    aks1_created   = try(length(module.aks1_hub) > 0, false)
    # acr1_created   = try(length(module.acr1_hub) > 0, false)
    rsv1_created   = try(length(module.rsv1_hub) > 0, false)
    sbns1_created  = try(length(module.eventhub_env) > 0, false)
    obs_created    = try(length(azurerm_log_analytics_workspace.obs_hub) > 0, false) || try(length(azurerm_log_analytics_workspace.obs_env) > 0, false)
    postgres_created = try(length(module.postgres_env) > 0, false)
    redis_created    = try(length(module.redis1_env) > 0, false)
  }
}

# aks summary (id + name)
output "aks" {
  description = "AKS cluster (hub in dev; env in uat/prod; null in qa)"
  value = try({
    id   = try(module.aks1_hub[0].id, module.aks1_env[0].id)
    name = try(module.aks1_hub[0].name, module.aks1_env[0].name)
  }, null)
}

# service bus summary
output "servicebus" {
  description = "service bus namespace details (no keys)"
  value = try({
    id                            = module.eventhub_env[0].id
    name                          = module.eventhub_env[0].namespace_name
    sku                           = var.servicebus_sku
    capacity                      = var.servicebus_capacity
  }, null)
}

output "postgres" {
  description = "postgres flexible server (no secrets)"
  value = try({
    id                  = module.postgres_env[0].id
    name                = module.postgres_env[0].name
    fqdn                = try(module.postgres_env[0].fqdn, null)
    private_dns_zone_id = try(module.postgres_env[0].private_dns_zone_id, null)
  }, null)
}

output "redis" {
  description = "azure cache for redis (no secrets)"
  value = try({
    id       = module.redis1_env[0].id
    name     = module.redis1_env[0].name
    hostname = try(module.redis1_env[0].hostname, null)
    sku_name = try(var.redis_sku_name, null)
  }, null)
}
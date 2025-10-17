output "ids" {
  value = {
    kv1      = try(module.kv1[0].id, null)
    sa1      = try(module.sa1[0].id, null)
    cosmos   = try(module.cosmos1[0].id, null)
    aks1     = try(module.aks1_hub[0].id, module.aks1_env[0].id, null)
    sbns1    = try(module.sbns1[0].id, null)
    eventhub = try(module.eventhub[0].id, null)
    postgres = try(module.postgres[0].id, null)
    redis    = try(module.redis1[0].id, null)
    cdbpg1   = try(module.cdbpg1[0].id, null)
  }
}
output "names" {
  value = {
    kv1         = try(module.kv1[0].name, null)
    sa1         = try(module.sa1[0].name, null)
    cosmos1     = try(module.cosmos1[0].name, null)
    aks1        = try(module.aks1_hub[0].name, module.aks1_env[0].name, null)
    sbns1       = try(module.sbns1[0].name, null)
    eventhub_ns = try(module.eventhub[0].namespace_name, null)
    eventhub    = try(module.eventhub[0].eventhub_name, null)
    postgres    = try(module.postgres[0].name, null)
    redis       = try(module.redis1[0].name, null)
    cdbpg1      = try(module.cdbpg1[0].name, null)
  }
}
output "endpoints" {
  value = {
    sb_namespace_fqdn  = null
    eventhub_namespace = try(module.eventhub[0].namespace_name, null)
    postgres_fqdn      = try(module.postgres[0].fqdn, null)
    redis_hostname     = try(module.redis1[0].hostname, null)
  }
}
output "features" {
  value = {
    create_servicebus = try(var.create_servicebus, false)
    servicebus_sku    = try(var.servicebus_sku, null)
    aks1_created      = (try(length(module.aks1_hub) > 0, false) || try(length(module.aks1_env) > 0, false))
    sbns1_created     = try(length(module.sbns1) > 0, false)
    eventhub_created  = try(length(module.eventhub) > 0, false)
    postgres_created  = try(length(module.postgres) > 0, false)
    redis_created     = try(length(module.redis1) > 0, false)
    cdbpg_created     = try(length(module.cdbpg1) > 0, false)
  }
}
output "aks" {
  value = try({
    id   = try(module.aks1_hub[0].id,  module.aks1_env[0].id)
    name = try(module.aks1_hub[0].name, module.aks1_env[0].name)
  }, null)
}
output "servicebus" {
  value = try({
    id       = module.sbns1[0].id
    name     = try(module.sbns1[0].name, null)
    sku      = var.servicebus_sku
    capacity = var.servicebus_capacity
  }, null)
}
output "postgres" {
  value = try({
    id                  = module.postgres[0].id
    name                = module.postgres[0].name
    fqdn                = try(module.postgres[0].fqdn, null)
    private_dns_zone_id = try(module.postgres[0].private_dns_zone_id, null)
  }, null)
}
output "redis" {
  value = try({
    id       = module.redis1[0].id
    name     = module.redis1[0].name
    hostname = try(module.redis1[0].hostname, null)
    sku_name = try(var.redis_sku_name, null)
  }, null)
}

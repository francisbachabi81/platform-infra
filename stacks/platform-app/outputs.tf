output "meta" {
  value = {
    product      = var.product
    env          = var.env
    plane        = local.plane
    plane_code   = local.plane_code
    region_code  = var.region
    location     = var.location
    subscription = var.subscription_id
    tenant       = var.tenant_id
    rg_name      = local.env_rg_name
    rg_hub       = local.rg_hub
    vnet_key     = local.vnet_key
  }
}

output "features" {
  value = {
    enable_public_features = local.enable_public_features
    enable_hrz_features    = local.enable_hrz_features
    create_aks             = local.create_aks
    deploy_aks_in_env      = local.aks_enabled_env
    sbns1_created          = try(length(module.sbns1)  > 0, false)
    eventhub_created       = try(length(module.eventhub) > 0, false)
    # AKS can exist in exactly one of the three per-env modules
    aks1_created           = (
      try(length(module.aks1_env_shared_nonprod) > 0, false) ||
      try(length(module.aks1_env_prod) > 0, false) ||
      try(length(module.aks1_env_uat) > 0, false)
    )
    postgres_created       = try(length(module.postgres) > 0, false)
    redis_created          = try(length(module.redis1) > 0, false)
    cdbpg_created          = try(length(module.cdbpg1) > 0, false)
    cosmos_created         = try(length(module.cosmos1) > 0, false)
  }
}

output "ids" {
  value = {
    kv1      = try(module.kv1[0].id, null)
    sa1      = try(module.sa1[0].id, null)
    cosmos1  = try(module.cosmos1[0].id, null)
    aks1     = local.aks_id
    aks      = local.aks_id
    sbns1    = try(module.sbns1[0].id, null)
    eventhub = try(module.eventhub[0].id, null)
    postgres = try(module.postgres[0].id, null)
    redis    = try(module.redis1[0].id, null)
    cdbpg1   = try(module.cdbpg1[0].id, null)
    funcapp1   = try(module.funcapp1[0].id, null)
    funcapp2   = try(module.funcapp2[0].id, null)
    plan1_func = try(module.plan1_func[0].id, null)
  }
}

output "aks_id" {
  value = local.aks_enabled_env ? local.aks_id : null
}

output "names" {
  value = {
    kv1           = try(module.kv1[0].name, null)
    sa1           = try(module.sa1[0].name, null)
    cosmos1       = try(module.cosmos1[0].name, null)
    aks1          = local.aks_name
    sbns1         = try(module.sbns1[0].name, null)
    eventhub_ns   = try(module.eventhub[0].namespace_name, null)
    eventhub      = try(module.eventhub[0].eventhub_name, null)
    postgres      = try(module.postgres[0].name, null)
    redis         = try(module.redis1[0].name, null)
    cdbpg1        = try(module.cdbpg1[0].name, null)
    funcapp1      = try(module.funcapp1[0].name, null)
    funcapp2      = try(module.funcapp2[0].name, null)
    plan1_func    = try(module.plan1_func[0].name, null)
  }
}

output "networking" {
  value = {
    pe_subnet_id_effective        = local.pe_subnet_id_effective
    aks_nodepool_subnet_effective = local.aks_nodepool_subnet_effective
    private_dns_zone_ids_used     = local.zone_ids_effective
    aks_private_dns_zone_name     = local.aks_pdns_name
    aks_region_token              = local.aks_region_token
  }
}

output "observability" {
  value = {
    law_workspace_id       = local.law_workspace_id
    appi_connection_string = local.appi_connection_string
    # aks_diag_name          = local.diag_name
    # aks_diag_id            = local.aks_diag_id
  }
}

output "aks" {
  value = local.aks_enabled_env ? {
    id                  = local.aks_id
    name                = local.aks_name
    node_resource_group = local.aks_node_rg
    service_cidr        = local.aks_service_cidr
    dns_service_ip      = local.aks_dns_service_ip
    subscription_id     = local.aks_subscription_id
    tenant_id           = local.aks_tenant_id
    resource_group      = local.aks_rg_name
    provider_alias      = local.aks_provider_alias
  } : null
}

locals {
  _sb_pub_domain = "servicebus.windows.net"
  _sb_gov_domain = "servicebus.usgovcloudapi.net"
  _sb_domain     = var.product == "hrz" ? local._sb_gov_domain : local._sb_pub_domain
}

output "servicebus" {
  value = try({
    id       = module.sbns1[0].id
    name     = module.sbns1[0].name
    sku      = var.servicebus_sku
    capacity = var.servicebus_capacity
    fqdn     = "${module.sbns1[0].name}.${local._sb_domain}"
  }, null)
}

output "event_hubs" {
  value = try({
    namespace_id    = module.eventhub[0].namespace_id
    namespace_name  = module.eventhub[0].namespace_name
    eventhub_name   = module.eventhub[0].eventhub_name
    fqdn            = "${module.eventhub[0].namespace_name}.${local._sb_domain}"
    consumer_groups = try(module.eventhub_cgs[0].consumer_group_names, null)
  }, null)
}

locals {
  _sa_pub_domain = "core.windows.net"
  _sa_gov_domain = "core.usgovcloudapi.net"
  _sa_domain     = var.product == "hrz" ? local._sa_gov_domain : local._sa_pub_domain
}

output "storage_account" {
  value = try({
    id                 = module.sa1[0].id
    name               = module.sa1[0].name
    blob_primary_host  = "${module.sa1[0].name}.blob.${local._sa_domain}"
    file_primary_host  = "${module.sa1[0].name}.file.${local._sa_domain}"
    queue_primary_host = "${module.sa1[0].name}.queue.${local._sa_domain}"
    table_primary_host = "${module.sa1[0].name}.table.${local._sa_domain}"
  }, null)
}

output "key_vault" {
  value = try({
    id        = module.kv1[0].id
    name      = module.kv1[0].name
    vault_uri = try(module.kv1[0].vault_uri, null)
  }, null)
}

locals {
  _cos_pub_domain = "documents.azure.com"
  _cos_gov_domain = "documents.azure.us"
  _cos_domain     = var.product == "hrz" ? local._cos_gov_domain : local._cos_pub_domain
}

output "cosmos_nosql" {
  value = try({
    id        = module.cosmos1[0].id
    name      = module.cosmos1[0].name
    endpoint  = "https://${module.cosmos1[0].name}.${local._cos_domain}:443/"
    database  = try(azurerm_cosmosdb_sql_database.app[0].name, null)
    containers = compact([
      try(azurerm_cosmosdb_sql_container.items[0].name, null),
      try(azurerm_cosmosdb_sql_container.events[0].name, null)
    ])
  }, null)
}

output "postgres" {
  value = try({
    id                  = module.postgres[0].id
    name                = module.postgres[0].name
    fqdn                = try(module.postgres[0].fqdn, null)
    private_dns_zone_id = try(module.postgres[0].private_dns_zone_id, null)
    ha_enabled          = try(module.postgres[0].ha_enabled, null)
  }, null)
}

output "postgres_replica" {
  value = try({
    id   = module.postgres_replica[0].id
    name = module.postgres_replica[0].name
    fqdn = try(module.postgres_replica[0].fqdn, null)
  }, null)
}

output "cosmosdb_postgresql" {
  value = try({
    id   = module.cdbpg1[0].id
    name = module.cdbpg1[0].name
  }, null)
}

output "redis" {
  value = try({
    id       = module.redis1[0].id
    name     = module.redis1[0].name
    hostname = try(module.redis1[0].hostname, null)
    sku_name = try(var.redis_sku_name, null)
    capacity = try(var.redis_capacity, null)
    family   = try(var.redis_sku_family, null)
  }, null)
}

locals {
  _app_pub_domain = "azurewebsites.net"
  _app_gov_domain = "azurewebsites.us"
  _app_domain     = var.product == "hrz" ? local._app_gov_domain : local._app_pub_domain
}

output "app_service_plan" {
  value = try({
    id       = module.plan1_func[0].id
    name     = module.plan1_func[0].name
    sku_name = module.plan1_func[0].sku_name
    os_type  = var.asp_os_type
  }, null)
}

output "function_apps" {
  value = {
    funcapp1 = try({
      id       = module.funcapp1[0].id
      name     = module.funcapp1[0].name
      hostname = "${module.funcapp1[0].name}.${local._app_domain}"
      scm_host = "${module.funcapp1[0].name}.scm.${local._app_domain}"
    }, null)
    funcapp2 = try({
      id       = module.funcapp2[0].id
      name     = module.funcapp2[0].name
      hostname = "${module.funcapp2[0].name}.${local._app_domain}"
      scm_host = "${module.funcapp2[0].name}.scm.${local._app_domain}"
    }, null)
  }
}

output "kubernetes" {
  value = local.aks_enabled_env ? {
    id   = local.aks_id
    name = local.aks_name
  } : null
}

output "nsg_flow_logs_storage" {
  value = try(module.sa_nsg_flowlogs[0].id, null) == null ? null : {
    id    = module.sa_nsg_flowlogs[0].id
    name  = module.sa_nsg_flowlogs[0].name
    rg    = local.shared_np_core_rg_name
    plane = local.plane
  }
}
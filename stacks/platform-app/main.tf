############################################
# terraform & providers
############################################
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.9.0" }
    random  = { source = "hashicorp/random",  version = "~> 3.6" }
  }
}

# ----- Effective subscription selection (env-scoped) -----
locals {
  # env can be: dev|qa|uat|prod  OR  plane-style: np|pr
  env_is_plane_code   = contains(["np","pr"], lower(var.env))
  env_is_standard     = contains(["dev","qa","uat","prod"], lower(var.env))

  # Resolve "plane" and "plane_code"
  plane               = local.env_is_plane_code ? (lower(var.env) == "np" ? "nonprod" : "prod") : (contains(["dev","qa"], lower(var.env)) ? "nonprod" : "prod")
  plane_code          = local.plane == "nonprod" ? "np" : "pr"

  is_dev              = lower(var.env) == "dev"
  is_qa               = lower(var.env) == "qa"
  is_uat              = lower(var.env) == "uat"
  is_prod             = lower(var.env) == "prod"

  # The *workload/env* subscription this run should use (default to var.subscription_id)
  env_subscription_id = (
    local.is_dev  && var.dev_subscription_id  != null ? var.dev_subscription_id  :
    local.is_qa   && var.qa_subscription_id   != null ? var.qa_subscription_id   :
    local.is_uat  && var.uat_subscription_id  != null ? var.uat_subscription_id  :
    local.is_prod && var.prod_subscription_id != null ? var.prod_subscription_id :
    var.subscription_id
  )

  env_tenant_id = (
    local.is_dev  && var.dev_tenant_id  != null ? var.dev_tenant_id  :
    local.is_qa   && var.qa_tenant_id   != null ? var.qa_tenant_id   :
    local.is_uat  && var.uat_tenant_id  != null ? var.uat_tenant_id  :
    local.is_prod && var.prod_tenant_id != null ? var.prod_tenant_id :
    var.tenant_id
  )

  # Hub subscription defaults to "hub_*" variables if set, otherwise env/default
  hub_subscription_id = coalesce(var.hub_subscription_id, var.subscription_id)
  hub_tenant_id       = coalesce(var.hub_tenant_id,       var.tenant_id)

  # Plane-shared run when env is np/pr
  is_plane_shared_run = local.env_is_plane_code
}

# Default provider = ENV/WORKLOAD subscription (dev/qa/uat/prod)
provider "azurerm" {
  features {}
  subscription_id = local.env_subscription_id
  tenant_id       = local.env_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Hub provider = Hub subscription (used whenever we are plane-shared, np/pr)
provider "azurerm" {
  alias           = "hub"
  features        {}
  subscription_id = local.hub_subscription_id
  tenant_id       = local.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

############################################
# env flags, plane, tags
############################################
locals {
  enable_public_features = var.product == "pub"
  enable_hrz_features    = var.product == "hrz"
  enable_both            = local.enable_public_features || local.enable_hrz_features

  uniq    = substr(md5(local.env_subscription_id), 0, 4)

  # Plane computed above; reused here
  vnet_key = (
    local.is_dev  ? "dev_spoke"  :
    local.is_qa   ? "qa_spoke"   :
    local.is_uat  ? "uat_spoke"  : "prod_spoke"
  )

  # aks: dev → nonprod_hub, uat → uat_spoke, prod → prod_spoke, qa → none
  aks_vnet_key_for_subnet = local.is_dev ? "nonprod_hub" : local.is_uat ? "uat_spoke" : local.is_prod ? "prod_spoke" : null

  create_rsv = contains(["dev","prod"], lower(var.env))
  create_aks = lower(var.env) != "qa"
  create_acr = contains(["dev","prod"], lower(var.env))

  # Resource Group selection:
  # - env run (dev/qa/uat/prod): var.rg_name (as before)
  # - plane run (np/pr): use a separate RG in the hub subscription
  rg_plane_default = "rg-${var.product}-${local.plane_code}-${var.region}-platform-01"
  rg_effective     = local.is_plane_shared_run ? coalesce(var.rg_plane_name, local.rg_plane_default) : var.rg_name

  # Tagging
  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }
  env_base_tags      = { env = var.env, lane = local.plane, layer = local.is_plane_shared_run ? "plane-resources" : "env-resources" }
  plane_overlay_tags = local.plane == "nonprod" ? { shared_with = "dev,qa",  criticality = "medium" } : { shared_with = "uat,prod", criticality = "high" }
  runtime_tags       = { managed_by = "terraform", deployed_via = "github-actions" }
  tags_common        = merge(local.org_base_tags, local.env_base_tags, local.plane_overlay_tags, local.runtime_tags)

  tags_kv       = { purpose = "secrets",            service = "key-vault" }
  tags_sa       = { purpose = "storage",            service = "blob,file" }
  tags_cosmos   = { purpose = "database",           service = "cosmosdb" }
  tags_rsv      = { purpose = "backup",             service = "recovery-services-vault" }
  tags_aks      = { purpose = "kubernetes",         service = "aks" }
  tags_acr      = { purpose = "container-registry", service = "acr" }
  tags_postgres = { purpose = "postgres-database",  service = "postgresql" }
  tags_redis    = { purpose = "redis-cache",        service = "redis" }
}

############################################
# remote state (shared-network)
############################################
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = "shared-network/${local.plane}/terraform.tfstate"
  }
}

############################################
# lookups & naming
############################################
locals {
  aks_subnet_ids          = local.aks_vnet_key_for_subnet != null ? try(data.terraform_remote_state.shared.outputs.vnets[local.aks_vnet_key_for_subnet].subnets, {}) : {}
  subnet_ids              = try(data.terraform_remote_state.shared.outputs.vnets[local.vnet_key].subnets, {})
  aks_nodepool_subnet_id  = try(local.aks_subnet_ids["aks${var.product}"], null)
  zone_ids                = try(data.terraform_remote_state.shared.outputs.private_dns_zone_ids_by_name, {})

  sa_suffix_raw   = lower(var.name_suffix)
  sa_suffix_clean = replace(local.sa_suffix_raw, "-", "")
  sa_suffix_short = substr(local.sa_suffix_clean, 0, 6)

  sa1_name  = substr("sa${var.product}${local.plane_code}${var.region}01${local.uniq}", 0, 24)
  aks1_name = "aks-${var.product}-${local.plane_code}-${var.region}-01"

  acr_name          = "acr${var.product}${local.plane_code}${var.region}01"
  acr_pna_effective = lower(var.acr_sku) == "premium" ? var.public_network_access_enabled : true

  deploy_obs = local.is_dev || local.is_prod
}

############################################
# Provider routing helper for modules/resources
############################################
# In plane-shared runs (np/pr), use provider = azurerm.hub; else default azurerm.
locals {
  module_providers_plane = local.is_plane_shared_run ? { azurerm = azurerm.hub } : {}
}

############################################
# key vault (plane-aware)
############################################
locals {
  kv1_base_name    = "kvt-${var.product}-${local.plane_code}-${var.region}-01"
  kv1_name_cleaned = replace(lower(trimspace(local.kv1_base_name)), "-", "")
}

module "kv1" {
  count       = local.enable_both ? 1 : 0
  source      = "../../modules/keyvault"
  providers   = local.module_providers_plane

  name                 = local.kv1_base_name
  location             = var.location
  resource_group_name  = local.rg_effective
  tenant_id            = local.is_plane_shared_run ? local.hub_tenant_id : local.env_tenant_id
  pe_subnet_id         = try(local.subnet_ids["privatelink"], null)
  private_dns_zone_ids = local.zone_ids

  pe_name                = "pep-${local.kv1_name_cleaned}-vault"
  psc_name               = "psc-${local.kv1_name_cleaned}-vault"
  pe_dns_zone_group_name = "pdns-${local.kv1_name_cleaned}-vault"

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  tags                       = merge(local.tags_common, local.tags_kv, var.tags)
}

############################################
# storage account (plane-aware)
############################################
locals { sa1_name_cleaned = replace(lower(trimspace(local.sa1_name)), "-", "") }

module "sa1" {
  count      = local.enable_both ? 1 : 0
  source     = "../../modules/storage-account"
  providers  = local.module_providers_plane

  name                 = local.sa1_name
  location             = var.location
  resource_group_name  = local.rg_effective
  replication_type     = var.sa_replication_type
  container_names      = ["json-image-storage", "video-data"]
  pe_subnet_id         = try(local.subnet_ids["privatelink"], null)
  private_dns_zone_ids = local.zone_ids

  pe_blob_name         = "pep-${local.sa1_name_cleaned}-blob"
  psc_blob_name        = "psc-${local.sa1_name_cleaned}-blob"
  blob_zone_group_name = "pdns-${local.sa1_name_cleaned}-blob"

  pe_file_name         = "pep-${local.sa1_name_cleaned}-file"
  psc_file_name        = "psc-${local.sa1_name_cleaned}-file"
  file_zone_group_name = "pdns-${local.sa1_name_cleaned}-file"

  tags       = merge(local.tags_common, local.tags_sa, var.tags)
  depends_on = [module.kv1]
}

############################################
# cosmos account (pub-only; plane-aware)
############################################
locals {
  cosmos1_name         = "cosno-${var.product}-${local.plane_code}-${var.region}-01"
  cosmos1_name_cleaned = replace(lower(trimspace(local.cosmos1_name)), "-", "")
  cosmos_enabled       = local.enable_public_features
}

module "cosmos1" {
  count      = local.cosmos_enabled ? 1 : 0
  source     = "../../modules/cosmos-account"
  providers  = local.module_providers_plane

  name                 = local.cosmos1_name
  location             = var.location
  resource_group_name  = local.rg_effective
  pe_subnet_id         = try(local.subnet_ids["privatelink"], null)
  private_dns_zone_ids = local.zone_ids

  total_throughput_limit = var.cosno_total_throughput_limit

  pe_sql_name         = "pep-${local.cosmos1_name_cleaned}-sql"
  psc_sql_name        = "psc-${local.cosmos1_name_cleaned}-sql"
  sql_zone_group_name = "pdns-${local.cosmos1_name_cleaned}-sql"

  tags = merge(
    local.tags_common,
    local.tags_cosmos,
    var.tags,
    { workload_purpose = "Stores notification_jobs and notification_history" },
    { workload_description = "Scalable fan-out with dedup via partitioned containers" }
  )

  depends_on = [module.sa1]
}

resource "azurerm_cosmosdb_sql_database" "app" {
  count               = local.cosmos_enabled ? 1 : 0
  name                = "cosnodb-${var.product}"
  resource_group_name = local.rg_effective
  account_name        = local.cosmos1_name
  throughput          = 400
  depends_on          = [module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "items" {
  count                 = local.cosmos_enabled ? 1 : 0
  name                  = "notification_jobs"
  resource_group_name   = local.rg_effective
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/shard_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "events" {
  count                 = local.cosmos_enabled ? 1 : 0
  name                  = "notification_history"
  resource_group_name   = local.rg_effective
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/user_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1]
}

############################################
# aks (env-scoped normally; plane-aware if np/pr)
############################################
locals {
  aks_service_cidr = coalesce(
    var.aks_service_cidr,
    local.is_dev ? "10.120.0.0/16" :
    local.is_prod ? "10.124.0.0/16" :
    "10.125.0.0/16"
  )
  aks_dns_service_ip = coalesce(var.aks_dns_service_ip, cidrhost(local.aks_service_cidr, 10))
  region_nospace     = replace(lower(var.location), " ", "")
  aks_pdns_name      = "privatelink.${local.region_nospace}.azmk8s.io"
}

data "azurerm_private_dns_zone" "aks_pl_zone" {
  provider            = local.is_plane_shared_run ? azurerm.hub : azurerm
  name                = "privatelink.${lower(replace(var.location, " ", ""))}.azmk8s.io"
  resource_group_name = var.shared_network_rg
}

resource "azurerm_user_assigned_identity" "aks" {
  provider            = local.is_plane_shared_run ? azurerm.hub : azurerm
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_effective
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity" }, var.tags)
}

resource "azurerm_role_assignment" "aks_pdz_contrib" {
  provider             = local.is_plane_shared_run ? azurerm.hub : azurerm
  count                = (local.enable_both && local.create_aks) ? 1 : 0
  scope                = data.azurerm_private_dns_zone.aks_pl_zone.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

module "aks1" {
  count      = (local.enable_both && local.create_aks) ? 1 : 0
  source     = "../../modules/aks"
  providers  = local.module_providers_plane

  name                = local.aks1_name
  location            = var.location
  resource_group_name = local.rg_effective
  node_resource_group = "${var.node_resource_group}-01"
  default_nodepool_subnet_id = local.aks_nodepool_subnet_id

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = data.azurerm_private_dns_zone.aks_pl_zone.id
  identity_type             = "UserAssigned"
  user_assigned_identity_id = azurerm_user_assigned_identity.aks.id

  tags = merge(local.tags_common, local.tags_aks, var.tags)
  depends_on = [azurerm_role_assignment.aks_pdz_contrib]
}

locals { manage_aks_diag = (local.enable_both && local.create_aks && local.deploy_obs) }

resource "azurerm_monitor_diagnostic_setting" "aks" {
  provider = local.is_plane_shared_run ? azurerm.hub : azurerm
  for_each = local.manage_aks_diag ? { "aks-diag" = true } : {}
  name                       = "aks-diag"
  target_resource_id         = try(module.aks1[0].id, null)
  log_analytics_workspace_id = try(azurerm_log_analytics_workspace.obs[0].id, null)
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "guard" }
  depends_on = [azurerm_application_insights.obs]
}

############################################
# acr (plane-aware)
############################################
module "acr1" {
  count      = (local.enable_both && local.create_acr) ? 1 : 0
  source     = "../../modules/acr"
  providers  = local.module_providers_plane

  name                          = local.acr_name
  resource_group_name           = local.rg_effective
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = local.acr_pna_effective
  network_rule_bypass_option    = var.acr_network_rule_bypass_option
  anonymous_pull_enabled        = var.acr_anonymous_pull_enabled
  data_endpoint_enabled         = var.acr_data_endpoint_enabled
  zone_redundancy_enabled       = var.acr_zone_redundancy_enabled
  tags                          = merge(local.tags_common, local.tags_acr, var.tags)
}

############################################
# recovery services vault (plane-aware)
############################################
module "rsv1" {
  count      = (local.enable_both && local.create_rsv) ? 1 : 0
  source     = "../../modules/recovery-vault"
  providers  = local.module_providers_plane

  name                = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_effective
  tags                = merge(local.tags_common, local.tags_rsv, var.tags)
}

############################################
# observability (plane-aware)
############################################
resource "azurerm_log_analytics_workspace" "obs" {
  provider            = local.is_plane_shared_run ? azurerm.hub : azurerm
  count               = (local.enable_both && local.deploy_obs) ? 1 : 0
  name                = "law-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_effective
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags = merge(var.tags, {
    env          = var.env
    plane        = local.plane_code
    layer        = local.is_plane_shared_run ? "plane-resources" : "observability"
    service      = "log-analytics"
    purpose      = local.is_dev ? "observability-nonprod" : "observability-prod"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  })
}

resource "azurerm_application_insights" "obs" {
  provider                   = local.is_plane_shared_run ? azurerm.hub : azurerm
  count                      = (local.enable_both && local.deploy_obs) ? 1 : 0
  name                       = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  location                   = var.location
  resource_group_name        = local.rg_effective
  application_type           = "web"
  workspace_id               = azurerm_log_analytics_workspace.obs[count.index].id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags = merge(var.tags, {
    env          = var.env
    plane        = local.plane_code
    layer        = local.is_plane_shared_run ? "plane-resources" : "observability"
    service      = "application-insights"
    purpose      = local.is_dev ? "app-telemetry-nonprod" : "app-telemetry-prod"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  })
}

############################################
# service bus / event hubs (pub-only; plane-aware)
############################################
locals {
  sb_is_premium = lower(var.servicebus_sku) == "premium"
  create_eventhub    = lower(var.env) == "dev" || lower(var.env) == "prod" || local.is_plane_shared_run
  eh1_namespace      = "evhns-${var.product}-${local.plane_code}-${var.region}-01"
  eh1_name_clean     = replace(lower(trimspace(local.eh1_namespace)), "-", "")
  eh1_pe_name        = "pep-${local.eh1_name_clean}-namespace"
  eh1_psc_name       = "psc-${local.eh1_name_clean}-namespace"
  eh1_pdz_group_name = "pdns-${local.eh1_name_clean}-namespace"
}

module "eventhub" {
  count      = (local.enable_public_features && local.create_eventhub) ? 1 : 0
  source     = "../../modules/event-hub"
  providers  = local.module_providers_plane

  namespace_name                = local.eh1_namespace
  eventhub_name                 = "locations-eh"
  location                      = var.location
  resource_group_name           = local.rg_effective
  namespace_sku                 = "Standard"
  namespace_capacity            = 1
  auto_inflate_enabled          = true
  maximum_throughput_units      = 10
  min_tls_version               = "1.2"
  public_network_access_enabled = false
  enable_private_endpoint       = true
  pe_subnet_id                  = local.subnet_ids["privatelink"]
  private_dns_zone_id           = local.zone_ids[var.product == "pub" ? "privatelink.servicebus.windows.net" : "privatelink.servicebus.usgovcloudapi.net"]
  pe_name                       = local.eh1_pe_name
  psc_name                      = local.eh1_psc_name
  pe_zone_group_name            = local.eh1_pdz_group_name
  tags = merge(local.tags_common, { component = "event-hubs" }, var.tags)
  depends_on = [module.sa1]
}

module "eventhub_cgs" {
  count                = (local.enable_public_features && local.create_eventhub) ? 1 : 0
  source               = "../../modules/event-hub-consumer-groups"
  providers            = local.module_providers_plane
  resource_group_name  = local.rg_effective
  namespace_name       = module.eventhub[0].namespace_name
  eventhub_name        = module.eventhub[0].eventhub_name
  consumer_group_names = ["af1-cg", "af2-cg"]
  consumer_group_metadata = { "af1-cg" = "Incident Processor", "af2-cg" = "Location Processor" }
  depends_on = [module.eventhub]
}

############################################
# postgres flex (env-scoped normally; plane-aware if np/pr)
############################################
locals {
  pgflex_subnet_id        = try(local.subnet_ids[var.pg_delegated_subnet_name], null)
  pg_private_zone_id      = try(local.zone_ids["privatelink.postgres.database.azure.com"], null)
  pg_name1                = "pgflex-${var.product}-${local.plane_code}-${var.region}-01"
  pg_geo_backup_effective = (lower(var.env) == "prod") ? true : var.pg_geo_redundant_backup
}

module "postgres" {
  count      = local.enable_public_features ? 1 : 0
  source     = "../../modules/postgres-flex"
  providers  = local.module_providers_plane

  name                = local.pg_name1
  resource_group_name = local.rg_effective
  location            = var.location

  pg_version                   = var.pg_version
  administrator_login_password = var.pg_admin_password
  sku_name                     = var.pg_sku_name
  storage_mb                   = var.pg_storage_mb

  zone       = var.pg_zone
  ha_enabled = var.pg_ha_enabled
  ha_zone    = var.pg_ha_zone

  network_mode        = "private"
  delegated_subnet_id = local.pgflex_subnet_id
  private_dns_zone_id = local.pg_private_zone_id

  aad_auth_enabled             = var.pg_aad_auth_enabled
  aad_tenant_id                = local.is_plane_shared_run ? local.hub_tenant_id : local.env_tenant_id
  geo_redundant_backup_enabled = local.pg_geo_backup_effective

  databases      = var.pg_databases
  firewall_rules = var.pg_firewall_rules
  enable_postgis = var.pg_enable_postgis

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "primary" })
}

module "postgres_replica" {
  count      = (local.enable_both && (var.pg_replica_enabled && !var.pg_ha_enabled)) ? 1 : 0
  source     = "../../modules/postgres-flex"
  providers  = local.module_providers_plane

  name                = local.pg_name1
  resource_group_name = local.rg_effective
  location            = var.location

  pg_version                   = var.pg_version
  administrator_login_password = var.pg_admin_password
  sku_name                     = var.pg_sku_name
  storage_mb                   = var.pg_storage_mb

  network_mode        = "private"
  delegated_subnet_id = local.pgflex_subnet_id
  private_dns_zone_id = local.pg_private_zone_id

  replica_enabled  = true
  source_server_id = module.postgres[0].id

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "replica" })
  depends_on = [module.postgres]
}

############################################
# redis (plane-aware)
############################################
locals {
  redis1_name       = "redis-${var.product}-${local.plane_code}-${var.region}-01-${local.uniq}"
  redis1_name_clean = replace(lower(trimspace(local.redis1_name)), "-", "")
}

module "redis1" {
  count      = local.enable_both ? 1 : 0
  source     = "../../modules/redis"
  providers  = local.module_providers_plane

  name                = local.redis1_name
  location            = var.location
  resource_group_name = local.rg_effective

  sku_name         = var.redis_sku_name
  redis_sku_family = var.redis_sku_family
  capacity         = var.redis_capacity

  pe_subnet_id         = local.subnet_ids["privatelink"]
  private_dns_zone_ids = local.zone_ids

  pe_name         = "pep-${local.redis1_name_clean}-cache"
  psc_name        = "psc-${local.redis1_name_clean}-cache"
  zone_group_name = "pdns-${local.redis1_name_clean}-cache"

  tags = merge(local.tags_common, local.tags_redis, var.tags)
}

############################################
# env rbac (env-scoped only; left as-is)
############################################
locals {
  is_dev_or_qa   = local.is_dev || local.is_qa
  env_to_rg      = { dev = "rg-${var.product}-dev-cus-01", qa = "rg-${var.product}-qa-cus-01" }
  target_rg_name = local.is_dev ? local.env_to_rg.dev : local.is_qa ? local.env_to_rg.qa : null

  dev_team_principals = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
  qa_team_principals  = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
  team_principals     = local.is_dev ? local.dev_team_principals : local.is_qa ? local.qa_team_principals : []
}

data "azurerm_resource_group" "scope" {
  count = local.is_dev_or_qa ? 1 : 0
  name  = local.target_rg_name
}

module "rbac_team_env" {
  count                = (local.enable_both && local.is_dev_or_qa) ? 1 : 0
  source               = "../../modules/rbac"
  scope_id             = data.azurerm_resource_group.scope[0].id
  principal_object_ids = local.team_principals
  role_definition_names = [
    "Azure Kubernetes Service RBAC Cluster Admin",
    "Key Vault Secrets User",
    "Storage Blob Data Contributor",
    "Azure Service Bus Data Owner"
  ]
  depends_on = [module.redis1]
}

############################################
# front door (managed in shared-network RG; not plane-dependent here)
############################################
locals {
  fd_is_nonprod    = local.plane == "nonprod"
  fd_profile_name  = "afd-${var.product}-${local.plane_code}-${var.region}-01"
  fd_endpoint_name = "fde-${var.product}-${local.plane_code}-${var.region}-01"

  fd_plane_overlay_tags = local.fd_is_nonprod ? {
    lane         = "nonprod"
    purpose      = "edge-frontdoor"
    criticality  = "medium"
    layer        = "shared-network"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  } : {
    lane         = "prod"
    purpose      = "edge-frontdoor"
    criticality  = "high"
    layer        = "shared-network"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  }

  fd_tags = merge(
    var.tags,
    local.org_base_tags,
    local.fd_plane_overlay_tags,
    { service = "frontdoor", product = var.product }
  )
}

module "fd" {
  count               = var.fd_create_frontdoor ? 1 : 0
  source              = "../../modules/frontdoor-profile"
  # Front Door lives with shared network RG
  resource_group_name = var.shared_network_rg
  profile_name        = local.fd_profile_name
  endpoint_name       = local.fd_endpoint_name
  sku_name            = var.fd_sku_name
  tags                = local.fd_tags
}

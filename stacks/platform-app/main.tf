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

############################################
# subscription / plane resolution
############################################
locals {
  # env can be: dev|qa|uat|prod  OR  plane-style: np|pr
  env_lc            = lower(var.env)
  env_is_plane_code = contains(["np", "pr"], local.env_lc)

  is_dev  = local.env_lc == "dev"
  is_qa   = local.env_lc == "qa"
  is_uat  = local.env_lc == "uat"
  is_prod = local.env_lc == "prod"

  # Derive plane from env (np/pr or inferred)
  plane      = local.env_is_plane_code ? (local.env_lc == "np" ? "nonprod" : "prod") : (local.is_dev || local.is_qa ? "nonprod" : "prod")
  plane_code = local.plane == "nonprod" ? "np" : "pr"

  # env-scoped subscription/tenant (overrides if provided)
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

  # hub subscription/tenant (for plane-shared runs or hub-scoped resources)
  hub_subscription_id = coalesce(var.hub_subscription_id, var.subscription_id)
  hub_tenant_id       = coalesce(var.hub_tenant_id,       var.tenant_id)

  # when env is np/pr, consider this a plane-shared run
  is_plane_shared_run = local.env_is_plane_code
}

# Default provider = ENV subscription (dev/qa/uat/prod)
provider "azurerm" {
  features {}
  subscription_id = local.env_subscription_id
  tenant_id       = local.env_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Hub provider = HUB subscription (np/pr runs and hub-routed resources)
provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = local.hub_subscription_id
  tenant_id       = local.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

############################################
# flags, naming, tags
############################################
locals {
  enable_public_features = var.product == "pub"
  enable_hrz_features    = var.product == "hrz"
  enable_both            = local.enable_public_features || local.enable_hrz_features

  uniq = substr(md5(local.env_subscription_id), 0, 4)

  vnet_key = (
    local.is_dev  ? "dev_spoke"  :
    local.is_qa   ? "qa_spoke"   :
    local.is_uat  ? "uat_spoke"  : "prod_spoke"
  )

  # aks: dev → nonprod_hub, uat → uat_spoke, prod → prod_spoke, qa → none
  aks_vnet_key_for_subnet = local.is_dev ? "nonprod_hub" : local.is_uat ? "uat_spoke" : local.is_prod ? "prod_spoke" : null

  # honor explicit toggle if provided; else default (no AKS in qa)
  create_aks = var.create_aks == null ? (local.env_lc != "qa") : var.create_aks
  create_rsv = contains(["dev","prod"], local.env_lc)
  # create_acr = contains(["dev","prod"], local.env_lc)

  # RG selection
  rg_plane_default = "rg-${var.product}-${local.plane_code}-${var.region}-platform-01"
  rg_env           = var.rg_name
  rg_hub           = coalesce(var.rg_plane_name, local.rg_plane_default)

  # Where to place which:
  deploy_aks_in_hub = local.is_dev && local.create_aks
  deploy_aks_in_env = (local.is_uat || local.is_prod) && local.create_aks && !local.env_is_plane_code

  # deploy_acr_in_hub = local.create_acr
  deploy_rsv_in_hub = local.create_rsv

  # ENV resources are built only when env is standard (not np/pr)
  allow_env_resources = !local.env_is_plane_code

  # Tags
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
  # tags_acr      = { purpose = "container-registry", service = "acr" }
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

  # acr_name          = "acr${var.product}${local.plane_code}${var.region}01"
  # acr_pna_effective = lower(var.acr_sku) == "premium" ? var.public_network_access_enabled : true

  deploy_obs = local.is_dev || local.is_prod
}

############################################
# AKS PDZ data (provider-bound)
############################################
data "azurerm_private_dns_zone" "aks_pl_zone_env" {
  count               = local.allow_env_resources ? 1 : 0
  provider            = azurerm
  name                = "privatelink.${lower(replace(var.location, " ", ""))}.azmk8s.io"
  resource_group_name = var.shared_network_rg
}
data "azurerm_private_dns_zone" "aks_pl_zone_hub" {
  count               = 1
  provider            = azurerm.hub
  name                = "privatelink.${lower(replace(var.location, " ", ""))}.azmk8s.io"
  resource_group_name = var.shared_network_rg
}
locals {
  # prefer hub PDZ id (AKS is hub-routed in dev), fall back to env PDZ if needed
  aks_pdz_id = try(
    data.azurerm_private_dns_zone.aks_pl_zone_hub[0].id,
    data.azurerm_private_dns_zone.aks_pl_zone_env[0].id,
    null
  )
}

############################################
# Key Vault (ENV only)
############################################
locals {
  kv1_base_name    = "kvt-${var.product}-${local.plane_code}-${var.region}-01"
  kv1_name_cleaned = replace(lower(trimspace(local.kv1_base_name)), "-", "")
}

module "kv1_env" {
  count               = local.allow_env_resources ? 1 : 0
  source              = "../../modules/keyvault"
  providers           = { azurerm = azurerm }

  name                 = local.kv1_base_name
  location             = var.location
  resource_group_name  = var.rg_name
  tenant_id            = local.env_tenant_id
  pe_subnet_id         = try(local.subnet_ids["privatelink"], null)
  private_dns_zone_ids = local.zone_ids

  pe_name                = "pep-${local.kv1_name_cleaned}-vault"
  psc_name               = "psc-${local.kv1_name_cleaned}-vault"
  pe_dns_zone_group_name = "pdns-${local.kv1_name_cleaned}-vault"

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  tags                       = merge(local.tags_common, local.tags_kv, var.tags)
}

locals {
  kv1_id             = try(module.kv1_env[0].id, null)
  kv1_name_effective = try(module.kv1_env[0].name, null)
}

############################################
# Storage Account (ENV only)
############################################
locals { sa1_name_cleaned = replace(lower(trimspace(local.sa1_name)), "-", "") }

module "sa1_env" {
  count               = local.allow_env_resources ? 1 : 0
  source              = "../../modules/storage-account"
  providers           = { azurerm = azurerm }

  name                 = local.sa1_name
  location             = var.location
  resource_group_name  = var.rg_name
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
  depends_on = [module.kv1_env]
}

locals {
  sa1_id             = try(module.sa1_env[0].id, null)
  sa1_name_effective = try(module.sa1_env[0].name, null)
}

############################################
# Cosmos Account (pub only, ENV only) + DB/containers
############################################
locals {
  cosmos_enabled       = local.enable_public_features
  cosmos1_name         = "cosno-${var.product}-${local.plane_code}-${var.region}-01"
  cosmos1_name_cleaned = replace(lower(trimspace(local.cosmos1_name)), "-", "")
}

module "cosmos1_env" {
  count               = (local.cosmos_enabled && local.allow_env_resources) ? 1 : 0
  source              = "../../modules/cosmos-account"
  providers           = { azurerm = azurerm }

  name                 = local.cosmos1_name
  location             = var.location
  resource_group_name  = var.rg_name
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

  depends_on = [module.sa1_env]
}

resource "azurerm_cosmosdb_sql_database" "app_env" {
  count               = (local.cosmos_enabled && local.allow_env_resources) ? 1 : 0
  provider            = azurerm
  name                = "cosnodb-${var.product}"
  resource_group_name = var.rg_name
  account_name        = local.cosmos1_name
  throughput          = 400
  depends_on          = [module.cosmos1_env]
}

resource "azurerm_cosmosdb_sql_container" "items_env" {
  count                 = (local.cosmos_enabled && local.allow_env_resources) ? 1 : 0
  provider              = azurerm
  name                  = "notification_jobs"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app_env[0].name
  partition_key_paths   = ["/shard_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1_env]
}

resource "azurerm_cosmosdb_sql_container" "events_env" {
  count                 = (local.cosmos_enabled && local.allow_env_resources) ? 1 : 0
  provider              = azurerm
  name                  = "notification_history"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app_env[0].name
  partition_key_paths   = ["/user_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1_env]
}

############################################
# AKS (ENV for uat/prod)
############################################
resource "azurerm_user_assigned_identity" "aks_env" {
  count               = local.deploy_aks_in_env ? 1 : 0
  provider            = azurerm
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity" }, var.tags)
}

resource "azurerm_role_assignment" "aks_pdz_contrib_env" {
  count                = local.deploy_aks_in_env ? 1 : 0
  provider             = azurerm
  scope                = local.aks_pdz_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = try(azurerm_user_assigned_identity.aks_env[0].principal_id, null)
}

module "aks1_env" {
  count               = local.deploy_aks_in_env ? 1 : 0
  source              = "../../modules/aks"
  providers           = { azurerm = azurerm }

  name                        = local.aks1_name
  location                    = var.location
  resource_group_name         = var.rg_name
  node_resource_group         = "${var.node_resource_group}-01"
  default_nodepool_subnet_id  = local.aks_nodepool_subnet_id

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = local.aks_pdz_id
  identity_type             = "UserAssigned"
  user_assigned_identity_id = try(azurerm_user_assigned_identity.aks_env[0].id, null)

  tags = merge(local.tags_common, local.tags_aks, var.tags)
  depends_on = [azurerm_role_assignment.aks_pdz_contrib_env]
}

############################################
# AKS (HUB only, dev only)
############################################
locals {
  aks_service_cidr = coalesce(
    var.aks_service_cidr,
    local.is_dev ? "10.120.0.0/16" :
    local.is_prod ? "10.124.0.0/16" :
    "10.125.0.0/16"
  )
  aks_dns_service_ip = coalesce(var.aks_dns_service_ip, cidrhost(local.aks_service_cidr, 10))
}

resource "azurerm_user_assigned_identity" "aks_hub" {
  count               = local.deploy_aks_in_hub ? 1 : 0
  provider            = azurerm.hub
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_hub
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity" }, var.tags)
}

resource "azurerm_role_assignment" "aks_pdz_contrib_hub" {
  count                = local.deploy_aks_in_hub ? 1 : 0
  provider             = azurerm.hub
  scope                = local.aks_pdz_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = try(azurerm_user_assigned_identity.aks_hub[0].principal_id, null)
}

module "aks1_hub" {
  count               = local.deploy_aks_in_hub ? 1 : 0
  source              = "../../modules/aks"
  providers           = { azurerm = azurerm.hub }

  name                = local.aks1_name
  location            = var.location
  resource_group_name = local.rg_hub
  node_resource_group = "${var.node_resource_group}-01"
  default_nodepool_subnet_id = local.aks_nodepool_subnet_id

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = local.aks_pdz_id
  identity_type             = "UserAssigned"
  user_assigned_identity_id = try(azurerm_user_assigned_identity.aks_hub[0].id, null)

  tags = merge(local.tags_common, local.tags_aks, var.tags)
  depends_on = [azurerm_role_assignment.aks_pdz_contrib_hub]
}

locals {
  aks_id   = try(module.aks1_hub[0].id, module.aks1_env[0].id, null)
  aks_name = try(module.aks1_hub[0].name, module.aks1_env[0].name, null)
}

# Observability: hub when AKS-in-hub; else env (when deploy_obs)
resource "azurerm_log_analytics_workspace" "obs_hub" {
  count               = (local.deploy_aks_in_hub && local.deploy_obs) ? 1 : 0
  provider            = azurerm.hub
  name                = "law-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_hub
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags = merge(var.tags, {
    env = var.env, plane = local.plane_code, layer = "plane-resources",
    service = "log-analytics", purpose = "observability-nonprod",
    managed_by = "terraform", deployed_via = "github-actions"
  })
}

resource "azurerm_log_analytics_workspace" "obs_env" {
  count               = (!local.deploy_aks_in_hub && local.deploy_obs && local.allow_env_resources) ? 1 : 0
  provider            = azurerm
  name                = "law-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags = merge(var.tags, {
    env = var.env, plane = local.plane_code, layer = "observability",
    service = "log-analytics", purpose = local.is_dev ? "observability-nonprod" : "observability-prod",
    managed_by = "terraform", deployed_via = "github-actions"
  })
}

locals { law_id = try(azurerm_log_analytics_workspace.obs_hub[0].id, azurerm_log_analytics_workspace.obs_env[0].id, null) }

resource "azurerm_application_insights" "obs_hub" {
  count                      = (local.deploy_aks_in_hub && local.deploy_obs) ? 1 : 0
  provider                   = azurerm.hub
  name                       = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  location                   = var.location
  resource_group_name        = local.rg_hub
  application_type           = "web"
  workspace_id               = local.law_id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags = merge(var.tags, { env = var.env, plane = local.plane_code, layer = "plane-resources",
    service = "application-insights", purpose = "app-telemetry-nonprod",
    managed_by = "terraform", deployed_via = "github-actions" })
}

resource "azurerm_application_insights" "obs_env" {
  count                      = (!local.deploy_aks_in_hub && local.deploy_obs && local.allow_env_resources) ? 1 : 0
  provider                   = azurerm
  name                       = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  location                   = var.location
  resource_group_name        = var.rg_name
  application_type           = "web"
  workspace_id               = local.law_id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags = merge(var.tags, { env = var.env, plane = local.plane_code, layer = "observability",
    service = "application-insights", purpose = local.is_dev ? "app-telemetry-nonprod" : "app-telemetry-prod",
    managed_by = "terraform", deployed_via = "github-actions" })
}

locals {
  appi_conn_str = try(azurerm_application_insights.obs_hub[0].connection_string, azurerm_application_insights.obs_env[0].connection_string, null)
}

resource "azurerm_monitor_diagnostic_setting" "aks_env" {
  count                      = (local.deploy_aks_in_env && local.deploy_obs) ? 1 : 0
  provider                   = azurerm
  name                       = "aks-diag"
  target_resource_id         = local.aks_id
  log_analytics_workspace_id = local.law_id
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "guard" }
  depends_on = [azurerm_application_insights.obs_hub, azurerm_application_insights.obs_env]
}

resource "azurerm_monitor_diagnostic_setting" "aks_hub" {
  count                      = (local.deploy_aks_in_hub && local.deploy_obs) ? 1 : 0
  provider                   = azurerm.hub
  name                       = "aks-diag"
  target_resource_id         = local.aks_id
  log_analytics_workspace_id = local.law_id
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "guard" }
  depends_on = [azurerm_application_insights.obs_hub, azurerm_application_insights.obs_env]
}

############################################
# ACR (HUB only)
############################################
# module "acr1_hub" {
#   count               = local.deploy_acr_in_hub ? 1 : 0
#   source              = "../../modules/acr"
#   providers           = { azurerm = azurerm.hub }

#   name                          = local.acr_name
#   resource_group_name           = local.rg_hub
#   location                      = var.location
#   sku                           = var.acr_sku
#   admin_enabled                 = var.admin_enabled
#   public_network_access_enabled = local.acr_pna_effective
#   network_rule_bypass_option    = var.acr_network_rule_bypass_option
#   anonymous_pull_enabled        = var.acr_anonymous_pull_enabled
#   data_endpoint_enabled         = var.acr_data_endpoint_enabled
#   zone_redundancy_enabled       = var.acr_zone_redundancy_enabled
#   tags                          = merge(local.tags_common, local.tags_acr, var.tags)
# }

# locals {
#   acr_id          = try(module.acr1_hub[0].id, null)
#   acr_loginserver = try(module.acr1_hub[0].login_server, null)
# }

############################################
# RSV (HUB only)
############################################
module "rsv1_hub" {
  count               = local.deploy_rsv_in_hub ? 1 : 0
  source              = "../../modules/recovery-vault"
  providers           = { azurerm = azurerm.hub }
  name                = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_hub
  tags                = merge(local.tags_common, local.tags_rsv, var.tags)
}

locals {
  rsv1_id   = try(module.rsv1_hub[0].id, null)
  rsv1_name = try(module.rsv1_hub[0].name, null)
}

############################################
# Event Hubs (pub only, ENV only)
############################################
locals {
  sb_is_premium        = lower(var.servicebus_sku) == "premium"
  create_eventhub      = local.enable_public_features && local.allow_env_resources && (local.env_lc == "dev" || local.env_lc == "prod")
  eh1_namespace        = "evhns-${var.product}-${local.plane_code}-${var.region}-01"
  eh1_name_clean       = replace(lower(trimspace(local.eh1_namespace)), "-", "")
  eh1_pe_name          = "pep-${local.eh1_name_clean}-namespace"
  eh1_psc_name         = "psc-${local.eh1_name_clean}-namespace"
  eh1_pdz_group_name   = "pdns-${local.eh1_name_clean}-namespace"
  eh_private_zone_name = var.product == "pub" ? "privatelink.servicebus.windows.net" : "privatelink.servicebus.usgovcloudapi.net"
}

module "eventhub_env" {
  count                         = local.create_eventhub ? 1 : 0
  source                        = "../../modules/event-hub"
  providers                     = { azurerm = azurerm }
  namespace_name                = local.eh1_namespace
  eventhub_name                 = "locations-eh"
  location                      = var.location
  resource_group_name           = var.rg_name
  namespace_sku                 = "Standard"
  namespace_capacity            = 1
  auto_inflate_enabled          = true
  maximum_throughput_units      = 10
  min_tls_version               = "1.2"
  public_network_access_enabled = false
  enable_private_endpoint       = true
  pe_subnet_id                  = local.subnet_ids["privatelink"]
  private_dns_zone_id           = local.zone_ids[local.eh_private_zone_name]
  pe_name                       = local.eh1_pe_name
  psc_name                      = local.eh1_psc_name
  pe_zone_group_name            = local.eh1_pdz_group_name
  tags = merge(local.tags_common, { component = "event-hubs" }, var.tags)
  depends_on = [module.sa1_env]
}

module "eventhub_cgs_env" {
  count                   = local.create_eventhub ? 1 : 0
  source                  = "../../modules/event-hub-consumer-groups"
  providers               = { azurerm = azurerm }
  resource_group_name     = var.rg_name
  namespace_name          = module.eventhub_env[0].namespace_name
  eventhub_name           = module.eventhub_env[0].eventhub_name
  consumer_group_names    = ["af1-cg", "af2-cg"]
  consumer_group_metadata = { "af1-cg" = "Incident Processor", "af2-cg" = "Location Processor" }
  depends_on              = [module.eventhub_env]
}

############################################
# Postgres Flexible (ENV only)
############################################
locals {
  pgflex_subnet_id        = try(local.subnet_ids[var.pg_delegated_subnet_name], null)
  pg_private_zone_id      = try(local.zone_ids["privatelink.postgres.database.azure.com"], null)
  pg_name1                = "pgflex-${var.product}-${local.plane_code}-${var.region}-01"
  pg_geo_backup_effective = local.is_prod ? true : var.pg_geo_redundant_backup
}

module "postgres_env" {
  count               = (local.enable_public_features && local.allow_env_resources) ? 1 : 0
  source              = "../../modules/postgres-flex"
  providers           = { azurerm = azurerm }

  name                = local.pg_name1
  resource_group_name = var.rg_name
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
  aad_tenant_id                = local.env_tenant_id
  geo_redundant_backup_enabled = local.pg_geo_backup_effective

  databases      = var.pg_databases
  firewall_rules = var.pg_firewall_rules
  enable_postgis = var.pg_enable_postgis

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "primary" })
}

module "postgres_replica_env" {
  count               = (local.allow_env_resources && (var.pg_replica_enabled && !var.pg_ha_enabled)) ? 1 : 0
  source              = "../../modules/postgres-flex"
  providers           = { azurerm = azurerm }
  name                = local.pg_name1
  resource_group_name = var.rg_name
  location            = var.location
  pg_version                   = var.pg_version
  administrator_login_password = var.pg_admin_password
  sku_name                     = var.pg_sku_name
  storage_mb                   = var.pg_storage_mb
  network_mode        = "private"
  delegated_subnet_id = local.pgflex_subnet_id
  private_dns_zone_id = local.pg_private_zone_id
  replica_enabled  = true
  source_server_id = module.postgres_env[0].id
  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "replica" })
  depends_on = [module.postgres_env]
}

locals {
  pg_id   = try(module.postgres_env[0].id, null)
  pg_name = try(module.postgres_env[0].name, null)
  pg_fqdn = try(module.postgres_env[0].fqdn, null)
}

############################################
# Redis (ENV only)
############################################
locals {
  redis1_name       = "redis-${var.product}-${local.plane_code}-${var.region}-01-${local.uniq}"
  redis1_name_clean = replace(lower(trimspace(local.redis1_name)), "-", "")
}
module "redis1_env" {
  count               = local.allow_env_resources ? 1 : 0
  source              = "../../modules/redis"
  providers           = { azurerm = azurerm }
  name                = local.redis1_name
  location            = var.location
  resource_group_name = var.rg_name

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

locals {
  redis_id       = try(module.redis1_env[0].id, null)
  redis_name     = try(module.redis1_env[0].name, null)
  redis_hostname = try(module.redis1_env[0].hostname, null)
}

############################################
# RBAC (ENV only)
############################################
# locals {
#   is_dev_or_qa   = local.is_dev || local.is_qa
#   env_to_rg      = { dev = "rg-${var.product}-dev-cus-01", qa = "rg-${var.product}-qa-cus-01" }
#   target_rg_name = local.is_dev ? local.env_to_rg.dev : local.is_qa ? local.env_to_rg.qa : null

#   dev_team_principals = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
#   qa_team_principals  = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
#   team_principals     = local.is_dev ? local.dev_team_principals : local.is_qa ? local.qa_team_principals : []
# }

# data "azurerm_resource_group" "scope" {
#   count = (local.is_dev_or_qa && local.allow_env_resources) ? 1 : 0
#   name  = local.target_rg_name
# }

# module "rbac_team_env" {
#   count                = (local.enable_both && local.is_dev_or_qa && local.allow_env_resources) ? 1 : 0
#   source               = "../../modules/rbac"
#   scope_id             = data.azurerm_resource_group.scope[0].id
#   principal_object_ids = local.team_principals
#   role_definition_names = [
#     "Azure Kubernetes Service RBAC Cluster Admin",
#     "Key Vault Secrets User",
#     "Storage Blob Data Contributor",
#     "Azure Service Bus Data Owner"
#   ]
#   depends_on = [module.redis1_env]
# }

############################################
# Front Door (unchanged; lives with shared network RG)
############################################
locals {
  fd_profile_name  = "afd-${var.product}-${local.plane_code}-${var.region}-01"
  fd_endpoint_name = "fde-${var.product}-${local.plane_code}-${var.region}-01"
  fd_tags = merge(
    var.tags,
    local.org_base_tags,
    { lane = local.plane, purpose = "edge-frontdoor", layer = "shared-network",
      service = "frontdoor", product = var.product, managed_by = "terraform", deployed_via = "github-actions" }
  )
}

module "fd" {
  count               = var.fd_create_frontdoor ? 1 : 0
  source              = "../../modules/frontdoor-profile"
  resource_group_name = var.shared_network_rg
  profile_name        = local.fd_profile_name
  endpoint_name       = local.fd_endpoint_name
  sku_name            = var.fd_sku_name
  tags                = local.fd_tags
}
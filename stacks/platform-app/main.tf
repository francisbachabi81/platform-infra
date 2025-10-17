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

# ENV subscription (dev/qa/uat/prod)
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# HUB subscription (shared resources like dev AKS, RSV, ACR)
provider "azurerm" {
  alias           = "hub"
  # features        = {}
  subscription_id = coalesce(var.hub_subscription_id, var.subscription_id)
  tenant_id       = coalesce(var.hub_tenant_id, var.tenant_id)
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

############################################
# env flags, plane, tags
############################################
locals {
  enable_public_features = var.product == "pub"
  enable_hrz_features    = var.product == "hrz"
  enable_both            = local.enable_public_features || local.enable_hrz_features

  uniq    = substr(md5(var.subscription_id), 0, 4)
  is_dev  = var.env == "dev"
  is_qa   = var.env == "qa"
  is_uat  = var.env == "uat"
  is_prod = var.env == "prod"

  plane      = contains(["dev","qa"], var.env) ? "nonprod" : "prod"
  plane_code = local.plane == "nonprod" ? "np" : "pr"

  # Which vnet group would supply subnets if foundation is present?
  vnet_key = (
    var.env == "dev"  ? "dev_spoke"  :
    var.env == "qa"   ? "qa_spoke"   :
    var.env == "uat"  ? "uat_spoke"  : "prod_spoke"
  )
  # AKS placement rule: dev → HUB (shared); uat/prod → ENV (env-specific); qa → none
  aks_vnet_key_for_subnet = local.is_dev ? "nonprod_hub" : local.is_uat ? "uat_spoke" : local.is_prod ? "prod_spoke" : null

  # feature toggles
  create_rsv = contains(["dev","prod"], var.env)
  create_aks = var.env != "qa"
  create_acr = contains(["dev","prod"], var.env)
  deploy_obs = local.is_dev || local.is_prod

  # foundation policy
  want_foundation = var.require_foundation

  # names
  sa_suffix_raw   = lower(var.name_suffix)
  sa_suffix_clean = replace(local.sa_suffix_raw, "-", "")
  sa_suffix_short = substr(local.sa_suffix_clean, 0, 6)

  sa1_name  = substr("sa${var.product}${var.env}${var.region}01${local.uniq}", 0, 24)
  aks1_name = "aks-${var.product}-${local.plane_code}-${var.region}-01"

  acr_name          = "acr${var.product}${local.plane_code}${var.region}01"
  acr_pna_effective = lower(var.acr_sku) == "premium" ? var.public_network_access_enabled : true

  # Hub “platform” RG for shared (non-network) resources
  rg_hub = coalesce(var.rg_plane_name, "rg-${var.product}-${local.plane_code}-${var.region}-platform-01")

  # tags
  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }
  env_base_tags      = { env = var.env, lane = local.plane, layer = "env-resources" }
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
# Remote state (shared-network) — Azure AD auth
############################################
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = "shared-network/${local.plane}/terraform.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}

############################################
# Foundation inputs (subnets & PDZs) with guards
############################################
locals {
  _subnet_ids_raw = try(data.terraform_remote_state.shared.outputs.vnets[local.vnet_key].subnets, null)
  _zone_ids_raw   = try(data.terraform_remote_state.shared.outputs.private_dns_zone_ids_by_name, null)

  subnet_ids = local.want_foundation ? coalesce(local._subnet_ids_raw, tomap({})) : tomap({})
  zone_ids   = local.want_foundation ? coalesce(local._zone_ids_raw,   tomap({})) : tomap({})

  aks_nodepool_subnet_id = try(local.subnet_ids["aks${var.product}"], null)
  pe_subnet_id           = try(local.subnet_ids["privatelink"], null)

  region_nospace   = replace(lower(var.location), " ", "")
  aks_pdns_name    = "privatelink.${local.region_nospace}.azmk8s.io"
  foundation_ready = local.want_foundation && length(local.subnet_ids) > 0 && length(local.zone_ids) > 0
}

check "foundation_subnets_present" {
  assert {
    condition     = !local.want_foundation || (local._subnet_ids_raw != null && length(local._subnet_ids_raw) > 0)
    error_message = "require_foundation=true but no subnets were found for '${local.vnet_key}' in shared-network state."
  }
}
check "foundation_pdz_present" {
  assert {
    condition     = !local.want_foundation || (local._zone_ids_raw != null && length(local._zone_ids_raw) > 0)
    error_message = "require_foundation=true but private DNS zone IDs were not found in shared-network state."
  }
}

############################################
# Key Vault (ENV)
############################################
locals {
  kv1_base_name    = "kvt-${var.product}-${var.env}-${var.region}-01"
  kv1_name_cleaned = replace(lower(trimspace(local.kv1_base_name)), "-", "")
}

module "kv1" {
  count                = local.enable_both ? 1 : 0
  source               = "../../modules/keyvault"
  name                 = local.kv1_base_name
  location             = var.location
  resource_group_name  = var.rg_name
  tenant_id            = var.tenant_id
  pe_subnet_id         = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids = local.foundation_ready ? local.zone_ids : {}
  pe_name                = "pep-${local.kv1_name_cleaned}-vault"
  psc_name               = "psc-${local.kv1_name_cleaned}-vault"
  pe_dns_zone_group_name = "pdns-${local.kv1_name_cleaned}-vault"
  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  tags                       = merge(local.tags_common, local.tags_kv, var.tags)
}

############################################
# Storage Account (ENV)
############################################
locals { sa1_name_cleaned = replace(lower(trimspace(local.sa1_name)), "-", "") }

module "sa1" {
  count                = local.enable_both ? 1 : 0
  source               = "../../modules/storage-account"
  name                 = local.sa1_name
  location             = var.location
  resource_group_name  = var.rg_name
  replication_type     = var.sa_replication_type
  container_names      = ["json-image-storage", "video-data"]
  pe_subnet_id         = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids = local.foundation_ready ? local.zone_ids : {}
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
# Cosmos (NoSQL) (ENV)
############################################
locals {
  cosmos1_name         = "cosno-${var.product}-${var.env}-${var.region}-01"
  cosmos1_name_cleaned = replace(lower(trimspace(local.cosmos1_name)), "-", "")
  cosmos_enabled       = local.enable_public_features
}

module "cosmos1" {
  count                = local.cosmos_enabled ? 1 : 0
  source               = "../../modules/cosmos-account"
  name                 = local.cosmos1_name
  location             = var.location
  resource_group_name  = var.rg_name
  pe_subnet_id         = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids = local.foundation_ready ? local.zone_ids : {}
  total_throughput_limit = var.cosno_total_throughput_limit
  pe_sql_name         = "pep-${local.cosmos1_name_cleaned}-sql"
  psc_sql_name        = "psc-${local.cosmos1_name_cleaned}-sql"
  sql_zone_group_name = "pdns-${local.cosmos1_name_cleaned}-sql"
  tags = merge(local.tags_common, local.tags_cosmos, var.tags, {
    workload_purpose     = "Stores notification_jobs and notification_history"
    workload_description = "Scalable fan-out with dedup via partitioned containers"
  })
  depends_on = [module.sa1]
}

resource "azurerm_cosmosdb_sql_database" "app" {
  count               = local.cosmos_enabled ? 1 : 0
  name                = "cosnodb-${var.product}"
  resource_group_name = var.rg_name
  account_name        = local.cosmos1_name
  throughput          = 400
  depends_on          = [module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "items" {
  count                 = local.cosmos_enabled ? 1 : 0
  name                  = "notification_jobs"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/shard_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "events" {
  count                 = local.cosmos_enabled ? 1 : 0
  name                  = "notification_history"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/user_id"]
  partition_key_version = 2
  depends_on            = [module.cosmos1]
}

############################################
# AKS (shared in DEV via HUB; env-specific in UAT/PROD)
############################################
locals {
  aks_service_cidr = coalesce(
    var.aks_service_cidr,
    local.is_dev ? "10.120.0.0/16" :
    local.is_prod ? "10.124.0.0/16" :
    "10.125.0.0/16"
  )
  aks_dns_service_ip = coalesce(var.aks_dns_service_ip, cidrhost(local.aks_service_cidr, 10))

  # Placement toggles (no conditionals in provider args)
  deploy_aks_in_hub = local.is_dev  && local.enable_both && local.create_aks && local.foundation_ready
  deploy_aks_in_env = (local.is_uat || local.is_prod) && local.enable_both && local.create_aks && local.foundation_ready
}

# ---------- Identity ----------
resource "azurerm_user_assigned_identity" "aks_hub" {
  count               = local.deploy_aks_in_hub ? 1 : 0
  provider            = azurerm.hub
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_hub
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity", layer = "plane-resources" }, var.tags)
}

resource "azurerm_user_assigned_identity" "aks_env" {
  count               = local.deploy_aks_in_env ? 1 : 0
  provider            = azurerm
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity" }, var.tags)
}

# ---------- PDZ Role Assignment ----------
resource "azurerm_role_assignment" "aks_pdz_contrib_hub" {
  count                = local.deploy_aks_in_hub ? 1 : 0
  provider             = azurerm.hub
  scope                = try(local.zone_ids[local.aks_pdns_name], null)
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_hub[0].principal_id

  lifecycle {
    precondition {
      condition     = try(local.zone_ids[local.aks_pdns_name], null) != null
      error_message = "AKS PDZ '${local.aks_pdns_name}' not found in zone_ids."
    }
  }
}

resource "azurerm_role_assignment" "aks_pdz_contrib_env" {
  count                = local.deploy_aks_in_env ? 1 : 0
  provider             = azurerm
  scope                = try(local.zone_ids[local.aks_pdns_name], null)
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_env[0].principal_id

  lifecycle {
    precondition {
      condition     = try(local.zone_ids[local.aks_pdns_name], null) != null
      error_message = "AKS PDZ '${local.aks_pdns_name}' not found in zone_ids."
    }
  }
}

# ---------- AKS Cluster ----------
module "aks1_hub" {
  count     = (local.deploy_aks_in_hub && local.aks_nodepool_subnet_id != null) ? 1 : 0
  source    = "../../modules/aks"
  providers = { azurerm = azurerm.hub }

  name                        = local.aks1_name
  location                    = var.location
  resource_group_name         = local.rg_hub
  node_resource_group         = "${var.node_resource_group}-01"
  default_nodepool_subnet_id  = local.aks_nodepool_subnet_id

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = local.zone_ids[local.aks_pdns_name]
  identity_type             = "UserAssigned"
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_hub[0].id

  tags       = merge(local.tags_common, local.tags_aks, var.tags, { layer = "plane-resources" })
  depends_on = [azurerm_role_assignment.aks_pdz_contrib_hub]
}

module "aks1_env" {
  count    = (local.deploy_aks_in_env && local.aks_nodepool_subnet_id != null) ? 1 : 0
  source   = "../../modules/aks"

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

  private_dns_zone_id       = local.zone_ids[local.aks_pdns_name]
  identity_type             = "UserAssigned"
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_env[0].id

  tags       = merge(local.tags_common, local.tags_aks, var.tags)
  depends_on = [azurerm_role_assignment.aks_pdz_contrib_env]
}

# Unified AKS refs
locals {
  aks_id   = try(module.aks1_hub[0].id, module.aks1_env[0].id, null)
  aks_name = try(module.aks1_hub[0].name, module.aks1_env[0].name, null)
}

############################################
# Observability (ENV)
############################################
resource "azurerm_log_analytics_workspace" "obs" {
  count               = (local.enable_both && local.deploy_obs) ? 1 : 0
  name                = "law-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags = merge(var.tags, {
    env          = var.env
    plane        = local.plane_code
    layer        = "observability"
    service      = "log-analytics"
    purpose      = local.is_dev ? "observability-nonprod" : "observability-prod"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  })
}

resource "azurerm_application_insights" "obs" {
  count                      = (local.enable_both && local.deploy_obs) ? 1 : 0
  name                       = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  location                   = var.location
  resource_group_name        = var.rg_name
  application_type           = "web"
  workspace_id               = azurerm_log_analytics_workspace.obs[count.index].id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags = merge(var.tags, {
    env          = var.env
    plane        = local.plane_code
    layer        = "observability"
    service      = "application-insights"
    purpose      = local.is_dev ? "app-telemetry-nonprod" : "app-telemetry-prod"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  })
}

locals { manage_aks_diag = (local.enable_both && local.create_aks && local.deploy_obs && local.foundation_ready) }

resource "azurerm_monitor_diagnostic_setting" "aks" {
  for_each = local.manage_aks_diag ? { "aks-diag" = true } : {}
  name                       = "aks-diag"
  target_resource_id         = local.aks_id
  log_analytics_workspace_id = try(azurerm_log_analytics_workspace.obs[0].id, null)
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "guard" }
  depends_on = [azurerm_application_insights.obs]
}

############################################
# ACR (SHARED → HUB)
############################################
module "acr1" {
  count               = (local.enable_both && local.create_acr) ? 1 : 0
  source              = "../../modules/acr"
  providers           = { azurerm = azurerm.hub }
  name                = local.acr_name
  resource_group_name = local.rg_hub
  location            = var.location
  sku                           = var.acr_sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = local.acr_pna_effective
  network_rule_bypass_option    = var.acr_network_rule_bypass_option
  anonymous_pull_enabled        = var.acr_anonymous_pull_enabled
  data_endpoint_enabled         = var.acr_data_endpoint_enabled
  zone_redundancy_enabled       = var.acr_zone_redundancy_enabled
  tags                          = merge(local.tags_common, local.tags_acr, var.tags, { layer = "plane-resources" })
}

############################################
# Recovery Services Vault (SHARED → HUB)
############################################
module "rsv1" {
  count               = (local.enable_both && local.create_rsv) ? 1 : 0
  source              = "../../modules/recovery-vault"
  providers           = { azurerm = azurerm.hub }
  name                = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.rg_hub
  tags                = merge(local.tags_common, local.tags_rsv, var.tags, { layer = "plane-resources" })
}

############################################
# Service Bus (ENV) – Premium uses private endpoints
############################################
locals { sb_is_premium = lower(var.servicebus_sku) == "premium" }

module "sbns1" {
  count  = (local.enable_both && var.create_servicebus) ? 1 : 0
  source = "../../modules/servicebus"

  name                = "svb-${var.product}-${var.env}-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name

  sku                           = var.servicebus_sku
  capacity                      = var.servicebus_capacity
  zone_redundant                = local.sb_is_premium
  min_tls_version               = var.servicebus_min_tls_version
  public_network_access_enabled = local.sb_is_premium ? false : true
  local_auth_enabled            = var.servicebus_local_auth_enabled

  queues = var.servicebus_queues
  topics = var.servicebus_topics

  privatelink_subnet_id = (local.sb_is_premium && local.foundation_ready) ? local.pe_subnet_id : null
  private_dns_zone_id   = (local.sb_is_premium && local.foundation_ready) ? try(local.zone_ids[var.product == "pub" ? "privatelink.servicebus.windows.net" : "privatelink.servicebus.usgovcloudapi.net"], null) : null

  manage_policy_name = var.servicebus_manage_policy_name
  tags = merge(local.tags_common, { component = "servicebus" }, {
    workload_purpose     = "Captures poison messages or failed notifications"
    workload_description = "Durable failure isolation for retry/audit"
  })
}

############################################
# App Service Plan + Function Apps (ENV)
############################################
module "plan1_func" {
  count               = local.enable_public_features ? 1 : 0
  source              = "../../modules/app-service-plan"
  name                = "asp-${var.product}-${var.env}-${var.region}-01"
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = var.asp_os_type
  sku_name            = var.func_linux_plan_sku_name
  tags                = merge(local.tags_common, { component = "app-service-plan", os = "linux" }, var.tags)
}

locals {
  funcapp1_name       = "func-${var.product}-${var.env}-${var.region}-01"
  funcapp1_name_clean = replace(lower(trimspace(local.funcapp1_name)), "-", "")
  funcapp2_name       = "func-${var.product}-${var.env}-${var.region}-02"
  funcapp2_name_clean = replace(lower(trimspace(local.funcapp2_name)), "-", "")
}

module "funcapp1" {
  count                      = local.enable_public_features ? 1 : 0
  source                     = "../../modules/function-app"
  name                       = local.funcapp1_name
  location                   = var.location
  resource_group_name        = var.rg_name
  service_plan_id            = module.plan1_func[0].id
  plan_sku_name              = module.plan1_func[0].sku_name
  storage_account_name       = module.sa1[0].name
  storage_account_access_key = module.sa1[0].primary_access_key

  vnet_integration_subnet_id = try(local.subnet_ids["appsvc-int-linux-01"], null)
  pe_subnet_id               = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids       = local.foundation_ready ? local.zone_ids : {}

  enable_private_endpoint     = local.foundation_ready
  enable_scm_private_endpoint = local.foundation_ready

  pe_site_name         = "pep-${local.funcapp1_name_clean}-site"
  psc_site_name        = "psc-${local.funcapp1_name_clean}-site"
  site_zone_group_name = "pdns-${local.funcapp1_name_clean}-site"
  pe_scm_name          = "pep-${local.funcapp1_name_clean}-scm"
  psc_scm_name         = "psc-${local.funcapp1_name_clean}-scm"
  scm_zone_group_name  = "pdns-${local.funcapp1_name_clean}-scm"

  stack = { node_version = "20" }
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  application_insights_connection_string = local.deploy_obs ? azurerm_application_insights.obs[0].connection_string : null
  tags = merge(local.tags_common, { component = "function-app", os = "linux" }, local.deploy_obs ? { "hidden-link: /app-insights-resource-id" = azurerm_application_insights.obs[0].id } : {}, var.tags)
}

module "funcapp2" {
  count                      = local.enable_public_features ? 1 : 0
  source                     = "../../modules/function-app"
  name                       = local.funcapp2_name
  location                   = var.location
  resource_group_name        = var.rg_name
  service_plan_id            = module.plan1_func[0].id
  plan_sku_name              = module.plan1_func[0].sku_name
  storage_account_name       = module.sa1[0].name
  storage_account_access_key = module.sa1[0].primary_access_key

  vnet_integration_subnet_id = try(local.subnet_ids["appsvc-int-linux-01"], null)
  pe_subnet_id               = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids       = local.foundation_ready ? local.zone_ids : {}

  enable_private_endpoint     = local.foundation_ready
  enable_scm_private_endpoint = local.foundation_ready

  pe_site_name         = "pep-${local.funcapp2_name_clean}-site"
  psc_site_name        = "psc-${local.funcapp2_name_clean}-site"
  site_zone_group_name = "pdns-${local.funcapp2_name_clean}-site"
  pe_scm_name          = "pep-${local.funcapp2_name_clean}-scm"
  psc_scm_name         = "psc-${local.funcapp2_name_clean}-scm"
  scm_zone_group_name  = "pdns-${local.funcapp2_name_clean}-scm"

  stack = { node_version = "20" }
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  application_insights_connection_string = local.deploy_obs ? azurerm_application_insights.obs[0].connection_string : null
  tags = merge(local.tags_common, { component = "function-app", os = "linux" }, local.deploy_obs ? { "hidden-link: /app-insights-resource-id" = azurerm_application_insights.obs[0].id } : {}, var.tags)
}

############################################
# Event Hubs (ENV)
############################################
locals {
  create_eventhub      = var.env == "dev" || var.env == "prod"
  eh1_namespace        = "evhns-${var.product}-${local.plane_code}-${var.region}-01"
  eh1_name_clean       = replace(lower(trimspace(local.eh1_namespace)), "-", "")
  eh1_pe_name          = "pep-${local.eh1_name_clean}-namespace"
  eh1_psc_name         = "psc-${local.eh1_name_clean}-namespace"
  eh1_pdz_group_name   = "pdns-${local.eh1_name_clean}-namespace"
  eh_private_zone_name = var.product == "pub" ? "privatelink.servicebus.windows.net" : "privatelink.servicebus.usgovcloudapi.net"
}

module "eventhub" {
  count                         = (local.enable_public_features && local.create_eventhub) ? 1 : 0
  source                        = "../../modules/event-hub"
  namespace_name                = local.eh1_namespace
  eventhub_name                 = "locations-eh"
  location                      = var.location
  resource_group_name           = var.rg_name
  namespace_sku                 = var.servicebus_sku
  namespace_capacity            = var.servicebus_capacity
  auto_inflate_enabled          = true
  maximum_throughput_units      = 10
  min_tls_version               = var.servicebus_min_tls_version
  public_network_access_enabled = false
  enable_private_endpoint       = local.foundation_ready
  pe_subnet_id                  = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_id           = local.foundation_ready ? try(local.zone_ids[local.eh_private_zone_name], null) : null
  pe_name                       = local.eh1_pe_name
  psc_name                      = local.eh1_psc_name
  pe_zone_group_name            = local.eh1_pdz_group_name
  tags = merge(local.tags_common, { component = "event-hubs" }, var.tags)
  depends_on = [module.funcapp2]
}

module "eventhub_cgs" {
  count                   = (local.enable_public_features && local.create_eventhub) ? 1 : 0
  source                  = "../../modules/event-hub-consumer-groups"
  resource_group_name     = var.rg_name
  namespace_name          = module.eventhub[0].namespace_name
  eventhub_name           = module.eventhub[0].eventhub_name
  consumer_group_names    = ["af1-cg", "af2-cg"]
  consumer_group_metadata = { "af1-cg" = "Incident Processor", "af2-cg" = "Location Processor" }
  depends_on              = [module.eventhub]
}

############################################
# Cosmos DB for PostgreSQL (Citus) (ENV)
############################################
locals {
  cdbpg_name         = "cdbpg-${var.product}-${var.env}-${var.region}-01"
  cdbpg_name_cleaned = replace(lower(trimspace(local.cdbpg_name)), "-", "")
}

module "cdbpg1" {
  count  = (local.enable_both && var.create_cdbpg) ? 1 : 0
  source = "../../modules/cosmosdb-postgresql"

  name                = local.cdbpg_name
  location            = var.location
  resource_group_name = var.rg_name

  coordinator_vcore_count         = var.cdbpg_coordinator_vcore_count
  coordinator_storage_quota_in_mb = var.cdbpg_coordinator_storage_quota_in_mb
  coordinator_server_edition      = var.cdbpg_coordinator_server_edition

  node_count               = var.cdbpg_node_count
  node_vcore_count         = var.cdbpg_node_vcore_count
  node_server_edition      = var.cdbpg_node_server_edition
  node_storage_quota_in_mb = var.cdbpg_node_storage_quota_in_mb

  citus_version              = var.cdbpg_citus_version
  preferred_primary_zone     = var.cdbpg_preferred_primary_zone
  administrator_login_password = var.cdbpg_admin_password

  enable_private_endpoint = local.foundation_ready && var.cdbpg_enable_private_endpoint
  privatelink_subnet_id   = local.foundation_ready ? try(local.subnet_ids["privatelink-cdbpg"], null) : null
  private_dns_zone_id     = local.foundation_ready ? try(local.zone_ids["privatelink.postgres.cosmos.azure.com"], null) : null

  pe_coordinator_name         = "pep-${local.cdbpg_name_cleaned}-coordinator"
  psc_coordinator_name        = "psc-${local.cdbpg_name_cleaned}-coordinator"
  coordinator_zone_group_name = "pdns-${local.cdbpg_name_cleaned}-coordinator"

  tags = merge(local.tags_common, { component = "cosmosdb-postgresql" })
}

############################################
# Postgres Flexible (ENV)
############################################
locals {
  pgflex_subnet_id        = try(local.subnet_ids[var.pg_delegated_subnet_name], null)
  pg_private_zone_id      = try(local.zone_ids["privatelink.postgres.database.azure.com"], null)
  pg_name1                = "pgflex-${var.product}-${var.env}-${var.region}-01"
  pg_geo_backup_effective = var.env == "prod" ? true : var.pg_geo_redundant_backup
}

module "postgres" {
  count               = local.enable_public_features ? 1 : 0
  source              = "../../modules/postgres-flex"
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
  delegated_subnet_id = local.foundation_ready ? local.pgflex_subnet_id : null
  private_dns_zone_id = local.foundation_ready ? local.pg_private_zone_id : null

  aad_auth_enabled             = var.pg_aad_auth_enabled
  aad_tenant_id                = var.tenant_id
  geo_redundant_backup_enabled = local.pg_geo_backup_effective

  databases      = var.pg_databases
  firewall_rules = var.pg_firewall_rules
  enable_postgis = var.pg_enable_postgis

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "primary" })
}

module "postgres_replica" {
  count  = (local.enable_both && (var.pg_replica_enabled && !var.pg_ha_enabled)) ? 1 : 0
  source = "../../modules/postgres-flex"

  name                = local.pg_name1
  resource_group_name = var.rg_name
  location            = var.location

  pg_version                   = var.pg_version
  administrator_login_password = var.pg_admin_password
  sku_name                     = var.pg_sku_name
  storage_mb                   = var.pg_storage_mb

  network_mode        = "private"
  delegated_subnet_id = local.foundation_ready ? local.pgflex_subnet_id : null
  private_dns_zone_id = local.foundation_ready ? local.pg_private_zone_id : null

  replica_enabled  = true
  source_server_id = module.postgres[0].id

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "replica" })
  depends_on = [module.postgres]
}

############################################
# Redis (ENV)
############################################
locals {
  redis1_name       = "redis-${var.product}-${var.env}-${var.region}-01-${local.uniq}"
  redis1_name_clean = replace(lower(trimspace(local.redis1_name)), "-", "")
}

module "redis1" {
  count               = local.enable_both ? 1 : 0
  source              = "../../modules/redis"
  name                = local.redis1_name
  location            = var.location
  resource_group_name = var.rg_name

  sku_name         = var.redis_sku_name
  redis_sku_family = var.redis_sku_family
  capacity         = var.redis_capacity

  pe_subnet_id         = local.foundation_ready ? local.pe_subnet_id : null
  private_dns_zone_ids = local.foundation_ready ? local.zone_ids : {}

  pe_name         = "pep-${local.redis1_name_clean}-cache"
  psc_name        = "psc-${local.redis1_name_clean}-cache"
  zone_group_name = "pdns-${local.redis1_name_clean}-cache"

  tags = merge(local.tags_common, local.tags_redis, var.tags)
}

############################################
# Env RBAC (dev/qa) (ENV)
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
# Front Door (shared-network RG; ENV-neutral config stays as-is)
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
  resource_group_name = var.shared_network_rg
  profile_name        = local.fd_profile_name
  endpoint_name       = local.fd_endpoint_name
  sku_name            = var.fd_sku_name
  tags                = local.fd_tags
}
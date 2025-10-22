# Providers
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.9.0" }
    random  = { source = "hashicorp/random",  version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = coalesce(var.hub_subscription_id, var.subscription_id)
  tenant_id       = coalesce(var.hub_tenant_id,       var.tenant_id)
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Env flags, naming, tags
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

  vnet_key = (
    var.env == "dev"  ? "dev_spoke"  :
    var.env == "qa"   ? "qa_spoke"   :
    var.env == "uat"  ? "uat_spoke"  : "prod_spoke"
  )

  sa_suffix_raw   = lower(var.name_suffix)
  sa_suffix_clean = replace(local.sa_suffix_raw, "-", "")
  sa_suffix_short = substr(local.sa_suffix_clean, 0, 6)

  sa1_name  = substr("sa${var.product}${var.env}${var.region}01${local.uniq}", 0, 24)
  aks1_name = "aks-${var.product}-${local.plane_code}-${var.region}-100"

  rg_hub = coalesce(var.rg_plane_name, "rg-${var.product}-${local.plane_code}-${var.region}-core-01")

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
  tags_aks      = { purpose = "kubernetes",         service = "aks" }
  tags_postgres = { purpose = "postgres-database",  service = "postgresql" }
  tags_redis    = { purpose = "redis-cache",        service = "redis" }

  create_aks = var.create_aks == null ? (var.env != "qa") : var.create_aks
}

# Remote state: shared-network + core
data "terraform_remote_state" "shared" {
  count   = var.shared_state_enabled ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = "shared-network/${var.product}/${local.plane}/terraform.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}

data "terraform_remote_state" "core" {
  count   = var.core_state_enabled ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = coalesce(var.core_state_key, "core/${var.product}/${local.plane_code}/terraform.tfstate")
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}

# Effective networking + observability inputs
locals {
  shared_defaults = {
    vnets       = {}
    private_dns = { zone_ids_by_name = {}, zone_ids = {} }
  }

  rs_outputs = merge(
    local.shared_defaults,
    try(data.terraform_remote_state.shared[0].outputs, {})
  )

  subnet_ids_from_state = try(local.rs_outputs.vnets[local.vnet_key].subnets, {})
  # zone_ids_from_state   = try(local.rs_outputs.private_dns_zone_ids_by_name, {})
  zone_ids_from_state = coalesce(
    try(local.rs_outputs.private_dns.zone_ids_by_name, null),
    try(local.rs_outputs.private_dns_zone_ids_by_name,  null), # legacy
    {}
  )

  zone_ids_effective            = length(var.private_dns_zone_ids) > 0 ? var.private_dns_zone_ids : local.zone_ids_from_state
  pe_subnet_id_effective = (
    var.pe_subnet_id != null && trimspace(var.pe_subnet_id) != ""
  ) ? var.pe_subnet_id : try(local.subnet_ids_from_state["privatelink"], null)

  aks_nodepool_subnet_effective = (
    var.aks_nodepool_subnet_id != null && trimspace(var.aks_nodepool_subnet_id) != ""
  ) ? var.aks_nodepool_subnet_id : try(local.subnet_ids_from_state["aks${var.product}"], null)

  _loc_lower = lower(var.location)
  _reg_lower = lower(var.region)

  aks_gov_region_by_code = { usaz = "usgovarizona", usva = "usgovvirginia" }
  _is_az = length(regexall("arizona",  local._loc_lower))  > 0
  _is_va = length(regexall("virginia", local._loc_lower))  > 0

  aks_region_token = local.enable_hrz_features ? coalesce(
    lookup(local.aks_gov_region_by_code, local._reg_lower, null),
    local._is_az ? "usgovarizona" : null,
    local._is_va ? "usgovvirginia" : null
  ) : null

  region_nospace = replace(lower(var.location), " ", "")

  aks_pdns_name = local.enable_hrz_features ? format("privatelink.%s.cx.aks.containerservice.azure.us", local.aks_region_token) : format("privatelink.%s.azmk8s.io", local.region_nospace)

  core_defaults = { observability = { law_workspace_id = null, appi_connection_string = null } }
  core_outputs  = merge(local.core_defaults, try(data.terraform_remote_state.core[0].outputs, {}))

  law_workspace_id        = var.law_workspace_id_override        != null ? var.law_workspace_id_override        : try(local.core_outputs.observability.law_workspace_id, null)
  appi_connection_string  = var.appi_connection_string_override  != null ? var.appi_connection_string_override  : try(local.core_outputs.observability.appi_connection_string, null)

  deploy_aks_in_hub = local.is_dev && local.enable_both && local.create_aks
  deploy_aks_in_env = (local.is_uat || local.is_prod) && local.enable_both && local.create_aks

  dev_only_tags  = { environment = "dev",  purpose = "env-dev",  criticality = "Low",    patchgroup = "Test",    lane = "nonprod" }
  qa_only_tags   = { environment = "qa",   purpose = "env-qa",   criticality = "Medium", patchgroup = "Test",    lane = "nonprod" }
  uat_only_tags  = { environment = "uat",  purpose = "env-uat",  criticality = "Medium", patchgroup = "Monthly", lane = "prod" }
  prod_only_tags = { environment = "prod", purpose = "env-prod", criticality = "High",   patchgroup = "Monthly", lane = "prod" }

  is_nonprod = local.plane == "nonprod"

  rg_layer_by_key = local.is_nonprod ? {
    nphub = "shared-network"
    dev   = "platform-dev"
    qa    = "platform-qa"
  } : {
    prhub = "shared-network"
    prod  = "platform-prod"
    uat   = "platform-uat"
  }
}

module "rg_dev" {
  count     = local.is_dev ? 1 : 0
  source    = "../../modules/resource-group"
  name      = "rg-${var.product}-${var.env}-${var.region}-01"
  location  = var.location
  tags      = merge(local.tags_common, local.dev_only_tags, { layer = local.rg_layer_by_key["dev"] })
}

module "rg_qa" {
  count     = local.is_qa ? 1 : 0
  source    = "../../modules/resource-group"
  name      = "rg-${var.product}-${var.env}-${var.region}-01"
  location  = var.location
  tags      = merge(local.tags_common, local.qa_only_tags, { layer = local.rg_layer_by_key["qa"] })
}

module "rg_prod" {
  count     = local.is_prod ? 1 : 0
  source    = "../../modules/resource-group"
  name      = "rg-${var.product}-${var.env}-${var.region}-01"
  location  = var.location
  tags      = merge(local.tags_common, local.prod_only_tags, { layer = local.rg_layer_by_key["prod"] })
}

module "rg_uat" {
  count     = local.is_uat ? 1 : 0
  source    = "../../modules/resource-group"
  name      = "rg-${var.product}-${var.env}-${var.region}-01"
  location  = var.location
  tags      = merge(local.tags_common, local.uat_only_tags, { layer = local.rg_layer_by_key["uat"] })
}

data "azurerm_resource_group" "env" {
  name = var.rg_name
  depends_on = [
    module.rg_dev,
    module.rg_qa,
    module.rg_uat,
    module.rg_prod
  ]
}

check "gov_region_supported" {
  assert {
    condition     = !local.enable_hrz_features || local.aks_region_token != null
    error_message = "Unsupported Azure Gov location/region. Use region 'usaz'/'usva' or location including 'Arizona'/'Virginia'."
  }
}

# Fail-fast checks
check "private_net_basics_present" {
  assert {
    condition     = !var.require_private_networking || (local.pe_subnet_id_effective != null && length(local.zone_ids_effective) > 0)
    error_message = "Private networking required, but pe_subnet_id and/or private_dns_zone_ids are missing."
  }
}

check "aks_requires_subnet" {
  assert {
    condition     = !local.create_aks || local.aks_nodepool_subnet_effective != null
    error_message = "AKS requested but no nodepool subnet found."
  }
}

check "aks_pdz_exists" {
  assert {
    condition     = !local.create_aks || try(local.zone_ids_effective[local.aks_pdns_name], null) != null
    error_message = "AKS PDZ '${local.aks_pdns_name}' not found."
  }
}

# Key Vault (env)
locals {
  kv1_base_name    = "kvt-${var.product}-${var.env}-${var.region}-100"
  kv1_name_cleaned = replace(lower(trimspace(local.kv1_base_name)), "-", "")
}

module "kv1" {
  count                = local.enable_both ? 1 : 0
  source               = "../../modules/keyvault"
  name                 = local.kv1_base_name
  location             = var.location
  resource_group_name  = var.rg_name
  tenant_id            = var.tenant_id
  pe_subnet_id         = local.pe_subnet_id_effective
  private_dns_zone_ids = local.zone_ids_effective

  pe_name                = "pep-${local.kv1_name_cleaned}-vault"
  psc_name               = "psc-${local.kv1_name_cleaned}-vault"
  pe_dns_zone_group_name = "pdns-${local.kv1_name_cleaned}-vault"

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  tags = merge(local.tags_common, local.tags_kv, var.tags)

  depends_on = [data.azurerm_resource_group.env]
}

# Storage Account (env)
locals { sa1_name_cleaned = replace(lower(trimspace(local.sa1_name)), "-", "") }

module "sa1" {
  count                = local.enable_both ? 1 : 0
  source               = "../../modules/storage-account"
  name                 = local.sa1_name
  location             = var.location
  resource_group_name  = var.rg_name
  replication_type     = var.sa_replication_type
  container_names      = ["json-image-storage", "video-data"]
  pe_subnet_id         = local.pe_subnet_id_effective
  private_dns_zone_ids = local.zone_ids_effective

  pe_blob_name         = "pep-${local.sa1_name_cleaned}-blob"
  psc_blob_name        = "psc-${local.sa1_name_cleaned}-blob"
  blob_zone_group_name = "pdns-${local.sa1_name_cleaned}-blob"
  pe_file_name         = "pep-${local.sa1_name_cleaned}-file"
  psc_file_name        = "psc-${local.sa1_name_cleaned}-file"
  file_zone_group_name = "pdns-${local.sa1_name_cleaned}-file"

  tags       = merge(local.tags_common, local.tags_sa, var.tags)
  depends_on = [data.azurerm_resource_group.env, module.kv1]
}

# Cosmos (NoSQL) (env)
locals {
  cosmos1_name         = "cosno-${var.product}-${var.env}-${var.region}-100"
  cosmos1_name_cleaned = replace(lower(trimspace(local.cosmos1_name)), "-", "")
  cosmos_enabled       = local.enable_public_features
}

module "cosmos1" {
  count                  = local.enable_public_features ? 1 : 0
  source                 = "../../modules/cosmos-account"
  name                   = local.cosmos1_name
  location               = var.location
  resource_group_name    = var.rg_name
  pe_subnet_id           = local.pe_subnet_id_effective
  private_dns_zone_ids   = local.zone_ids_effective
  total_throughput_limit = var.cosno_total_throughput_limit

  pe_sql_name         = "pep-${local.cosmos1_name_cleaned}-sql"
  psc_sql_name        = "psc-${local.cosmos1_name_cleaned}-sql"
  sql_zone_group_name = "pdns-${local.cosmos1_name_cleaned}-sql"

  tags = merge(local.tags_common, local.tags_cosmos, var.tags, {
    workload_purpose     = "Stores notification_jobs and notification_history"
    workload_description = "Scalable fan-out with dedup via partitioned containers"
  })
  depends_on = [data.azurerm_resource_group.env, module.sa1]
}

resource "azurerm_cosmosdb_sql_database" "app" {
  count               = local.enable_public_features ? 1 : 0
  name                = "cosnodb-${var.product}"
  resource_group_name = var.rg_name
  account_name        = local.cosmos1_name
  throughput          = 400
  depends_on          = [data.azurerm_resource_group.env, module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "items" {
  count                 = local.enable_public_features ? 1 : 0
  name                  = "notification_jobs"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/shard_id"]
  partition_key_version = 2
  depends_on            = [data.azurerm_resource_group.env, module.cosmos1]
}

resource "azurerm_cosmosdb_sql_container" "events" {
  count                 = local.enable_public_features ? 1 : 0
  name                  = "notification_history"
  resource_group_name   = var.rg_name
  account_name          = local.cosmos1_name
  database_name         = azurerm_cosmosdb_sql_database.app[0].name
  partition_key_paths   = ["/user_id"]
  partition_key_version = 2
  depends_on            = [data.azurerm_resource_group.env, module.cosmos1]
}

# AKS (dev in hub; uat/prod in env)
locals {
  aks_service_cidr = coalesce(
    var.aks_service_cidr,
    local.is_dev ? "10.120.0.0/16" :
    local.is_prod ? "10.124.0.0/16" : "10.125.0.0/16"
  )
  aks_dns_service_ip = coalesce(var.aks_dns_service_ip, cidrhost(local.aks_service_cidr, 10))
}

resource "azurerm_user_assigned_identity" "aks_hub" {
  count               = local.deploy_aks_in_hub ? 1 : 0
  provider            = azurerm.hub
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-100"
  location            = var.location
  resource_group_name = local.rg_hub
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity", layer = "plane-resources" }, var.tags)
}

resource "azurerm_user_assigned_identity" "aks_env" {
  count               = local.deploy_aks_in_env ? 1 : 0
  provider            = azurerm
  name                = "uai-${var.product}-${local.plane_code}-aks-${var.region}-100"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = merge(local.tags_common, { purpose = "aks-control-plane-identity" }, var.tags)
  depends_on          = [data.azurerm_resource_group.env]
}

resource "azurerm_role_assignment" "aks_pdz_contrib_hub" {
  count                = local.deploy_aks_in_hub ? 1 : 0
  provider             = azurerm.hub
  scope                = try(local.zone_ids_effective[local.aks_pdns_name], null)
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_hub[0].principal_id
  lifecycle {
    precondition {
      condition     = try(local.zone_ids_effective[local.aks_pdns_name], null) != null
      error_message = "AKS PDZ '${local.aks_pdns_name}' not found."
    }
  }
  depends_on          = [data.azurerm_resource_group.env]
}

resource "azurerm_role_assignment" "aks_pdz_contrib_env" {
  count                = local.deploy_aks_in_env ? 1 : 0
  provider             = azurerm
  scope                = try(local.zone_ids_effective[local.aks_pdns_name], null)
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_env[0].principal_id
  lifecycle {
    precondition {
      condition     = try(local.zone_ids_effective[local.aks_pdns_name], null) != null
      error_message = "AKS PDZ '${local.aks_pdns_name}' not found."
    }
  }
  depends_on          = [data.azurerm_resource_group.env]
}

module "aks1_hub" {
  count     = local.deploy_aks_in_hub ? 1 : 0
  source    = "../../modules/aks"
  providers = { azurerm = azurerm.hub }

  name                        = local.aks1_name
  location                    = var.location
  resource_group_name         = local.rg_hub
  node_resource_group         = "rg-${var.product}-${local.plane_code}-${var.region}-aksn-01"
  default_nodepool_subnet_id  = local.aks_nodepool_subnet_effective

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = try(local.zone_ids_effective[local.aks_pdns_name], null)
  identity_type             = "UserAssigned"
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_hub[0].id

  tags       = merge(local.tags_common, local.tags_aks, var.tags, { layer = "plane-resources" })
  depends_on = [azurerm_role_assignment.aks_pdz_contrib_hub]
}

module "aks1_env" {
  count   = local.deploy_aks_in_env ? 1 : 0
  source  = "../../modules/aks"

  name                        = local.aks1_name
  location                    = var.location
  resource_group_name         = var.rg_name
  node_resource_group         = "rg-${var.product}-${var.env}-${var.region}-aksn-01"
  default_nodepool_subnet_id  = local.aks_nodepool_subnet_effective

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  node_count         = var.aks_node_count
  sku_tier           = var.aks_sku_tier

  pod_cidr       = var.aks_pod_cidr
  service_cidr   = local.aks_service_cidr
  dns_service_ip = local.aks_dns_service_ip

  private_dns_zone_id       = try(local.zone_ids_effective[local.aks_pdns_name], null)
  identity_type             = "UserAssigned"
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_env[0].id

  tags       = merge(local.tags_common, local.tags_aks, var.tags)
  depends_on          = [data.azurerm_resource_group.env, azurerm_role_assignment.aks_pdz_contrib_env]
}

locals {
  aks_id   = try(module.aks1_hub[0].id, module.aks1_env[0].id, null)
  aks_name = try(module.aks1_hub[0].name, module.aks1_env[0].name, null)
}

# Diagnostics (AKS → LA)
# locals { manage_aks_diag = local.enable_both && local.create_aks && local.aks_id != null && local.law_workspace_id != null }

locals {
  want_aks_diag = local.create_aks  # plan-known flag
  diag_name = "aks-diag-${var.product}-${local.plane_code}-${var.region}"
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  for_each                   = local.want_aks_diag ? toset([local.diag_name]) : toset([])
  name                       = each.key
  target_resource_id         = local.aks_id
  log_analytics_workspace_id = local.law_workspace_id
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "guard" }

  depends_on = [module.aks1_hub, module.aks1_env]

  lifecycle {
    precondition {
      condition     = local.aks_id != null && local.law_workspace_id != null
      error_message = "AKS diagnostics requires AKS id and Log Analytics workspace id."
    }
  }
}

# Service Bus (env)
locals { sb_is_premium = lower(var.servicebus_sku) == "premium" }

module "sbns1" {
  count  = (local.enable_both && var.create_servicebus) ? 1 : 0
  source = "../../modules/servicebus"

  name                = "svb-${var.product}-${var.env}-${var.region}-100"
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

  privatelink_subnet_id = local.sb_is_premium ? local.pe_subnet_id_effective : null
  private_dns_zone_id   = local.sb_is_premium ? try(local.zone_ids_effective[var.product == "pub" ? "privatelink.servicebus.windows.net" : "privatelink.servicebus.usgovcloudapi.net"], null) : null

  manage_policy_name = var.servicebus_manage_policy_name

  tags = merge(local.tags_common, { component = "servicebus" }, {
    workload_purpose     = "Captures poison messages or failed notifications"
    workload_description = "Durable failure isolation for retry/audit"
  })
  depends_on  = [data.azurerm_resource_group.env]
}

# App Service Plan + Function Apps (env)
module "plan1_func" {
  count               = local.enable_public_features ? 1 : 0
  source              = "../../modules/app-service-plan"
  name                = "asp-${var.product}-${var.env}-${var.region}-100"
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = var.asp_os_type
  sku_name            = var.func_linux_plan_sku_name
  tags                = merge(local.tags_common, { component = "app-service-plan", os = "linux" }, var.tags)

  depends_on  = [data.azurerm_resource_group.env]
}

locals {
  funcapp1_name       = "func-${var.product}-${var.env}-${var.region}-100"
  funcapp1_name_clean = replace(lower(trimspace(local.funcapp1_name)), "-", "")
  funcapp2_name       = "func-${var.product}-${var.env}-${var.region}-102"
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

  vnet_integration_subnet_id = try(local.subnet_ids_from_state["appsvc-int-linux-01"], null)
  pe_subnet_id               = local.pe_subnet_id_effective
  private_dns_zone_ids       = local.zone_ids_effective

  enable_private_endpoint     = local.pe_subnet_id_effective != null
  enable_scm_private_endpoint = local.pe_subnet_id_effective != null

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

  application_insights_connection_string = local.appi_connection_string
  tags = merge(local.tags_common, { component = "function-app", os = "linux" }, var.tags)

  depends_on  = [data.azurerm_resource_group.env, module.plan1_func, module.sa1]
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

  vnet_integration_subnet_id = try(local.subnet_ids_from_state["appsvc-int-linux-01"], null)
  pe_subnet_id               = local.pe_subnet_id_effective
  private_dns_zone_ids       = local.zone_ids_effective

  enable_private_endpoint     = local.pe_subnet_id_effective != null
  enable_scm_private_endpoint = local.pe_subnet_id_effective != null

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

  application_insights_connection_string = local.appi_connection_string
  tags = merge(local.tags_common, { component = "function-app", os = "linux" }, var.tags)

  depends_on  = [data.azurerm_resource_group.env, module.plan1_func, module.sa1, module.funcapp1]
}

# Event Hubs (env)
locals {
  create_eventhub      = var.env == "dev" || var.env == "prod"
  eh1_namespace        = "evhns-${var.product}-${local.plane_code}-${var.region}-100"
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
  enable_private_endpoint       = local.pe_subnet_id_effective != null
  pe_subnet_id                  = local.pe_subnet_id_effective
  private_dns_zone_id           = try(local.zone_ids_effective[local.eh_private_zone_name], null)
  pe_name                       = local.eh1_pe_name
  psc_name                      = local.eh1_psc_name
  pe_zone_group_name            = local.eh1_pdz_group_name
  tags                          = merge(local.tags_common, { component = "event-hubs" }, var.tags)
  depends_on                    = [data.azurerm_resource_group.env, module.funcapp2]
}

module "eventhub_cgs" {
  count                   = (local.enable_public_features && local.create_eventhub) ? 1 : 0
  source                  = "../../modules/event-hub-consumer-groups"
  resource_group_name     = var.rg_name
  namespace_name          = module.eventhub[0].namespace_name
  eventhub_name           = module.eventhub[0].eventhub_name
  consumer_group_names    = ["af1-cg", "af2-cg"]
  consumer_group_metadata = { "af1-cg" = "Incident Processor", "af2-cg" = "Location Processor" }
  depends_on              = [data.azurerm_resource_group.env, module.eventhub]
}

# Cosmos DB for PostgreSQL (Citus) (env)
locals {
  cdbpg_name         = "cdbpg-${var.product}-${var.env}-${var.region}-100"
  cdbpg_name_cleaned = replace(lower(trimspace(local.cdbpg_name)), "-", "")
}

module "cdbpg1" {
  count  = (var.product == "pub" && var.create_cdbpg) ? 1 : 0
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

  citus_version                = var.cdbpg_citus_version
  preferred_primary_zone       = var.cdbpg_preferred_primary_zone
  administrator_login_password = var.cdbpg_admin_password

  enable_private_endpoint = var.cdbpg_enable_private_endpoint && local.pe_subnet_id_effective != null
  privatelink_subnet_id   = local.pe_subnet_id_effective
  private_dns_zone_id     = try(local.zone_ids_effective["privatelink.postgres.cosmos.azure.com"], null)

  pe_coordinator_name         = "pep-${local.cdbpg_name_cleaned}-coordinator"
  psc_coordinator_name        = "psc-${local.cdbpg_name_cleaned}-coordinator"
  coordinator_zone_group_name = "pdns-${local.cdbpg_name_cleaned}-coordinator"

  tags = merge(local.tags_common, { component = "cosmosdb-postgresql" }, var.tags)

  depends_on  = [data.azurerm_resource_group.env]
}

# PostgreSQL Flexible (env)
locals {
  pgflex_subnet_id        = try(local.subnet_ids_from_state[var.pg_delegated_subnet_name], null)
  pg_private_zone_id      = try(local.zone_ids_effective["privatelink.postgres.database.azure.com"], null)
  pg_name1                = "pgflex-${var.product}-${var.env}-${var.region}-100"
  pg_geo_backup_effective = var.env == "prod" ? true : var.pg_geo_redundant_backup
}

module "postgres" {
  count               = local.enable_both ? 1 : 0
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
  delegated_subnet_id = coalesce(local.pgflex_subnet_id, var.pg_delegated_subnet_id, null)
  private_dns_zone_id = local.pg_private_zone_id

  aad_auth_enabled             = var.pg_aad_auth_enabled
  aad_tenant_id                = var.tenant_id
  geo_redundant_backup_enabled = local.pg_geo_backup_effective

  databases      = var.pg_databases
  firewall_rules = var.pg_firewall_rules
  enable_postgis = var.pg_enable_postgis

  tags = merge(local.tags_common, local.tags_postgres, var.tags, { role = "primary" })

  depends_on  = [data.azurerm_resource_group.env]
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
  delegated_subnet_id = coalesce(local.pgflex_subnet_id, var.pg_delegated_subnet_id, null)
  private_dns_zone_id = local.pg_private_zone_id

  replica_enabled  = true
  source_server_id = module.postgres[0].id

  tags       = merge(local.tags_common, local.tags_postgres, var.tags, { role = "replica" })
  depends_on  = [data.azurerm_resource_group.env, module.postgres]
}

# Redis (env)
locals {
  redis1_name       = "redis-${var.product}-${var.env}-${var.region}-100-${local.uniq}"
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

  pe_subnet_id         = local.pe_subnet_id_effective
  private_dns_zone_ids = local.zone_ids_effective

  pe_name         = "pep-${local.redis1_name_clean}-cache"
  psc_name        = "psc-${local.redis1_name_clean}-cache"
  zone_group_name = "pdns-${local.redis1_name_clean}-cache"

  tags = merge(local.tags_common, local.tags_redis, var.tags)

  depends_on  = [data.azurerm_resource_group.env]
}

# ############################################
# # env rbac (example: dev/qa)
# ############################################
# locals {
#   is_dev_or_qa   = local.is_dev || local.is_qa
#   env_to_rg      = { dev = "rg-${var.product}-dev-cus-01", qa = "rg-${var.product}-qa-cus-01" }
#   target_rg_name = local.is_dev ? local.env_to_rg.dev : local.is_qa ? local.env_to_rg.qa : null
#
#   dev_team_principals = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
#   qa_team_principals  = ["e7d56a14-7c2d-4802-827b-bc81db286bf0"]
#   team_principals     = local.is_dev ? local.dev_team_principals : local.is_qa ? local.qa_team_principals : []
# }
#
# data "azurerm_resource_group" "scope" {
#   count = local.is_dev_or_qa ? 1 : 0
#   name  = local.target_rg_name
# }
#
# module "rbac_team_env" {
#   count                 = (local.enable_both && local.is_dev_or_qa) ? 1 : 0
#   source                = "../../modules/rbac"
#   scope_id              = data.azurerm_resource_group.scope[0].id
#   principal_object_ids  = local.team_principals
#   role_definition_names = [
#     "Azure Kubernetes Service RBAC Cluster Admin",
#     "Key Vault Secrets User",
#     "Storage Blob Data Contributor",
#     "Azure Service Bus Data Owner"
#   ]
#   depends_on = [module.redis1]
# }
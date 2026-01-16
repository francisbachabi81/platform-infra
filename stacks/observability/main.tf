# Environment / plane resolution and base naming
locals {
  env_norm   = var.env == null ? null : lower(var.env)
  plane_norm = var.plane == null ? null : lower(var.plane)

  env_effective = coalesce(
    local.env_norm,
    local.plane_norm == "nonprod" ? "dev" :
    local.plane_norm == "prod"    ? "prod" :
    "dev"
  )

  plane_effective = coalesce(
    local.plane_norm,
    contains(["dev", "qa"], local.env_effective) ? "nonprod" : "prod"
  )

  plane_full = local.plane_effective
  plane_code = local.plane_effective == "nonprod" ? "np" : "pr"

  activity_alert_location = "Global"
  ag_name_default         = "ag-obs-${var.product}-${local.env_effective}-${var.region}-01"
}

# Base provider and remote state
# Remote state
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg
    storage_account_name = var.state_sa
    container_name       = var.state_container
    key                  = "shared-network/${var.product}/${local.plane_full}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "core" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg
    storage_account_name = var.state_sa
    container_name       = var.state_container
    key                  = "core/${var.product}/${local.plane_code}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg
    storage_account_name = var.state_sa
    container_name       = var.state_container
    key                  = "platform-app/${var.product}/${local.env_effective}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Base provider (default)
provider "azurerm" {
  features {}

  subscription_id = coalesce(
    try(data.terraform_remote_state.platform.outputs.meta.subscription, null),
    var.subscription_id
  )

  tenant_id = coalesce(
    try(data.terraform_remote_state.platform.outputs.meta.tenant, null),
    var.tenant_id
  )

  environment = var.product == "hrz" ? "usgovernment" : "public"
}

# Subscription / tenant resolution and provider aliases
locals {
  product_env = var.product == "hrz" ? "usgovernment" : "public"

  core_sub    = trimspace(coalesce(var.core_subscription_id, var.subscription_id))
  core_tenant = trimspace(coalesce(var.core_tenant_id,     var.tenant_id))

  env_sub    = trimspace(coalesce(var.env_subscription_id, var.subscription_id))
  env_tenant = trimspace(coalesce(var.env_tenant_id, var.tenant_id))
}

locals {
  dev_sub  = (var.dev_subscription_id  != null && trimspace(var.dev_subscription_id)  != "") ? var.dev_subscription_id  : var.core_subscription_id
  dev_ten  = (var.dev_tenant_id        != null && trimspace(var.dev_tenant_id)        != "") ? var.dev_tenant_id        : var.core_tenant_id

  qa_sub   = (var.qa_subscription_id   != null && trimspace(var.qa_subscription_id)   != "") ? var.qa_subscription_id   : var.core_subscription_id
  qa_ten   = (var.qa_tenant_id         != null && trimspace(var.qa_tenant_id)         != "") ? var.qa_tenant_id         : var.core_tenant_id

  uat_sub  = (var.uat_subscription_id  != null && trimspace(var.uat_subscription_id)  != "") ? var.uat_subscription_id  : var.core_subscription_id
  uat_ten  = (var.uat_tenant_id        != null && trimspace(var.uat_tenant_id)        != "") ? var.uat_tenant_id        : var.core_tenant_id

  prod_sub = (var.prod_subscription_id != null && trimspace(var.prod_subscription_id) != "") ? var.prod_subscription_id : var.core_subscription_id
  prod_ten = (var.prod_tenant_id       != null && trimspace(var.prod_tenant_id)       != "") ? var.prod_tenant_id       : var.core_tenant_id
}

# azurerm aliases
provider "azurerm" {
  alias           = "env"
  features {}
  subscription_id = local.env_sub
  tenant_id       = local.env_tenant
  environment     = local.product_env
}

provider "azurerm" {
  alias           = "core"
  features {}
  subscription_id = local.core_sub
  tenant_id       = local.core_tenant
  environment     = local.product_env
}

provider "azurerm" {
  alias           = "dev"
  features {}
  subscription_id = local.dev_sub
  tenant_id       = local.dev_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

provider "azurerm" {
  alias           = "qa"
  features {}
  subscription_id = local.qa_sub
  tenant_id       = local.qa_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

provider "azurerm" {
  alias           = "uat"
  features {}
  subscription_id = local.uat_sub
  tenant_id       = local.uat_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

provider "azurerm" {
  alias           = "prod"
  features {}
  subscription_id = local.prod_sub
  tenant_id       = local.prod_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Caller identity and RG discovery
data "azurerm_client_config" "core" { provider = azurerm.core }
data "azurerm_client_config" "env"  { provider = azurerm.env }

# (locals depend on remote state outputs)
locals {
  rg_core_name = try(data.terraform_remote_state.core.outputs.meta.rg_core_name, null)
  rg_app_name  = coalesce(
    var.env_rg_name,
    try(data.terraform_remote_state.platform.outputs.meta.rg_name, null)
  )
}

data "azurerm_resource_group" "core_rg" {
  provider = azurerm.core
  count    = local.rg_core_name != null ? 1 : 0
  name     = local.rg_core_name
}

data "azurerm_resource_group" "env_rg" {
  provider = azurerm.env
  count    = local.rg_app_name != null ? 1 : 0
  name     = local.rg_app_name
}

locals {
  sub_core_resolved = try(data.azurerm_client_config.core.subscription_id, null)
  sub_env_resolved  = try(data.azurerm_client_config.env.subscription_id,  null)

  rg_env_name_resolved  = try(data.azurerm_resource_group.env_rg[0].name, null)
  rg_env_id_resolved    = try(data.azurerm_resource_group.env_rg[0].id,   null)

  rg_core_name_resolved = try(data.azurerm_resource_group.core_rg[0].name,     null)
  rg_core_id_resolved   = try(data.azurerm_resource_group.core_rg[0].id,       null)
  rg_core_location_resolved = try(data.azurerm_resource_group.core_rg[0].location, null)
}

# Resource ID collection and maps
locals {
  law_id = coalesce(
    var.law_workspace_id_override,
    try(data.terraform_remote_state.core.outputs.observability.law_workspace_id, null),
    try(data.terraform_remote_state.core.outputs.ids.law, null),
    try(data.terraform_remote_state.platform.outputs.observability.law_workspace_id, null)
  )

  platform_ids = try(data.terraform_remote_state.platform.outputs.ids, {})
  platform_app = try(data.terraform_remote_state.platform.outputs.app, {})
  core_ids     = try(data.terraform_remote_state.core.outputs.ids, {})
  net_vpng     = try(data.terraform_remote_state.network.outputs.vpn_gateway.id, null)

  ids_kv = compact(concat(
    [
      try(local.platform_ids.kv1, null),
      try(data.terraform_remote_state.platform.outputs.ids.kv, null),
      try(data.terraform_remote_state.platform.outputs.keyvault.id, null)
    ],
    var.key_vault_ids
  ))

  ids_sa    = compact([try(local.platform_ids.sa1, null)])
  ids_sbns  = compact([try(local.platform_ids.sbns1, null)])
  ids_ehns  = compact([try(data.terraform_remote_state.platform.outputs.eventhub.namespace_id, null)])
  ids_pg    = compact([try(local.platform_ids.postgres, null), try(local.platform_ids.cdbpg1, null)])
  ids_redis = compact([try(local.platform_ids.redis, null)])
  ids_rsv   = compact([try(local.core_ids.rsv, null)])
  ids_appi  = compact([try(local.core_ids.appi, null)])
  ids_vpng  = compact([local.net_vpng])

  ids_cosmos = compact(concat(
    [
      try(local.platform_ids.cosmos,                     null),
      try(local.platform_ids.cosmos1,                    null),
      try(local.platform_ids.cdb1,                       null),
      try(data.terraform_remote_state.platform.outputs.ids.cosmosdb,        null),
      try(data.terraform_remote_state.platform.outputs.cosmos.account_id,   null),
      try(data.terraform_remote_state.platform.outputs.cosmosdb.account_id, null)
    ],
    var.cosmos_account_ids
  ))

  ids_aks = compact([
    try(data.terraform_remote_state.platform.outputs.aks.id,        null),
    try(data.terraform_remote_state.platform.outputs.aks_id,        null),
    try(data.terraform_remote_state.platform.outputs.ids.aks,       null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ])

  ids_funcapps = compact([
    try(local.platform_ids.funcapp1,   null),
    try(local.platform_ids.funcapp2,   null),
    try(local.platform_ids.plan1_func, null),
  ])

  ids_webapps = compact([
    try(local.platform_ids.webapp,       null),
    try(local.platform_app.web_app_id,   null),
    try(local.platform_ids.app,          null),
  ])

  ids_appgws = compact([
    try(data.terraform_remote_state.network.outputs.app_gateway.id,         null),
    try(data.terraform_remote_state.network.outputs.application_gateway.id, null),
  ])

  ids_frontdoor = compact([
    try(data.terraform_remote_state.network.outputs.frontdoor.profile_id, null)
  ])

  nsg_ids_flat = concat(
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.hub,  {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.dev,  {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.qa,   {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.prod, {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.uat,  {}))
  )

  ids_nsg = compact(local.nsg_ids_flat)

  kv_map     = { for id in local.ids_kv       : id => id }
  sa_map     = { for id in local.ids_sa       : id => id }
  sbns_map   = { for id in local.ids_sbns     : id => id }
  ehns_map   = { for id in local.ids_ehns     : id => id }
  pg_map     = { for id in local.ids_pg       : id => id }
  redis_map  = { for id in local.ids_redis    : id => id }
  rsv_map    = { for id in local.ids_rsv      : id => id }
  appi_map   = { for id in local.ids_appi     : id => id }
  vpng_map   = { for id in local.ids_vpng     : id => id }
  cosmos_map = { for id in local.ids_cosmos   : id => id }

  fa_map    = { for id in local.ids_funcapps  : id => id }
  web_map   = { for id in local.ids_webapps   : id => id }
  appgw_map = { for id in local.ids_appgws    : id => id }
  afd_map   = { for id in local.ids_frontdoor : id => id }
  nsg_map   = { for id in local.ids_nsg       : id => id }

  nsg_flow_logs_storage = try(data.terraform_remote_state.platform.outputs.nsg_flow_logs_storage, null)

  existing_exports_sa_id   = coalesce(var.nsg_flow_logs_storage_account_id_override, try(local.nsg_flow_logs_storage.id, null))
}

locals {
  # Which tiers are managed by this observability run?
  manage_core_shared = contains(["dev", "prod"], local.env_effective) # dev => nonprod core; prod => prod core
  manage_env_only    = contains(["qa", "uat"], local.env_effective)

  # Convenience: which env this run is responsible for (itself only)
  managed_env_key = local.env_effective
}

locals {
  # --- Core Key Vault ("kvt") from core stack outputs ---
  ids_kv_core = compact([
    try(data.terraform_remote_state.core.outputs.core_key_vault.id, null),
    try(data.terraform_remote_state.core.outputs.keyvault.core.id, null),
  ])

  # --- Env Key Vault(s) ("kv") from platform stack outputs / overrides ---
  ids_kv_env = compact(concat(
    [
      try(local.platform_ids.kv1, null),
      try(data.terraform_remote_state.platform.outputs.ids.kv, null),
      try(data.terraform_remote_state.platform.outputs.key_vault.id, null),
      try(data.terraform_remote_state.platform.outputs.keyvault.id, null),
    ],
    var.key_vault_ids
  ))

  ids_kv_env_distinct  = distinct(local.ids_kv_env)
  ids_kv_core_distinct = distinct(local.ids_kv_core)

  kv_env_map  = { for id in local.ids_kv_env_distinct  : id => id }
  kv_core_map = { for id in local.ids_kv_core_distinct : id => id }
}

locals {
  # single resource id (or null if platform stack didn't create it)
  excluded_flowlogs_sa_id = try(data.terraform_remote_state.platform.outputs.nsg_flow_logs_storage.id, null)
}

# Diagnostic categories (data sources)
# data "azurerm_monitor_diagnostic_categories" "kv" {
#   for_each    = local.kv_map
#   resource_id = each.value
# }
data "azurerm_monitor_diagnostic_categories" "kv_env" {
  provider    = azurerm.env
  for_each    = local.kv_env_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "kv_core" {
  provider    = azurerm.core
  for_each    = local.kv_core_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "sa" {
  for_each    = local.sa_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "sbns" {
  for_each    = local.sbns_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "ehns" {
  for_each    = local.ehns_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "pg" {
  for_each    = local.pg_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "redis" {
  for_each    = local.redis_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "rsv" {
  for_each    = local.rsv_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "appi" {
  for_each    = local.appi_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "vpng" {
  for_each    = local.vpng_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "fa" {
  for_each    = local.fa_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "web" {
  for_each    = local.web_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "appgw" {
  for_each    = local.appgw_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "afd" {
  for_each    = local.afd_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "cosmos" {
  for_each    = local.cosmos_map
  resource_id = each.value
}

data "azurerm_monitor_diagnostic_categories" "nsg" {
  for_each    = local.nsg_map
  resource_id = each.value
}

# Diagnostic settings to Log Analytics
locals {
  sub_env_target_id = local.sub_env_resolved != null ? "/subscriptions/${local.sub_env_resolved}" : null
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = var.enable_nsg_diagnostics ? {
    for id, cats in data.azurerm_monitor_diagnostic_categories.nsg :
    id => cats
    if length(try(cats.log_category_types, [])) > 0 || length(try(cats.metrics, [])) > 0
  } : {}

  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.nsg_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for NSG diagnostics."
    }
  }
}

locals {
  appgw_nsg_id = try(data.terraform_remote_state.network.outputs.app_gateway.nsg_id, null)
}

data "azurerm_monitor_diagnostic_categories" "appgw_nsg" {
  provider    = azurerm.core
  count       = (var.enable_nsg_diagnostics && local.appgw_nsg_id != null) ? 1 : 0
  resource_id = local.appgw_nsg_id
}

resource "azurerm_monitor_diagnostic_setting" "appgw_nsg" {
  provider                   = azurerm.core
  count                      = (var.enable_nsg_diagnostics && local.appgw_nsg_id != null) ? 1 : 0

  name                       = "${var.diag_name}-appgw-nsg"
  target_resource_id         = local.appgw_nsg_id
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.nsg_log_categories : c
      if contains(try(data.azurerm_monitor_diagnostic_categories.appgw_nsg[0].log_category_types, []), c)
    ])
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(try(data.azurerm_monitor_diagnostic_categories.appgw_nsg[0].metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for AppGW NSG diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sub_env" {
  provider                   = azurerm.env
  count                      = (local.sub_env_target_id == null || !var.enable_subscription_diagnostics) ? 0 : 1
  name                       = var.diag_name
  target_resource_id         = local.sub_env_target_id
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(var.subscription_log_categories)
    content { category = enabled_log.value }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID not resolved for subscription diagnostics."
    }
  }
}

locals {
  sub_core_target_id = local.sub_core_resolved != null ? "/subscriptions/${local.sub_core_resolved}" : null
}

resource "azurerm_monitor_diagnostic_setting" "sub_core" {
  provider                   = azurerm.core
  count                      = (local.sub_core_target_id == null || !var.enable_subscription_diagnostics) ? 0 : 1
  name                       = "${var.diag_name}-core"
  target_resource_id         = local.sub_core_target_id
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(var.subscription_log_categories)
    content { category = enabled_log.value }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID not resolved for core subscription diagnostics."
    }
  }
}

# resource "azurerm_monitor_diagnostic_setting" "kv" {
#   for_each                   = var.enable_kv_diagnostics ? data.azurerm_monitor_diagnostic_categories.kv : {}
#   name                       = var.diag_name
#   target_resource_id         = each.key
#   log_analytics_workspace_id = local.law_id

#   dynamic "enabled_log" {
#     for_each = toset([
#       for c in var.kv_log_categories :
#       c if (
#         contains(try(each.value.log_category_types, []), c) ||
#         contains(try(each.value.logs, []), c)
#       )
#     ])
#     content { category = enabled_log.value }
#   }

#   dynamic "metric" {
#     for_each = toset(try(each.value.metrics, []))
#     content {
#       category = metric.value
#       enabled  = true
#     }
#   }

#   lifecycle {
#     precondition {
#       condition     = local.law_id != null
#       error_message = "LAW workspace ID could not be resolved for Key Vault diagnostics."
#     }
#   }
# }

resource "azurerm_monitor_diagnostic_setting" "kv_env" {
  provider                   = azurerm.env
  for_each                   = var.enable_kv_diagnostics ? data.azurerm_monitor_diagnostic_categories.kv_env : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.kv_log_categories :
      c if contains(try(each.value.log_category_types, []), c)
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content { 
      category = metric.value
      enabled = true 
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for ENV Key Vault diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv_core" {
  provider                   = azurerm.core
  for_each                   = (var.enable_kv_diagnostics && local.manage_core_shared) ? data.azurerm_monitor_diagnostic_categories.kv_core : {}
  name                       = "${var.diag_name}-core"
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.kv_log_categories :
      c if contains(try(each.value.log_category_types, []), c)
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content { 
      category = metric.value
      enabled = true 
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for CORE Key Vault diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sa" {
  for_each                   = var.enable_sa_diagnostics ? data.azurerm_monitor_diagnostic_categories.sa : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.sa_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sbns" {
  for_each                   = var.enable_sbns_diagnostics ? data.azurerm_monitor_diagnostic_categories.sbns : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.sbns_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Service Bus diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "ehns" {
  for_each                   = var.enable_ehns_diagnostics ? data.azurerm_monitor_diagnostic_categories.ehns : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.ehns_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Event Hubs diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "pg" {
  for_each                   = var.enable_pg_diagnostics ? data.azurerm_monitor_diagnostic_categories.pg : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.pg_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for PostgreSQL diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "redis" {
  for_each                   = var.enable_redis_diagnostics ? data.azurerm_monitor_diagnostic_categories.redis : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.redis_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Redis diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  for_each                   = var.enable_rsv_diagnostics ? data.azurerm_monitor_diagnostic_categories.rsv : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.rsv_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = var.enable_rsv_metrics ? toset(try(each.value.metrics, [])) : toset([])
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    # ignore_changes = [metric]

    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Redis diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "appi" {
  for_each                   = var.enable_appi_diagnostics ? data.azurerm_monitor_diagnostic_categories.appi : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.appi_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Application Insights diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "vpng" {
  for_each                   = var.enable_vpng_diagnostics ? data.azurerm_monitor_diagnostic_categories.vpng : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.vpng_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for VPN Gateway diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "fa" {
  for_each                   = var.enable_fa_diagnostics ? data.azurerm_monitor_diagnostic_categories.fa : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.fa_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Function App diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "web" {
  for_each                   = var.enable_web_diagnostics ? data.azurerm_monitor_diagnostic_categories.web : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.web_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Web App diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  for_each                   = var.enable_appgw_diagnostics ? data.azurerm_monitor_diagnostic_categories.appgw : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.appgw_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Application Gateway diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "afd" {
  for_each                   = var.enable_afd_diagnostics ? data.azurerm_monitor_diagnostic_categories.afd : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.afd_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Azure Front Door diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  for_each                   = var.enable_cosmos_diagnostics ? data.azurerm_monitor_diagnostic_categories.cosmos : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.cosmos_log_categories :
      c if (
        contains(try(each.value.log_category_types, []), c) ||
        contains(try(each.value.logs, []), c)
      )
    ])
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = var.enable_cosmos_metrics ? toset(try(each.value.metrics, [])) : toset([])
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    # ignore_changes = [metric]

    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Redis diagnostics."
    }
  }
}

# Alerts and Action Groups
locals {
  action_group_id = try(data.terraform_remote_state.core.outputs.action_group.id, null)
}

resource "random_string" "sfx" {
  length  = 4
  special = false
  upper   = false
}

locals {
  alert_emails_effective = length(var.action_group_email_receivers) > 0 ? [for r in var.action_group_email_receivers : r.email_address] : var.alert_emails
}

resource "azurerm_monitor_action_group" "fallback" {
  count               = local.action_group_id == null ? 1 : 0
  name                = local.ag_name_default
  resource_group_name = coalesce(local.rg_core_name, local.rg_app_name)
  short_name          = "obs${random_string.sfx.result}"
  location            = var.location
  tags                = var.tags_extra

  dynamic "email_receiver" {
    for_each = toset(local.alert_emails_effective)
    content {
      name          = "email-${replace(email_receiver.value, "@", "_")}"
      email_address = email_receiver.value
    }
  }
}

resource "azurerm_monitor_action_group" "fallback_env" {
  count               = (local.rg_app_name != null && local.action_group_id == null) ? 1 : 0
  name                = "ag-${var.product}-${var.env}-env-${random_string.sfx.result}"
  resource_group_name = local.rg_app_name
  short_name          = "obs${random_string.sfx.result}"
  location            = var.location

  dynamic "email_receiver" {
    for_each = toset(var.alert_emails)
    content {
      name          = "email-${replace(email_receiver.value, "@", "_")}"
      email_address = email_receiver.value
    }
  }
}

locals {
  ag_id      = coalesce(local.action_group_id, try(azurerm_monitor_action_group.fallback[0].id, null))
  ag_id_env  = coalesce(try(azurerm_monitor_action_group.fallback_env[0].id, null), local.ag_id)
  ag_id_core = local.ag_id
}

resource "azurerm_monitor_activity_log_alert" "rg_changes_env" {
  count               = (local.rg_env_name_resolved != null) ? 1 : 0
  provider            = azurerm.env
  name                = "rg-change-${var.product}-${local.env_effective}"
  location            = "Global"
  resource_group_name = local.rg_env_name_resolved
  scopes              = [local.rg_env_id_resolved]
  criteria { category = "Administrative" }
  action   { action_group_id = local.ag_id_env }

  lifecycle {
    precondition {
      condition     = local.sub_env_resolved != null && local.rg_env_name_resolved != null
      error_message = "ENV RG not found in ENV subscription. Set var.env_rg_name or fix platform outputs."
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "service_health_env" {
  count               = (local.rg_env_name_resolved != null) ? 1 : 0
  provider            = azurerm.env
  name                = "service-health-${var.product}-${local.env_effective}"
  location            = "Global"
  resource_group_name = local.rg_env_name_resolved
  scopes              = ["/subscriptions/${local.sub_env_resolved}"]
  criteria { category = "ServiceHealth" }
  action   { action_group_id = local.ag_id_env }

  lifecycle {
    precondition {
      condition     = local.sub_env_resolved != null && local.rg_env_name_resolved != null
      error_message = "ENV RG not found in ENV subscription. Set var.env_rg_name or fix platform outputs."
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "service_health_core" {
  count               = local.rg_core_name_resolved != null && local.ag_id_core != null && local.sub_core_resolved != null ? 1 : 0
  provider            = azurerm.core
  name                = "service-health-${var.product}-${local.plane_code}-core"
  location            = local.activity_alert_location
  resource_group_name = local.rg_core_name_resolved
  scopes              = ["/subscriptions/${local.sub_core_resolved}"]
  description         = "Service Health incidents in the core subscription"
  criteria { category = "ServiceHealth" }
  action   { action_group_id = local.ag_id_core }

  lifecycle {
    precondition {
      condition     = local.sub_core_resolved != null
      error_message = "Core provider not authenticated / missing subscription."
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "rg_changes_core" {
  count               = local.rg_core_name_resolved != null && local.ag_id_core != null && local.sub_core_resolved != null ? 1 : 0
  provider            = azurerm.core
  name                = "rg-change-${var.product}-${local.plane_code}-core"
  location            = local.activity_alert_location
  resource_group_name = local.rg_core_name_resolved
  scopes              = ["/subscriptions/${local.sub_core_resolved}/resourceGroups/${local.rg_core_name_resolved}"]
  description         = "Alert on administrative operations in core RG"
  criteria { category = "Administrative" }
  action   { action_group_id = local.ag_id_core }
}

# AKS diagnostics
locals {
  aks_ids = toset(compact([
    try(data.terraform_remote_state.platform.outputs.ids.aks,       null),
    try(data.terraform_remote_state.platform.outputs.aks_id,        null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ]))

  aks_map         = { for id in local.aks_ids : id => id }
  aks_env_enabled = contains(["dev", "uat", "prod"], local.env_effective)
}

data "azurerm_monitor_diagnostic_categories" "aks" {
  for_each    = local.aks_map
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  for_each                   = (var.enable_aks_diagnostics && local.aks_env_enabled) ? local.aks_map : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(data.azurerm_monitor_diagnostic_categories.aks[each.key].logs, []))
    content { category = enabled_log.value }
  }

  dynamic "metric" {
    for_each = toset(try(data.azurerm_monitor_diagnostic_categories.aks[each.key].metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for AKS diagnostics."
    }
  }
}

# Policy compliance – Event Grid system topic
locals {
  policy_system_topic_parent_ids = {
    for label, cfg in var.policy_source_subscriptions :
    label => (
      label == "core"
        ? local.rg_core_id_resolved
        : try(
            data.terraform_remote_state.network.outputs.resource_groups[replace(label, "-", "_")].id,
            null
          )
    )
  }
}

locals {
  policy_alerts_enabled_for_env = contains(["dev", "prod"], local.env_effective)
  policy_compliance_enabled = var.enable_policy_compliance_alerts && local.policy_alerts_enabled_for_env
}

resource "azapi_resource" "policy_state_changes" {
  provider = azapi.core

  for_each = local.policy_compliance_enabled ? var.policy_source_subscriptions : {}

  type      = "Microsoft.EventGrid/systemTopics@2023-06-01-preview"
  name      = "policy-compliance-topic-${var.product}-${local.plane_code}-${var.region}-${each.key}"
  parent_id = local.policy_system_topic_parent_ids[each.key]
  location  = "global"

  body = {
    properties = {
      source    = "/subscriptions/${each.value.subscription_id}"
      topicType = "Microsoft.PolicyInsights.PolicyStates"
    }
  }
}

# Policy compliance – Logic App and connection
locals {
  logicapp_parameters = {
    "$connections" = {
      "value" = {
        "office365" = {
          "connectionId"   = "/subscriptions/${data.azurerm_client_config.core.subscription_id}/resourceGroups/${data.azurerm_resource_group.core_rg[0].name}/providers/Microsoft.Web/connections/office365"
          "connectionName" = "office365"
          "id"             = "/subscriptions/${data.azurerm_client_config.core.subscription_id}/providers/Microsoft.Web/locations/${data.azurerm_resource_group.core_rg[0].location}/managedApis/office365"
        }
      }
    }
  }

  logicapp_definition = {
    "$schema"        = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
    "contentVersion" = "1.0.0.0"

    "parameters" = {
      "$connections" = {
        "defaultValue" = {}
        "type"         = "Object"
      }
    }

    "triggers" = {
      "manual" = {
        "type" = "Request"
        "kind" = "Http"
        "inputs" = {
          "schema" = {
            "type" = "array"
          }
        }
      }
    }

    "actions" = {
      "If_SubscriptionValidation" = {
        "type"       = "If"
        "expression" = "@or(equals(triggerOutputs()?['headers']?['aeg-event-type'],'SubscriptionValidation'), and(greater(length(coalesce(triggerBody(), json('[]'))), 0), equals(first(coalesce(triggerBody(), json('[]')))?['eventType'],'Microsoft.EventGrid.SubscriptionValidationEvent')))"

        "actions" = {
          "Return_SubscriptionValidation_Response" = {
            "type" = "Response"
            "inputs" = {
              "statusCode" = 200
              "body" = {
                "validationResponse" = "@first(coalesce(triggerBody(), json('[]')))?['data']?['validationCode']"
              }
            }
          },
          "Manual_Validation_GET" = {
            "type" = "Http"
            "runAfter" = { "Return_SubscriptionValidation_Response" = ["Failed"] }
            "inputs" = {
              "method" = "GET"
              "uri"    = "@first(coalesce(triggerBody(), json('[]')))?['data']?['validationUrl']"
            }
          },
          "Terminate_Validation" = {
            "type"     = "Terminate"
            "runAfter" = { "Manual_Validation_GET" = ["Succeeded"] }
            "inputs"   = { "runStatus" = "Succeeded" }
          }
        }

        "else" = {
          "actions" = {
            # inside local.logicapp_definition "actions" -> If_SubscriptionValidation -> else -> actions
            "If_HasEvents" = {
              "type"       = "If"
              "expression" = "@greater(length(coalesce(triggerBody(), json('[]'))), 0)"
              "actions" = {
                "For_each_event" = {
                  "type"    = "Foreach"
                  "foreach" = "@coalesce(triggerBody(), json('[]'))"
                  "actions" = {
                    "If_NonCompliant" = {
                      "type"       = "If"
                      "expression" = "@equals(items('For_each_event')?['data']?['complianceState'], 'NonCompliant')"
                      "actions" = {
                        # ---- Core event fields ----
                        "Compose_SubscriptionId" = {
                          "type"   = "Compose"
                          "inputs" = "@items('For_each_event')?['data']?['subscriptionId']"
                        },
                        "Compose_ResourceId" = {
                          "type"   = "Compose"
                          "inputs" = "@coalesce(items('For_each_event')?['data']?['resourceId'], items('For_each_event')?['subject'])"
                          "runAfter" = { "Compose_SubscriptionId" = ["Succeeded"] }
                        },
                        "Compose_ResourceGroup" = {
                          "type"   = "Compose"
                          "inputs" = "@coalesce(items('For_each_event')?['data']?['resourceGroup'], split(outputs('Compose_ResourceId'), '/')[4])"
                          "runAfter" = { "Compose_ResourceId" = ["Succeeded"] }
                        },
                        "Compose_ResourceType" = {
                          "type"   = "Compose"
                          "inputs" = "@coalesce(items('For_each_event')?['data']?['resourceType'], concat(split(outputs('Compose_ResourceId'), '/')[6], '/', split(outputs('Compose_ResourceId'), '/')[7]))"
                          "runAfter" = { "Compose_ResourceGroup" = ["Succeeded"] }
                        },
                        "Compose_ResourceName" = {
                          "type"   = "Compose"
                          "inputs" = "@last(split(outputs('Compose_ResourceId'), '/'))"
                          "runAfter" = { "Compose_ResourceType" = ["Succeeded"] }
                        },

                        # ---- Enrichment: Policy Definition ----
                        "HTTP_PolicyDefinition" = {
                          "type" = "Http"
                          "inputs" = {
                            "method" = "GET"
                            "uri"    = "@concat('https://management.usgovcloudapi.net', items('For_each_event')?['data']?['policyDefinitionId'], '?api-version=2021-06-01')"
                            "headers" = { "Content-Type" = "application/json" }
                            "authentication" = {
                              "type"     = "ManagedServiceIdentity"
                              "audience" = "https://management.usgovcloudapi.net"
                            }
                          }
                          "runAfter" = { "Compose_ResourceName" = ["Succeeded"] }
                        },

                        # ---- Enrichment: Policy Assignment ----
                        "HTTP_PolicyAssignment" = {
                          "type" = "Http"
                          "inputs" = {
                            "method" = "GET"
                            "uri"    = "@concat('https://management.usgovcloudapi.net', items('For_each_event')?['data']?['policyAssignmentId'], '?api-version=2023-04-01')"
                            "headers" = { "Content-Type" = "application/json" }
                            "authentication" = {
                              "type"     = "ManagedServiceIdentity"
                              "audience" = "https://management.usgovcloudapi.net"
                            }
                          }
                          "runAfter" = { "HTTP_PolicyDefinition" = ["Succeeded"] }
                        },

                        # ---- Friendly fields ----
                        "Compose_PolicyDisplayName" = {
                          "type"   = "Compose"
                          "inputs" = "@coalesce(body('HTTP_PolicyDefinition')?['properties']?['displayName'], items('For_each_event')?['data']?['policyDefinitionId'])"
                          "runAfter" = { "HTTP_PolicyAssignment" = ["Succeeded"] }
                        },
                        "Compose_AssignmentDisplayName" = {
                          "type"   = "Compose"
                          "inputs" = "@coalesce(body('HTTP_PolicyAssignment')?['properties']?['displayName'], items('For_each_event')?['data']?['policyAssignmentId'])"
                          "runAfter" = { "Compose_PolicyDisplayName" = ["Succeeded"] }
                        },
                        "Compose_NonComplianceMessage" = {
                          "type"   = "Compose"
                          "inputs" = "@if(empty(coalesce(body('HTTP_PolicyAssignment')?['properties']?['nonComplianceMessages'], json('[]'))), null, first(coalesce(body('HTTP_PolicyAssignment')?['properties']?['nonComplianceMessages'], json('[]')))?['message'])"
                          "runAfter" = { "Compose_AssignmentDisplayName" = ["Succeeded"] }
                        },

                        # ---- Portal links (Gov) ----
                        # Resource blade link
                        "Compose_ResourcePortalUrl" = {
                          "type"   = "Compose"
                          "inputs" = "@concat('https://portal.azure.us/#@/resource', outputs('Compose_ResourceId'))"
                          "runAfter" = { "Compose_NonComplianceMessage" = ["Succeeded"] }
                        },
                        # Assignment blade link
                        "Compose_AssignmentPortalUrl" = {
                          "type"   = "Compose"
                          "inputs" = "@concat('https://portal.azure.us/#@/resource', items('For_each_event')?['data']?['policyAssignmentId'])"
                          "runAfter" = { "Compose_ResourcePortalUrl" = ["Succeeded"] }
                        },
                        # Definition blade link
                        "Compose_DefinitionPortalUrl" = {
                          "type"   = "Compose"
                          "inputs" = "@concat('https://portal.azure.us/#@/resource', items('For_each_event')?['data']?['policyDefinitionId'])"
                          "runAfter" = { "Compose_AssignmentPortalUrl" = ["Succeeded"] }
                        },

                        # ---- Email ----
                        "Send_Email" = {
                          "type" = "ApiConnection"
                          "runAfter" = { "Compose_DefinitionPortalUrl" = ["Succeeded"] }
                          "inputs" = {
                            "host" = {
                              "connection" = {
                                "name" = "@parameters('$connections')['office365']['connectionId']"
                              }
                            }
                            "method" = "post"
                            "path"   = "/v2/Mail"
                            "body" = {
                              "To"   = var.policy_alert_email
                              "From" = "noreply-alerts@intterragroup.com"
                              "Subject" = "@{concat('Non-Compliance: ', outputs('Compose_ResourceName'), ' | ', outputs('Compose_PolicyDisplayName'))}"
                              "Body" = <<-HTML
                                <p><strong>Azure Policy Non-Compliance detected.</strong></p>

                                <h3>What failed</h3>
                                <p><strong>Policy:</strong> @{outputs('Compose_PolicyDisplayName')}<br/>
                                  <strong>Assignment:</strong> @{outputs('Compose_AssignmentDisplayName')}</p>

                                <p><strong>Noncompliance guidance:</strong><br/>
                                  @{coalesce(outputs('Compose_NonComplianceMessage'), body('HTTP_PolicyDefinition')?['properties']?['description'], 'No description provided.')}
                                </p>

                                <h3>Affected resource</h3>
                                <p>
                                  <strong>Name:</strong> @{outputs('Compose_ResourceName')}<br/>
                                  <strong>Type:</strong> @{outputs('Compose_ResourceType')}<br/>
                                  <strong>Resource Group:</strong> @{outputs('Compose_ResourceGroup')}<br/>
                                  <strong>Subscription:</strong> @{outputs('Compose_SubscriptionId')}<br/>
                                  <strong>Resource ID:</strong><br/>@{outputs('Compose_ResourceId')}
                                </p>

                                <p>
                                  <a href="@{outputs('Compose_ResourcePortalUrl')}">Open Resource (Azure Gov Portal)</a><br/>
                                  <a href="@{outputs('Compose_AssignmentPortalUrl')}">Open Policy Assignment</a><br/>
                                  <a href="@{outputs('Compose_DefinitionPortalUrl')}">Open Policy Definition</a>
                                </p>

                                <h3>Evaluation</h3>
                                <p>
                                  <strong>Compliance state:</strong> @{items('For_each_event')?['data']?['complianceState']}<br/>
                                  <strong>Policy evaluation time:</strong> @{items('For_each_event')?['data']?['timestamp']}<br/>
                                  <strong>Event time:</strong> @{items('For_each_event')?['eventTime']}<br/>
                                  <strong>Effect (definition):</strong> @{body('HTTP_PolicyDefinition')?['properties']?['policyRule']?['then']?['effect']}<br/>
                                  <strong>Enforcement mode (assignment):</strong> @{body('HTTP_PolicyAssignment')?['properties']?['enforcementMode']}
                                </p>

                                <p>
                                  <strong>Next steps:</strong><br/>
                                  1) Open the resource link and validate the configuration.<br/>
                                  2) Open the assignment to confirm scope/notScopes and any noncompliance message.<br/>
                                  3) Remediate to the FedRAMP Moderate baseline (or move workload out of boundary).
                                </p>
                              HTML
                              "BodyContentType" = "HTML"
                            }
                          }
                        }
                      }
                      "else" = { "actions" = {} }
                    }
                  }
                }
              }
              "else" = { "actions" = {} }
            }
          }
        }
      }
    }

    "outputs" = {}
  }
}

resource "azurerm_api_connection" "office365" {
  provider            = azurerm.core
  count               = local.policy_compliance_enabled ? 1 : 0
  name                = "office365"
  resource_group_name = local.rg_core_name_resolved
  display_name        = "Office 365"
  managed_api_id      = "/subscriptions/${local.sub_core_resolved}/providers/Microsoft.Web/locations/${local.rg_core_location_resolved}/managedApis/office365"
  parameter_values    = {}
}

resource "azurerm_resource_group_template_deployment" "logicapp" {
  provider            = azurerm.core
  count               = local.policy_compliance_enabled ? 1 : 0
  name                = "tmpl-la-${var.product}-${local.plane_code}-${var.region}-policy-alerts"
  resource_group_name = local.rg_core_name_resolved
  deployment_mode     = "Incremental"

  template_content = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.Logic/workflows",
      "apiVersion": "2019-05-01",
      "name": "la-${var.product}-${local.plane_code}-${var.region}-policy-alerts-01",
      "location": "${data.azurerm_resource_group.core_rg[0].location}",
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "definition": ${jsonencode(local.logicapp_definition)},
        "parameters": ${jsonencode(local.logicapp_parameters)}
      }
    }
  ]
}
TEMPLATE
}

data "azurerm_logic_app_workflow" "policy_alerts" {
  provider            = azurerm.core
  count               = local.policy_compliance_enabled ? 1 : 0
  name                = "la-${var.product}-${local.plane_code}-${var.region}-policy-alerts-01"
  resource_group_name = local.rg_core_name_resolved

  depends_on = [
    azurerm_resource_group_template_deployment.logicapp
  ]
}

resource "azapi_resource_action" "manual_trigger_callback" {
  count       = local.policy_compliance_enabled ? 1 : 0
  type        = "Microsoft.Logic/workflows/triggers@2019-05-01"
  resource_id = "${data.azurerm_logic_app_workflow.policy_alerts[0].id}/triggers/manual"
  action      = "listCallbackUrl"
  method      = "POST"
  body        = {}

  response_export_values = ["value"]

  depends_on = [azurerm_resource_group_template_deployment.logicapp]
}

locals {
  logicapp_manual_trigger_callback_url = try(azapi_resource_action.manual_trigger_callback[0].output.value, null)
}

resource "azapi_resource" "policy_to_logicapp" {
  for_each = (
    local.policy_compliance_enabled &&
    local.logicapp_manual_trigger_callback_url != null
  ) ? azapi_resource.policy_state_changes : {}

  type      = "Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15"
  name      = "egsub-${var.product}-${local.plane_code}-${var.region}-policy-noncompliant-${each.key}"
  parent_id = each.value.id

  body = {
    properties = {
      destination = {
        endpointType = "WebHook"
        properties = {
          endpointUrl = local.logicapp_manual_trigger_callback_url
        }
      }
      filter = {
        includedEventTypes = [
          "Microsoft.PolicyInsights.PolicyStateCreated",
          "Microsoft.PolicyInsights.PolicyStateChanged",
        ]
        advancedFilters = [
          {
            operatorType = "StringIn"
            key          = "data.complianceState"
            values       = ["NonCompliant"]
          }
        ]
      }
      eventDeliverySchema = "EventGridSchema"
      retryPolicy = {
        maxDeliveryAttempts      = 30
        eventTimeToLiveInMinutes = 1440
      }
    }
  }

  depends_on = [
    azurerm_resource_group_template_deployment.logicapp,
  ]
}

# Subscription budgets for policy sources
locals {
  budget_emails_effective = length(var.budget_alert_emails) > 0 ? var.budget_alert_emails : local.alert_emails_effective

  budget_subscriptions = {
    for label, cfg in var.policy_source_subscriptions :
    label => "/subscriptions/${cfg.subscription_id}"
  }
}

resource "azurerm_consumption_budget_subscription" "policy_source_budgets" {
  for_each = var.enable_subscription_budgets ? local.budget_subscriptions : {}

  name            = "bud-${var.product}-${local.plane_code}-${var.region}-${each.key}"
  subscription_id = each.value

  amount     = var.subscription_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.subscription_budget_start_date
    end_date   = var.subscription_budget_end_date
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = var.subscription_budget_threshold
    contact_emails = local.budget_emails_effective
  }
}

# VNet flow logs (replaces NSG flow logs)
locals {
  # --- Backward compat defaults (prefer new vnet_* vars if set) ---
  flow_logs_enabled_effective = coalesce(var.enable_vnet_flow_logs, var.enable_nsg_flow_logs, false)
  flow_logs_retention_days    = coalesce(var.vnet_flow_logs_retention_days, var.nsg_flow_logs_retention_days, 30)
  flow_logs_sa_override_id = try(
    coalesce(
      var.vnet_flow_logs_storage_account_id_override,
      var.nsg_flow_logs_storage_account_id_override
    ),
    null
  )

  # Prefer explicit override for workspace GUID first
  law_workspace_guid = coalesce(
    var.law_workspace_guid_override,
    try(data.terraform_remote_state.core.outputs.observability.law_workspace_guid, null),
    try(data.terraform_remote_state.platform.outputs.observability.law_workspace_guid, null),
    null
  )

  # Storage account for flow logs (from platform remote state OR explicit override)
  flow_logs_storage = try(data.terraform_remote_state.platform.outputs.nsg_flow_logs_storage, null)
  flow_logs_sa_id   = coalesce(local.flow_logs_sa_override_id, try(local.flow_logs_storage.id, null))

  # Pull VNets from:
  # 1) shared-network remote state (if you expose it), and
  # 2) explicit var.vnet_ids_by_env (already in your variables.tf)
  # vnet_ids_by_env_remote = try(data.terraform_remote_state.network.outputs.vnet_ids_by_env, {})

  # shared-network exposes vnet_map with keys:
  # - "nphub" or "prhub"
  # - dev, qa, prod, uat
  _shared_vnet_map = try(data.terraform_remote_state.network.outputs.vnet_map, {})

  _shared_hub_vnet_id = coalesce(
    try(local._shared_vnet_map["nphub"].id, null),
    try(local._shared_vnet_map["prhub"].id, null),
    null
  )

  # Normalize into the env keys your observability stack expects: hub/dev/qa/prod/uat
  vnet_ids_by_env_remote = {
    hub  = compact([local._shared_hub_vnet_id])
    dev  = compact([try(local._shared_vnet_map["dev"].id,  null)])
    qa   = compact([try(local._shared_vnet_map["qa"].id,   null)])
    prod = compact([try(local._shared_vnet_map["prod"].id, null)])
    uat  = compact([try(local._shared_vnet_map["uat"].id,  null)])
  }

  vnet_env_keys_all = toset(concat(
    keys(local.vnet_ids_by_env_remote),
    keys(var.vnet_ids_by_env)
  ))

  vnet_ids_by_env_effective = {
    for k in local.vnet_env_keys_all :
    k => distinct(compact(concat(
      lookup(local.vnet_ids_by_env_remote, k, []),
      lookup(var.vnet_ids_by_env,        k, [])
    )))
  }

  # Match your existing pattern:
  # - dev env stack manages: hub + dev + qa
  # - prod env stack manages: hub + prod + uat
  vnet_flowlog_env_sets = {
    dev  = ["hub", "dev", "qa"]
    prod = ["hub", "prod", "uat"]
  }

  vnet_flowlog_env_keys = lookup(local.vnet_flowlog_env_sets, local.env_effective, [])

  vnet_flowlog_items = flatten([
    for env_key in local.vnet_flowlog_env_keys : [
      for vnet_id in lookup(local.vnet_ids_by_env_effective, env_key, []) : {
        id      = vnet_id
        env_key = env_key
      }
    ]
  ])

  vnet_flowlog_map = {
    for item in local.vnet_flowlog_items :
    item.id => item
  }

  vnet_flowlogs_enabled = (
    local.flow_logs_enabled_effective &&
    local.law_id != null &&
    local.law_workspace_guid != null &&
    local.flow_logs_sa_id != null &&
    length(local.vnet_flowlog_map) > 0
  )

  vnet_flowlog_map_hub  = { for id, item in local.vnet_flowlog_map : id => item if item.env_key == "hub"  }
  vnet_flowlog_map_dev  = { for id, item in local.vnet_flowlog_map : id => item if item.env_key == "dev"  }
  vnet_flowlog_map_qa   = { for id, item in local.vnet_flowlog_map : id => item if item.env_key == "qa"   }
  vnet_flowlog_map_prod = { for id, item in local.vnet_flowlog_map : id => item if item.env_key == "prod" }
  vnet_flowlog_map_uat  = { for id, item in local.vnet_flowlog_map : id => item if item.env_key == "uat"  }

  network_watcher_by_env = coalesce(
    try(data.terraform_remote_state.network.outputs.network_watchers, null),
    {
      hub = {
        name = "nw-${var.product}-${local.plane_code}-${var.region}-01"
        rg   = "rg-${var.product}-${local.plane_code}-${var.region}-net-01"
      }
      dev = {
        name = "nw-${var.product}-dev-${var.region}-01"
        rg   = "rg-${var.product}-dev-${var.region}-net-01"
      }
      qa = {
        name = "nw-${var.product}-qa-${var.region}-01"
        rg   = "rg-${var.product}-qa-${var.region}-net-01"
      }
      prod = {
        name = "nw-${var.product}-prod-${var.region}-01"
        rg   = "rg-${var.product}-prod-${var.region}-net-01"
      }
      uat = {
        name = "nw-${var.product}-uat-${var.region}-01"
        rg   = "rg-${var.product}-uat-${var.region}-net-01"
      }
    }
  )
}

# HUB (core subscription)
resource "azurerm_network_watcher_flow_log" "vnet_core" {
  provider = azurerm.core

  for_each = (local.vnet_flowlogs_enabled && contains(["dev", "prod"], local.env_effective)) ? local.vnet_flowlog_map_hub : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["hub"].name
  resource_group_name  = local.network_watcher_by_env["hub"].rg

  target_resource_id = each.value.id
  storage_account_id = local.flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = local.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law_workspace_guid
    workspace_region      = var.location
    workspace_resource_id = local.law_id
    interval_in_minutes   = 10
  }

  lifecycle {
    precondition {
      condition = (
        local.law_id != null &&
        local.law_workspace_guid != null &&
        local.flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or flow-logs storage account not resolved."
    }
  }
}

# DEV subscription
resource "azurerm_network_watcher_flow_log" "vnet_dev" {
  provider = azurerm.dev

  for_each = (local.vnet_flowlogs_enabled && local.env_effective == "dev") ? local.vnet_flowlog_map_dev : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["dev"].name
  resource_group_name  = local.network_watcher_by_env["dev"].rg

  target_resource_id = each.value.id
  storage_account_id = local.flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = local.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law_workspace_guid
    workspace_region      = var.location
    workspace_resource_id = local.law_id
    interval_in_minutes   = 10
  }
}

# QA subscription (created by the dev stack)
resource "azurerm_network_watcher_flow_log" "vnet_qa" {
  provider = azurerm.qa

  for_each = (local.vnet_flowlogs_enabled && local.env_effective == "dev") ? local.vnet_flowlog_map_qa : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["qa"].name
  resource_group_name  = local.network_watcher_by_env["qa"].rg

  target_resource_id = each.value.id
  storage_account_id = local.flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = local.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law_workspace_guid
    workspace_region      = var.location
    workspace_resource_id = local.law_id
    interval_in_minutes   = 10
  }
}

# PROD subscription
resource "azurerm_network_watcher_flow_log" "vnet_prod" {
  provider = azurerm.prod

  for_each = (local.vnet_flowlogs_enabled && local.env_effective == "prod") ? local.vnet_flowlog_map_prod : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["prod"].name
  resource_group_name  = local.network_watcher_by_env["prod"].rg

  target_resource_id = each.value.id
  storage_account_id = local.flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = local.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law_workspace_guid
    workspace_region      = var.location
    workspace_resource_id = local.law_id
    interval_in_minutes   = 10
  }
}

# UAT subscription (created by the prod stack)
resource "azurerm_network_watcher_flow_log" "vnet_uat" {
  provider = azurerm.uat

  for_each = (local.vnet_flowlogs_enabled && local.env_effective == "prod") ? local.vnet_flowlog_map_uat : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["uat"].name
  resource_group_name  = local.network_watcher_by_env["uat"].rg

  target_resource_id = each.value.id
  storage_account_id = local.flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = local.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = local.law_workspace_guid
    workspace_region      = var.location
    workspace_resource_id = local.law_id
    interval_in_minutes   = 10
  }
}

# AzAPI providers for Cost Management Exports (subscription-scoped resources)
provider "azapi" {
  alias           = "dev"
  subscription_id = local.dev_sub
  tenant_id       = local.dev_ten
}

provider "azapi" {
  alias           = "qa"
  subscription_id = local.qa_sub
  tenant_id       = local.qa_ten
}

provider "azapi" {
  alias           = "prod"
  subscription_id = local.prod_sub
  tenant_id       = local.prod_ten
}

provider "azapi" {
  alias           = "uat"
  subscription_id = local.uat_sub
  tenant_id       = local.uat_ten
}

# --- Register required Resource Providers (explicit per provider alias) ---
locals {
  cost_exports_enabled = var.enable_cost_exports

  # same logic you had
  cost_exports_rp_targets = (
    !local.cost_exports_enabled ? toset([]) :
    local.env_effective == "dev"  ? toset(["core", "dev", "qa"]) :
    local.env_effective == "prod" ? toset(["core", "uat", "prod"]) :
    toset([])
  )
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_core" {
  count    = contains(local.cost_exports_rp_targets, "core") ? 1 : 0
  provider = azurerm.core
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_dev" {
  count    = contains(local.cost_exports_rp_targets, "dev") ? 1 : 0
  provider = azurerm.dev
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_qa" {
  count    = contains(local.cost_exports_rp_targets, "qa") ? 1 : 0
  provider = azurerm.qa
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_uat" {
  count    = contains(local.cost_exports_rp_targets, "uat") ? 1 : 0
  provider = azurerm.uat
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_prod" {
  count    = contains(local.cost_exports_rp_targets, "prod") ? 1 : 0
  provider = azurerm.prod
  name     = "Microsoft.CostManagementExports"
}

resource "time_sleep" "wait_cost_exports_rp" {
  count           = length(local.cost_exports_rp_targets) > 0 ? 1 : 0
  create_duration = "8m"

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    azurerm_resource_provider_registration.cost_exports_rp_dev,
    azurerm_resource_provider_registration.cost_exports_rp_qa,
    azurerm_resource_provider_registration.cost_exports_rp_uat,
    azurerm_resource_provider_registration.cost_exports_rp_prod,
  ]
}

locals {
  cost_exports_schedule_from = var.cost_exports_schedule_from
  cost_exports_schedule_to   = coalesce(var.cost_exports_schedule_end_date, "2035-01-01T00:00:00Z")
}

# Cost Management exports (env subscriptions) -> core storage
locals {
  # Match your "dev => dev+qa" and "prod => prod+uat" pattern
  cost_export_env_sets = {
    dev  = ["dev", "qa"]
    prod = ["prod", "uat"]
  }

  cost_export_targets = local.cost_exports_enabled ? lookup(local.cost_export_env_sets, local.env_effective, []) : []
}

locals {
  cost_exports_destination = (var.enable_cost_exports && local.existing_exports_sa_id != null) ? {
    resourceId     = local.existing_exports_sa_id
    container      = var.cost_exports_container_name        # "cost-exports"
    rootFolderPath = "${var.cost_exports_root_folder}"
    # rootFolderPath = "${var.cost_exports_root_folder}/${var.product}/${local.env_effective}/${var.region}"
  } : null
}

# ---------- DEV subscription exports ----------
resource "azapi_resource" "cost_export_dev_last_month" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-dev-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.dev_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_dev_mtd_daily" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-dev-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.dev_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_dev_manual_custom" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-dev-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.dev_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

# ---------- QA subscription exports ----------
resource "azapi_resource" "cost_export_qa_last_month" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-qa-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.qa_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_qa_mtd_daily" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-qa-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.qa_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_qa_manual_custom" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-qa-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.qa_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

# ---------- PROD subscription exports ----------
resource "azapi_resource" "cost_export_prod_last_month" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-prod-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.prod_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_prod_mtd_daily" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-prod-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.prod_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_prod_manual_custom" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-prod-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.prod_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

# ---------- UAT subscription exports ----------
resource "azapi_resource" "cost_export_uat_last_month" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-uat-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.uat_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_uat_mtd_daily" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-uat-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.uat_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_uat_manual_custom" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-uat-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.uat_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

# ---------- CORE subscription exports ----------
resource "azapi_resource" "cost_export_core_nonprod_last_month" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-np-core-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_core_nonprod_mtd_daily" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-np-core-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_core_nonprod_manual_custom" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-np-core-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_last_month" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-pr-core-${var.region}-last-month-monthly"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "TheLastMonth"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_mtd_daily" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-pr-core-${var.region}-mtd-daily"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet   = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Daily"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Active"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_manual_custom" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2025-03-01"
  name                      = "ce-${var.product}-pr-core-${var.region}-manual-custom"
  parent_id                 = "/subscriptions/${local.core_sub}"
  location                  = var.location
  schema_validation_enabled = false

  identity { type = "SystemAssigned" }

  body = {
    properties = {
      definition = {
        type      = "Usage"
        timeframe = "Custom"
        timePeriod = {
          from = "2025-01-01T00:00:00Z"
          to   = "2025-01-31T23:59:59Z"
        }
        dataSet = { granularity = "Daily" }
      }
      deliveryInfo = {
        destination = local.cost_exports_destination
      }
      format = "Csv"
      schedule = {
        recurrence = "Monthly"
        recurrencePeriod = {
          from = local.cost_exports_schedule_from
          to   = local.cost_exports_schedule_to
        }
        status = "Inactive"
      }
    }
  }

#  response_export_values = ["identity.principalId"]

  depends_on = [time_sleep.wait_cost_exports_rp]

  lifecycle {
    precondition {
      condition     = var.enable_cost_exports ? local.existing_exports_sa_id != null : true
      error_message = "Cost exports enabled but destination storage account ID not resolved."
    }
  }
}

resource "azapi_resource" "apr_suppress_core_excluded_resources" {
  provider = azapi.core
  count = (
    contains(["dev", "prod"], local.env_effective) &&
    local.excluded_flowlogs_sa_id != null &&
    trimspace(local.excluded_flowlogs_sa_id) != "" &&
    local.rg_core_name_resolved != null
  ) ? 1 : 0

  type      = "Microsoft.AlertsManagement/actionRules@2021-08-08"
  name      = "apr-${var.product}-${local.plane_code}-${var.region}-core-saobs"
  parent_id = "/subscriptions/${local.core_sub}/resourceGroups/${local.rg_core_name_resolved}"
  location  = "global"

  body = {
    properties = {
      enabled     = true
      description = "Suppress alert notifications for the flow logs storage account (core subscription)."
      scopes      = ["/subscriptions/${local.core_sub}"]

      conditions = [
        {
          field    = "TargetResource"
          operator = "Equals"
          values   = [local.excluded_flowlogs_sa_id]
        }
      ]

      actions = [
        { actionType = "RemoveAllActionGroups" }
      ]
    }
  }
}

locals {
  # Exclude these namespaces from collection
  aks_ci_namespace_filtering_mode = "Exclude"
  aks_ci_namespaces_excluded      = ["kube-system", "gatekeeper-system", "azure-arc"]

  aks_ci_collect_perf        = coalesce(var.aks_collect_performance, false)
  aks_ci_collect_all_logs    = coalesce(var.aks_collect_all_logs, true)

  aks_ci_streams = local.aks_ci_collect_all_logs ? ["Microsoft-ContainerInsights-Group-Default"] : compact(concat(
        ["Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory"],
        local.aks_ci_collect_perf ? ["Microsoft-Perf"] : []
      ))
}

resource "azapi_resource" "dcr_container_insights_nonprod" {
  provider                  = azapi.core
  count                     = (local.env_effective == "dev" && local.aks_env_enabled) ? 1 : 0
  type                      = "Microsoft.Insights/dataCollectionRules@2022-06-01"
  name                      = "dcr-${var.product}-dev-${var.region}-aks-containers"
  parent_id                 = "/subscriptions/${local.core_sub}/resourceGroups/${local.rg_core_name_resolved}"
  location                  = var.location
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Azure Monitor Container Insights for AKS (nonprod) -> LAW (cost-optimized defaults)"

      destinations = {
        logAnalytics = [
          {
            name                = "law"
            workspaceResourceId = local.law_id
          }
        ]
      }

      dataFlows = [
        {
          streams      = local.aks_ci_streams
          destinations = ["law"]
        }
      ]

      dataSources = {
        extensions = [
          {
            name          = "ContainerInsightsExtension"
            extensionName = "ContainerInsights"
            streams       = local.aks_ci_streams

            extensionSettings = {
              dataCollectionSettings = {
                interval               = "5m"
                namespaceFilteringMode = local.aks_ci_namespace_filtering_mode
                namespaces             = local.aks_ci_namespaces_excluded

                # Only meaningful when you’re using ContainerLogV2 (which you are in the non-group preset case).
                enableContainerLogV2 = true
              }
            }
          }
        ]
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null && local.rg_core_name_resolved != null
      error_message = "LAW workspace ID or core RG not resolved; cannot enable Container Insights DCR."
    }
  }
}

resource "azapi_resource" "dcr_assoc_container_insights_nonprod" {
  provider                  = azapi.core
  for_each                  = (local.env_effective == "dev" && local.aks_env_enabled) ? local.aks_map : {}
  type                      = "Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01"
  name                      = "dcrassoc-containers"
  parent_id                 = each.key
  schema_validation_enabled = false

  body = {
    properties = {
      description         = "Associate Container Insights DCR"
      dataCollectionRuleId = azapi_resource.dcr_container_insights_nonprod[0].id
    }
  }
}

resource "azapi_resource" "dcr_container_insights_prod" {
  provider                  = azapi.prod
  count                     = (local.env_effective == "prod" && local.aks_env_enabled) ? 1 : 0
  type                      = "Microsoft.Insights/dataCollectionRules@2022-06-01"
  name                      = "dcr-${var.product}-prod-${var.region}-aks-containers"
  parent_id                 = "/subscriptions/${local.prod_sub}/resourceGroups/${local.rg_env_name_resolved}"
  location                  = var.location
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Azure Monitor Container Insights for AKS (prod) -> LAW (cost-optimized defaults)"

      destinations = {
        logAnalytics = [
          {
            name                = "law"
            workspaceResourceId = local.law_id
          }
        ]
      }

      dataFlows = [
        {
          streams      = local.aks_ci_streams
          destinations = ["law"]
        }
      ]

      dataSources = {
        extensions = [
          {
            name          = "ContainerInsightsExtension"
            extensionName = "ContainerInsights"
            streams       = local.aks_ci_streams

            extensionSettings = {
              dataCollectionSettings = {
                interval               = "5m"
                namespaceFilteringMode = local.aks_ci_namespace_filtering_mode
                namespaces             = local.aks_ci_namespaces_excluded

                # Only meaningful when you’re using ContainerLogV2 (which you are in the non-group preset case).
                enableContainerLogV2 = true
              }
            }
          }
        ]
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null && local.rg_env_name_resolved != null
      error_message = "LAW workspace ID or env RG not resolved; cannot enable Container Insights DCR."
    }
  }
}

resource "azapi_resource" "dcr_assoc_container_insights_prod" {
  provider                  = azapi.prod
  for_each                  = (local.env_effective == "prod" && local.aks_env_enabled) ? local.aks_map : {}
  type                      = "Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01"
  name                      = "dcrassoc-containers"
  parent_id                 = each.key
  schema_validation_enabled = false

  body = {
    properties = {
      description         = "Associate Container Insights DCR"
      dataCollectionRuleId = azapi_resource.dcr_container_insights_prod[0].id
    }
  }
}

# AKS Scheduled Query Alerts (CPU/Mem/Disk)
locals {
  aks_ids_effective = toset(distinct(compact(concat(
    [
      try(data.terraform_remote_state.platform.outputs.ids.aks,       null),
      try(data.terraform_remote_state.platform.outputs.aks_id,        null),
      try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
    ],
    [
      try(data.terraform_remote_state.core.outputs.ids.aks,           null),
      try(data.terraform_remote_state.core.outputs.aks_id,            null),
      try(data.terraform_remote_state.core.outputs.kubernetes.id,     null),
    ],
    var.aks_resource_ids_override
  ))))

  # aks_map = { for id in local.aks_ids_effective : id => id }

  # Enable AKS alerting only where we want it
  aks_alerts_enabled_for_env = contains(["dev", "prod"], local.env_effective)
}

# --- Shared alert knobs ---
locals {
  aks_alert_frequency = "PT5M"

  aks_cpu_threshold  = 90.0
  aks_mem_threshold  = 90.0
  aks_disk_threshold = 50.0
}

# CPU (Allocatable-based)
locals {
  aks_cpu_window = "PT5M"
  aks_cpu_query  = <<-KQL
    let threshold = ${local.aks_cpu_threshold};
    let lookback  = 5m;
    let usage =
    Perf
    | where TimeGenerated > ago(lookback)
    | where ObjectName == "K8SNode" and CounterName == "cpuUsageNanoCores"
    | summarize Usage = avg(CounterValue), UsageTs = max(TimeGenerated) by Computer;
    let alloc =
    Perf
    | where TimeGenerated > ago(lookback)
    | where ObjectName == "K8SNode" and CounterName == "cpuAllocatableNanoCores"
    | summarize arg_max(TimeGenerated, CounterValue) by Computer
    | project Computer, Alloc = CounterValue, AllocTs = TimeGenerated;
    usage
    | join kind=inner alloc on Computer
    | where Alloc > 0
    | extend CpuPct = 100.0 * Usage / Alloc
    | where CpuPct >= threshold
    | extend TimeGenerated = iif(UsageTs > AllocTs, UsageTs, AllocTs)
    | project TimeGenerated, Computer, CpuPct
    | order by CpuPct desc
  KQL
}

# DEV: alerts in CORE subscription (AKS often lives in nonprod core)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_cpu_high_dev" {
  provider = azurerm.core
  for_each = (local.env_effective == "dev" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-dev-${var.region}-aks-cpu-high"
  resource_group_name = local.rg_core_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_cpu_window

  criteria {
    query                   = local.aks_cpu_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_cpu_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "CpuPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_core] }
}

# PROD: alerts in PROD subscription
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_cpu_high_prod" {
  provider = azurerm.prod
  for_each = (local.env_effective == "prod" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-prod-${var.region}-aks-cpu-high"
  resource_group_name = local.rg_env_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_cpu_window

  criteria {
    query                   = local.aks_cpu_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_cpu_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "CpuPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_env] }
}

# Memory (Allocatable-based)
locals {
  aks_mem_window = "PT5M"
  aks_mem_query  = <<-KQL
    let threshold = ${local.aks_mem_threshold};
    let lookback  = 5m;
    let used =
    Perf
    | where TimeGenerated > ago(lookback)
    | where ObjectName == "K8SNode" and CounterName == "memoryWorkingSetBytes"
    | summarize Used = avg(CounterValue), UsedTs = max(TimeGenerated) by Computer;
    let alloc =
    Perf
    | where TimeGenerated > ago(lookback)
    | where ObjectName == "K8SNode" and CounterName == "memoryAllocatableBytes"
    | summarize arg_max(TimeGenerated, CounterValue) by Computer
    | project Computer, Alloc = CounterValue, AllocTs = TimeGenerated;
    used
    | join kind=inner alloc on Computer
    | where Alloc > 0
    | extend MemPct = 100.0 * Used / Alloc
    | where MemPct >= threshold
    | extend TimeGenerated = iif(UsedTs > AllocTs, UsedTs, AllocTs)
    | project TimeGenerated, Computer, MemPct
    | order by MemPct desc
  KQL
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_mem_high_dev" {
  provider = azurerm.core
  for_each = (local.env_effective == "dev" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-dev-${var.region}-aks-mem-high"
  resource_group_name = local.rg_core_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_mem_window

  criteria {
    query                   = local.aks_mem_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_mem_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "MemPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_core] }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_mem_high_prod" {
  provider = azurerm.prod
  for_each = (local.env_effective == "prod" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-prod-${var.region}-aks-mem-high"
  resource_group_name = local.rg_env_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_mem_window

  criteria {
    query                   = local.aks_mem_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_mem_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "MemPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_env] }
}

# Disk (InsightsMetrics used_percent by mountPath)
locals {
  aks_disk_window = "PT10M"
  aks_disk_query  = <<-KQL
    let threshold = ${local.aks_disk_threshold};
    let lookback  = 10m;
    InsightsMetrics
    | where TimeGenerated > ago(lookback)
    | where Namespace == "container.azm.ms/disk"
    | where Name == "used_percent"
    | extend TagsD = todynamic(Tags)
    | extend Mount = tostring(TagsD.mountPath)
    | summarize DiskUsedPct = avg(Val), DiskTs = max(TimeGenerated) by Computer, Mount
    | where DiskUsedPct >= threshold
    | project TimeGenerated = DiskTs, Computer, Mount, DiskUsedPct
    | order by DiskUsedPct desc
  KQL
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_disk_high_dev" {
  provider = azurerm.core
  for_each = (local.env_effective == "dev" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-dev-${var.region}-aks-disk-high"
  resource_group_name = local.rg_core_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_disk_window

  criteria {
    query                   = local.aks_disk_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_disk_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "DiskUsedPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "Mount"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_core] }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_disk_high_prod" {
  provider = azurerm.prod
  for_each = (local.env_effective == "prod" && local.aks_alerts_enabled_for_env) ? local.aks_map : {}

  name                = "al-${var.product}-prod-${var.region}-aks-disk-high"
  resource_group_name = local.rg_env_name_resolved
  location            = var.location
  scopes              = [each.key]
  severity            = 2

  evaluation_frequency = local.aks_alert_frequency
  window_duration      = local.aks_disk_window

  criteria {
    query                   = local.aks_disk_query
    time_aggregation_method = "Maximum"
    threshold               = local.aks_disk_threshold
    operator                = "GreaterThanOrEqual"
    metric_measure_column   = "DiskUsedPct"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "Mount"
      operator = "Include"
      values   = ["*"]
    }
  }

  action { action_groups = [local.ag_id_env] }
}

#############################
# High-signal RG change alerts (LAW / AzureActivity)
#############################

locals {
  # Use LAW for high-signal alerts. If LAW isn't resolved, we do nothing.
  enable_high_signal_rg_alerts = var.enable_high_signal_rg_alerts

  # Exclude known "expected" automation callers to reduce deployment noise.
  # Populate with your actual service principals / managed identities (display names) that deploy infra.
  # Tip: Start empty, observe a week, then add the top noisy callers.
  rg_alert_excluded_callers = coalesce(var.rg_alert_excluded_callers, [])

  env_sub_by_env = {
    dev  = local.dev_sub
    qa   = local.qa_sub
    uat  = local.uat_sub
    prod = local.prod_sub
  }

  # RG targets to monitor (env RG + core RG if present)
  rg_alert_targets = {
    # ENV target key becomes the real env name (dev/qa/uat/prod)
    for k, v in {
      "${local.env_effective}" = {
        rg_name = local.rg_env_name_resolved
        sub_id  = lookup(local.env_sub_by_env, local.env_effective, local.env_sub)
        ag_id   = local.ag_id_env
        enabled = local.rg_env_name_resolved != null
      }

      # CORE target key becomes np-core/pr-core (or whatever you prefer)
      "${local.plane_code}-core" = {
        rg_name = local.rg_core_name_resolved
        sub_id  = local.core_sub
        ag_id   = local.ag_id_core
        enabled = local.rg_core_name_resolved != null
      }
    } : k => v if v.enabled
  }

  # Shared schedule knobs (tune as needed)
  rg_alert_freq   = "PT5M"
  rg_alert_window = "PT5M"

  # Helper: caller exclusion snippet for KQL
  # Uses "Caller" column in AzureActivity (string)
  rg_alert_kql_exclude_callers = length(local.rg_alert_excluded_callers) == 0 ? "" : format(
    "| where Caller !in (%s)",
    join(", ", [for c in local.rg_alert_excluded_callers : format("'%s'", replace(c, "'", "''"))])
  )

  # --- 6 high-signal alert definitions (edit/add/remove here) ---
  # Each entry should produce low-noise, high-value signals.
  high_signal_alert_defs = {
    # 1) RBAC changes
    rbac_changes = {
      suffix   = "rbac-changes"
      severity = 1
      desc     = "RBAC changes (role assignments/definitions) in the resource group."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where Authorization has "Microsoft.Authorization"
        | where OperationNameValue has_any (
            "Microsoft.Authorization/roleAssignments/write",
            "Microsoft.Authorization/roleAssignments/delete",
            "Microsoft.Authorization/roleDefinitions/write",
            "Microsoft.Authorization/roleDefinitions/delete"
          )
      KQL
    }

    # 2) Azure Policy changes
    policy_changes = {
      suffix   = "policy-changes"
      severity = 2
      desc     = "Policy assignment/definition changes in the resource group."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where OperationNameValue has_any (
            "Microsoft.Authorization/policyAssignments/write",
            "Microsoft.Authorization/policyAssignments/delete",
            "Microsoft.Authorization/policyDefinitions/write",
            "Microsoft.Authorization/policyDefinitions/delete",
            "Microsoft.Authorization/policySetDefinitions/write",
            "Microsoft.Authorization/policySetDefinitions/delete"
          )
      KQL
    }

    # 3) Key Vault sensitive admin operations (focus on vault config / access control)
    keyvault_admin = {
      suffix   = "kv-admin"
      severity = 2
      desc     = "Key Vault configuration/access-control changes (high signal)."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where ResourceProviderValue == "MICROSOFT.KEYVAULT"
        | where OperationNameValue has_any (
            "Microsoft.KeyVault/vaults/write",
            "Microsoft.KeyVault/vaults/delete",
            "Microsoft.KeyVault/vaults/accessPolicies/write",
            "Microsoft.KeyVault/vaults/accessPolicies/delete"
          )
      KQL
    }

    # 4) Network security perimeter changes (NSG rules / route changes / public exposure)
    network_security_changes = {
      suffix   = "netsec-changes"
      severity = 2
      desc     = "Network perimeter changes (NSG rules, routes, public IPs, gateways) in the RG."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where ResourceProviderValue == "MICROSOFT.NETWORK"
        | where OperationNameValue has_any (
            "Microsoft.Network/networkSecurityGroups/securityRules/write",
            "Microsoft.Network/networkSecurityGroups/securityRules/delete",
            "Microsoft.Network/routeTables/routes/write",
            "Microsoft.Network/routeTables/routes/delete",
            "Microsoft.Network/publicIPAddresses/write",
            "Microsoft.Network/publicIPAddresses/delete",
            "Microsoft.Network/virtualNetworkGateways/write",
            "Microsoft.Network/virtualNetworkGateways/delete",
            "Microsoft.Network/azureFirewalls/write",
            "Microsoft.Network/azureFirewalls/delete",
            "Microsoft.Network/applicationGateways/write",
            "Microsoft.Network/applicationGateways/delete",
            "Microsoft.Network/firewallPolicies/write",
            "Microsoft.Network/firewallPolicies/delete"
          )
      KQL
    }

    # 5) Deletes (broad but only delete ops; still usually high-signal)
    deletes = {
      suffix   = "resource-deletes"
      severity = 2
      desc     = "Any successful delete operations in the resource group."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where OperationNameValue endswith "/delete"
        | where ActivityStatusValue in ("Succeeded")
      KQL
    }

    # 6) Failed administrative operations (probing / mistakes / attempted changes)
    failed_admin_ops = {
      suffix   = "admin-failures"
      severity = 2
      desc     = "Failed administrative operations (attempted changes that did not succeed)."
      kql      = <<-KQL
        AzureActivity
        | where CategoryValue == "Administrative"
        | where ActivityStatusValue in ("Failure", "Failed")
      KQL
    }
  }

  # Expand into instances: { "<target>.<alert_key>" => {...} }
  high_signal_alert_instances = {
    for item in flatten([
      for t_key, t in local.rg_alert_targets : [
        for a_key, a in local.high_signal_alert_defs : {
          key      = "${t_key}.${a_key}"
          t_key    = t_key
          a_key    = a_key
          target   = t
          alertdef = a
        }
      ]
    ]) : item.key => item
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "rg_high_signal" {
  provider = azurerm.core

  for_each = (
    var.enable_high_signal_rg_alerts &&
    local.law_id != null &&
    local.rg_core_name_resolved != null
  ) ? local.high_signal_alert_instances : {}

  # for_each = (
  #   var.enable_high_signal_rg_alerts && 
  #   local.policy_alerts_enabled_for_env && 
  #   local.law_id != null && 
  #   local.rg_core_name_resolved != null
  #   ) ? local.high_signal_alert_instances : {}

  name                = "al-${var.product}-${each.value.t_key}-${var.region}-${each.value.alertdef.suffix}"
  resource_group_name = local.rg_core_name_resolved
  location            = var.location

  scopes = [local.law_id]

  severity    = each.value.alertdef.severity
  description = each.value.alertdef.desc

  evaluation_frequency = local.rg_alert_freq
  window_duration      = local.rg_alert_window

  criteria {
    query = join("\n", [
      for line in split("\n", trimspace(<<-KQL
        ${each.value.alertdef.kql}
        | where SubscriptionId == "${each.value.target.sub_id}"
        | where ResourceGroup == "${each.value.target.rg_name}"
        | project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, ResourceProviderValue, ResourceId, CorrelationId
        | order by TimeGenerated desc
      KQL
      )) : trimspace(line)
      if trimspace(line) != ""
    ])

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  action { action_groups = [each.value.target.ag_id] }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID not resolved; cannot create high-signal RG alerts."
    }
    precondition {
      condition     = local.rg_core_name_resolved != null
      error_message = "Core RG not resolved; cannot create high-signal RG alerts centrally."
    }
  }
}
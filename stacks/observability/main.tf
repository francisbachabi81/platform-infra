# =============================================================================
# Environment / plane resolution and base naming
# =============================================================================
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

# =============================================================================
# Base provider and remote state
# =============================================================================

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

# =============================================================================
# Subscription / tenant resolution and provider aliases
# =============================================================================
locals {
  product_env = var.product == "hrz" ? "usgovernment" : "public"

  core_sub    = trimspace(coalesce(var.core_subscription_id, var.subscription_id))
  core_tenant = trimspace(coalesce(var.core_tenant_id,     var.tenant_id))

  env_sub     = trimspace(var.env_subscription_id)
  env_tenant  = trimspace(coalesce(var.env_tenant_id, var.tenant_id))
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

# =============================================================================
# Caller identity and RG discovery
# =============================================================================
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

# =============================================================================
# Resource ID collection and maps
# =============================================================================
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
  nsg_flow_logs_sa_id   = try(local.nsg_flow_logs_storage.id, null)
}

# =============================================================================
# Diagnostic categories (data sources)
# =============================================================================
data "azurerm_monitor_diagnostic_categories" "kv" {
  for_each    = local.kv_map
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

# =============================================================================
# Diagnostic settings to Log Analytics
# =============================================================================
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

resource "azurerm_monitor_diagnostic_setting" "kv" {
  for_each                   = var.enable_kv_diagnostics ? data.azurerm_monitor_diagnostic_categories.kv : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in var.kv_log_categories :
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
      error_message = "LAW workspace ID could not be resolved for Key Vault diagnostics."
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
  for_each                   = var.enable_rsv_diagnostics ? local.rsv_map : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(var.rsv_log_categories)
    content { category = enabled_log.value }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Recovery Services Vault diagnostics."
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

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Cosmos diagnostics."
    }
  }
}

# =============================================================================
# Alerts and Action Groups
# =============================================================================
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

# =============================================================================
# AKS diagnostics
# =============================================================================
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

# =============================================================================
# Policy compliance – Event Grid system topic
# =============================================================================
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
}

resource "azapi_resource" "policy_state_changes" {
  provider = azapi.core

  for_each = (var.enable_policy_compliance_alerts && local.policy_alerts_enabled_for_env) ? var.policy_source_subscriptions : {}

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

# =============================================================================
# Policy compliance – Logic App and connection
# =============================================================================
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
        "expression" = "@or(equals(triggerOutputs()?['headers']?['aeg-event-type'],'SubscriptionValidation'), equals(first(triggerBody())?['eventType'],'Microsoft.EventGrid.SubscriptionValidationEvent'))"

        "actions" = {
          "Return_SubscriptionValidation_Response" = {
            "type" = "Response"
            "inputs" = {
              "statusCode" = 200
              "body" = {
                "validationResponse" = "@first(triggerBody())?['data']?['validationCode']"
              }
            }
          },
          "Manual_Validation_GET" = {
            "type" = "Http"
            "runAfter" = { "Return_SubscriptionValidation_Response" = ["Failed"] }
            "inputs" = {
              "method" = "GET"
              "uri"    = "@first(triggerBody())?['data']?['validationUrl']"
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
            "If_NonCompliant" = {
              "type"       = "If"
              "expression" = "@equals(first(triggerBody())?['data']?['complianceState'], 'NonCompliant')"

              "actions" = {
                "Compose_SubjectRaw" = {
                  "type"   = "Compose"
                  "inputs" = "@first(triggerBody())?['subject']"
                },
                "Compose_SubscriptionId" = {
                  "type"   = "Compose"
                  "inputs" = "@first(triggerBody())?['data']?['subscriptionId']"
                  "runAfter" = {
                    "Compose_SubjectRaw" = ["Succeeded"]
                  }
                },
                "Compose_ResourceGroup" = {
                  "type"   = "Compose"
                  "inputs" = "@split(outputs('Compose_SubjectRaw'), '/')[4]"
                  "runAfter" = {
                    "Compose_SubscriptionId" = ["Succeeded"]
                  }
                },
                "Compose_ProviderNamespace" = {
                  "type"   = "Compose"
                  "inputs" = "@split(outputs('Compose_SubjectRaw'), '/')[6]"
                  "runAfter" = {
                    "Compose_ResourceGroup" = ["Succeeded"]
                  }
                },
                "Compose_ResourceType" = {
                  "type"   = "Compose"
                  "inputs" = "@split(outputs('Compose_SubjectRaw'), '/')[7]"
                  "runAfter" = {
                    "Compose_ProviderNamespace" = ["Succeeded"]
                  }
                },
                "Compose_ResourceName" = {
                  "type"   = "Compose"
                  "inputs" = "@last(split(outputs('Compose_SubjectRaw'), '/'))"
                  "runAfter" = {
                    "Compose_ResourceType" = ["Succeeded"]
                  }
                },

                "Send_Email" = {
                  "type" = "ApiConnection"
                  "runAfter" = {
                    "Compose_ResourceName" = ["Succeeded"]
                  }
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
                      "Subject" = "@{concat('FedRAMP Non-Compliant: ', outputs('Compose_ResourceName'), ' (', outputs('Compose_ResourceType'), ') in RG ', outputs('Compose_ResourceGroup'), ' [', outputs('Compose_SubscriptionId'), ']')}"
                      "Body" = <<-HTML
                        <p><strong>FedRAMP Moderate non-compliant resource detected.</strong></p>

                        <h3>Resource Context</h3>
                        <p><strong>Resource ID:</strong><br />
                          @{outputs('Compose_SubjectRaw')}
                        </p>
                        <p><strong>Subscription:</strong><br />
                          @{outputs('Compose_SubscriptionId')}
                        </p>
                        <p><strong>Resource Group:</strong><br />
                          @{outputs('Compose_ResourceGroup')}
                        </p>
                        <p><strong>Provider Namespace:</strong><br />
                          @{outputs('Compose_ProviderNamespace')}
                        </p>
                        <p><strong>Resource Type:</strong><br />
                          @{outputs('Compose_ResourceType')}
                        </p>
                        <p><strong>Resource Name:</strong><br />
                          @{outputs('Compose_ResourceName')}
                        </p>

                        <h3>Policy Context</h3>
                        <p><strong>Policy Assignment:</strong><br />
                          @{first(triggerBody())?['data']?['policyAssignmentId']}
                        </p>
                        <p><strong>Policy Definition:</strong><br />
                          @{first(triggerBody())?['data']?['policyDefinitionId']}
                        </p>
                        <p><strong>Compliance State:</strong><br />
                          @{first(triggerBody())?['data']?['complianceState']}
                        </p>

                        <h3>Timestamps</h3>
                        <p><strong>Evaluation Time (Policy Scan):</strong><br />
                          @{first(triggerBody())?['data']?['timestamp']}
                        </p>
                        <p><strong>Event Time (Event Grid):</strong><br />
                          @{first(triggerBody())?['eventTime']}
                        </p>

                        <p>
                          Please remediate according to the FedRAMP Moderate baseline or move
                          this workload out of the FedRAMP boundary.
                        </p>
                      HTML
                      "BodyContentType" = "HTML"
                    }
                  }
                }
              }

              "else" = {}
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
  name                = "office365"
  resource_group_name = local.rg_core_name_resolved
  display_name        = "Office 365"
  managed_api_id      = "/subscriptions/${local.sub_core_resolved}/providers/Microsoft.Web/locations/${local.rg_core_location_resolved}/managedApis/office365"
  parameter_values    = {}
}

resource "azurerm_resource_group_template_deployment" "logicapp" {
  provider            = azurerm.core
  count               = var.enable_policy_compliance_alerts ? 1 : 0
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
  name                = "la-${var.product}-${local.plane_code}-${var.region}-policy-alerts-01"
  resource_group_name = local.rg_core_name_resolved

  depends_on = [
    azurerm_resource_group_template_deployment.logicapp
  ]
}

resource "azapi_resource_action" "manual_trigger_callback" {
  type        = "Microsoft.Logic/workflows/triggers@2019-05-01"
  resource_id = "${data.azurerm_logic_app_workflow.policy_alerts.id}/triggers/manual"
  action      = "listCallbackUrl"
  method      = "POST"
  body        = {}

  response_export_values = ["value"]

  depends_on = [azurerm_resource_group_template_deployment.logicapp]
}

locals {
  logicapp_manual_trigger_callback_url = azapi_resource_action.manual_trigger_callback.output.value
}

resource "azapi_resource" "policy_to_logicapp" {
  for_each = (var.enable_policy_compliance_alerts && local.policy_alerts_enabled_for_env) ? azapi_resource.policy_state_changes : {}

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

# =============================================================================
# Subscription budgets for policy sources
# =============================================================================
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

# =============================================================================
# NSG flow logs
# =============================================================================
locals {
  nsg_flowlog_env_sets = {
    dev  = ["hub", "dev", "qa"]
    prod = ["hub", "prod", "uat"]
  }

  nsg_flowlog_env_keys = lookup(local.nsg_flowlog_env_sets, local.env_effective, [])

  nsg_flowlog_items = flatten([
    for env_key in local.nsg_flowlog_env_keys : [
      for _, nsg_id in try(data.terraform_remote_state.network.outputs.nsg_ids_by_env[env_key], {}) : {
        id      = nsg_id
        env_key = env_key
      }
    ]
  ])

  nsg_flowlog_map = {
    for item in local.nsg_flowlog_items :
    item.id => item
  }

  network_watcher_by_env = {
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

  law_workspace_guid = coalesce(
    try(data.terraform_remote_state.core.outputs.observability.law_workspace_guid, null),
    try(data.terraform_remote_state.platform.outputs.observability.law_workspace_guid, null),
    null
  )

  nsg_flowlogs_enabled = (
    var.enable_nsg_flow_logs &&
    local.law_id != null &&
    local.law_workspace_guid != null &&
    local.nsg_flow_logs_sa_id != null &&
    length(local.nsg_flowlog_map) > 0
  )

  nsg_flowlog_map_hub = { for id, item in local.nsg_flowlog_map : id => item if item.env_key == "hub"  }
  nsg_flowlog_map_dev = { for id, item in local.nsg_flowlog_map : id => item if item.env_key == "dev"  }
  nsg_flowlog_map_qa  = { for id, item in local.nsg_flowlog_map : id => item if item.env_key == "qa"   }
  nsg_flowlog_map_prod= { for id, item in local.nsg_flowlog_map : id => item if item.env_key == "prod" }
  nsg_flowlog_map_uat = { for id, item in local.nsg_flowlog_map : id => item if item.env_key == "uat"  }
}

resource "azurerm_network_watcher_flow_log" "nsg_core" {
  provider = azurerm.core

  for_each = (local.nsg_flowlogs_enabled && contains(["dev", "prod"], local.env_effective)) ? local.nsg_flowlog_map_hub : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env[each.value.env_key].name
  resource_group_name  = local.network_watcher_by_env[each.value.env_key].rg

  target_resource_id = each.value.id
  storage_account_id = local.nsg_flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = var.nsg_flow_logs_retention_days
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
        local.nsg_flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or NSG flow-logs storage account not resolved."
    }
  }
}

resource "azurerm_network_watcher_flow_log" "nsg_dev" {
  provider = azurerm.dev

  for_each = (local.nsg_flowlogs_enabled && local.env_effective == "dev") ? local.nsg_flowlog_map_dev : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["dev"].name
  resource_group_name  = local.network_watcher_by_env["dev"].rg

  target_resource_id = each.value.id
  storage_account_id = local.nsg_flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = var.nsg_flow_logs_retention_days
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
        local.nsg_flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or NSG flow-logs storage account not resolved."
    }
  }
}

resource "azurerm_network_watcher_flow_log" "nsg_qa" {
  provider = azurerm.qa

  for_each = (local.nsg_flowlogs_enabled && local.env_effective == "dev") ? local.nsg_flowlog_map_qa : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["qa"].name
  resource_group_name  = local.network_watcher_by_env["qa"].rg

  target_resource_id = each.value.id
  storage_account_id = local.nsg_flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = var.nsg_flow_logs_retention_days
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
        local.nsg_flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or NSG flow-logs storage account not resolved."
    }
  }
}

resource "azurerm_network_watcher_flow_log" "nsg_prod" {
  provider = azurerm.prod

  for_each = (local.nsg_flowlogs_enabled && local.env_effective == "prod") ? local.nsg_flowlog_map_prod : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["prod"].name
  resource_group_name  = local.network_watcher_by_env["prod"].rg

  target_resource_id = each.value.id
  storage_account_id = local.nsg_flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = var.nsg_flow_logs_retention_days
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
        local.nsg_flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or NSG flow-logs storage account not resolved."
    }
  }
}

resource "azurerm_network_watcher_flow_log" "nsg_uat" {
  provider = azurerm.uat

  for_each = (local.nsg_flowlogs_enabled && local.env_effective == "prod") ? local.nsg_flowlog_map_uat : {}

  name = "fl-${var.product}-${each.value.env_key}-${var.region}-${basename(each.value.id)}"

  network_watcher_name = local.network_watcher_by_env["uat"].name
  resource_group_name  = local.network_watcher_by_env["uat"].rg

  target_resource_id = each.value.id
  storage_account_id = local.nsg_flow_logs_sa_id

  enabled = true
  version = 2

  retention_policy {
    enabled = true
    days    = var.nsg_flow_logs_retention_days
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
        local.nsg_flow_logs_sa_id != null
      )
      error_message = "LAW workspace (ID/GUID) or NSG flow-logs storage account not resolved."
    }
  }
}

# =============================================================================
# AzAPI providers for Cost Management Exports (subscription-scoped resources)
# =============================================================================
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

# --- Register required Resource Providers (core + env subscriptions) ---
resource "azurerm_resource_provider_registration" "cost_exports_rp_core" {
  provider = azurerm.core
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_dev" {
  provider = azurerm.dev
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_qa" {
  provider = azurerm.qa
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_uat" {
  provider = azurerm.uat
  name     = "Microsoft.CostManagementExports"
}

resource "azurerm_resource_provider_registration" "cost_exports_rp_prod" {
  provider = azurerm.prod
  name     = "Microsoft.CostManagementExports"
}

# --- RP Registration barriers (helps with eventual consistency in ARM) ---
resource "time_sleep" "wait_cost_exports_rp_core" {
  depends_on      = [azurerm_resource_provider_registration.cost_exports_rp_core]
  create_duration = "8m"
}

resource "time_sleep" "wait_cost_exports_rp_dev" {
  depends_on      = [azurerm_resource_provider_registration.cost_exports_rp_dev]
  create_duration = "8m"
}

resource "time_sleep" "wait_cost_exports_rp_qa" {
  depends_on      = [azurerm_resource_provider_registration.cost_exports_rp_qa]
  create_duration = "8m"
}

resource "time_sleep" "wait_cost_exports_rp_uat" {
  depends_on      = [azurerm_resource_provider_registration.cost_exports_rp_uat]
  create_duration = "8m"
}

resource "time_sleep" "wait_cost_exports_rp_prod" {
  depends_on      = [azurerm_resource_provider_registration.cost_exports_rp_prod]
  create_duration = "8m"
}

resource "random_string" "cost_sa_sfx" {
  length  = 5
  special = false
  upper   = false
}

locals {
  # Decide based on inputs / resolved RG, NOT on resources created in this plan
  cost_exports_enabled = var.enable_cost_exports

  # storage account name rules: lowercase, 3-24 chars, unique
  cost_exports_sa_name = substr(
    lower("saobs${var.product}${local.plane_code}${var.region}ce${random_string.cost_sa_sfx.result}"),
    0,
    24
  )

  cost_exports_schedule_from = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), var.cost_exports_schedule_start_offset))}T00:00:00Z"
  cost_exports_schedule_to   = "2035-01-01T00:00:00Z"
}

resource "azurerm_storage_account" "cost_exports" {
  provider            = azurerm.core
  count               = local.cost_exports_enabled ? 1 : 0
  name                = local.cost_exports_sa_name
  resource_group_name = local.rg_core_name_resolved
  location            = local.rg_core_location_resolved

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  tags = var.tags_extra

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core
  ]

  lifecycle {
    precondition {
      condition     = local.rg_core_name_resolved != null && local.rg_core_location_resolved != null
      error_message = "Core RG name/location not resolved; cannot create cost exports storage account."
    }
  }
}

resource "azurerm_storage_container" "cost_exports" {
  provider              = azurerm.core
  count                 = local.cost_exports_enabled ? 1 : 0
  name                  = var.cost_exports_container_name
  # storage_account_name  = azurerm_storage_account.cost_exports[0].name
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.cost_exports
  ]
}

# =============================================================================
# Cost Management exports (env subscriptions) -> core storage
# =============================================================================
locals {
  # Match your "dev => dev+qa" and "prod => prod+uat" pattern
  cost_export_env_sets = {
    dev  = ["dev", "qa"]
    prod = ["prod", "uat"]
  }

  cost_export_targets = local.cost_exports_enabled ? lookup(local.cost_export_env_sets, local.env_effective, []) : []
}

locals {
  cost_exports_destination = local.cost_exports_enabled ? {
    resourceId     = azurerm_storage_account.cost_exports[0].id
    container      = var.cost_exports_container_name
    rootFolderPath = "${var.cost_exports_root_folder}/${var.product}/${local.env_effective}/${var.region}"
  } : null
}

# ---------- DEV subscription exports ----------
resource "azapi_resource" "cost_export_dev_last_month" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_dev_mtd_daily" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_dev_manual_custom" {
  provider                  = azapi.dev
  count                     = contains(local.cost_export_targets, "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

# ---------- QA subscription exports ----------
resource "azapi_resource" "cost_export_qa_last_month" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_qa_mtd_daily" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_qa_manual_custom" {
  provider                  = azapi.qa
  count                     = contains(local.cost_export_targets, "qa") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

# ---------- PROD subscription exports ----------
resource "azapi_resource" "cost_export_prod_last_month" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_prod_mtd_daily" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_prod_manual_custom" {
  provider                  = azapi.prod
  count                     = contains(local.cost_export_targets, "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

# ---------- UAT subscription exports ----------
resource "azapi_resource" "cost_export_uat_last_month" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_uat_mtd_daily" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_uat_manual_custom" {
  provider                  = azapi.uat
  count                     = contains(local.cost_export_targets, "uat") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

# ---------- CORE subscription exports ----------
resource "azapi_resource" "cost_export_core_nonprod_last_month" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_core_nonprod_mtd_daily" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_core_nonprod_manual_custom" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "dev") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_last_month" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_mtd_daily" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

resource "azapi_resource" "cost_export_core_prod_manual_custom" {
  provider                  = azapi.core
  count                     = (local.cost_exports_enabled && local.env_effective == "prod") ? 1 : 0
  type                      = "Microsoft.CostManagement/exports@2024-08-01"
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

  response_export_values = ["identity.principalId"]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,

    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,

    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,

    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,

    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,

    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = try(azurerm_storage_account.cost_exports[0].id, null) != null
      error_message = "Cost exports storage account was not created/resolved, but exports were enabled."
    }
  }
}

# ------------------------------------------------------------
# Role assignments (static keys; principal IDs are values)
# ------------------------------------------------------------

locals {
  ce_principal_ids = {
    dev_last_month     = try(jsondecode(azapi_resource.cost_export_dev_last_month[0].output).identity.principalId, null)
    dev_mtd_daily      = try(jsondecode(azapi_resource.cost_export_dev_mtd_daily[0].output).identity.principalId, null)
    dev_manual_custom  = try(jsondecode(azapi_resource.cost_export_dev_manual_custom[0].output).identity.principalId, null)

    qa_last_month      = try(jsondecode(azapi_resource.cost_export_qa_last_month[0].output).identity.principalId, null)
    qa_mtd_daily       = try(jsondecode(azapi_resource.cost_export_qa_mtd_daily[0].output).identity.principalId, null)
    qa_manual_custom   = try(jsondecode(azapi_resource.cost_export_qa_manual_custom[0].output).identity.principalId, null)

    prod_last_month    = try(jsondecode(azapi_resource.cost_export_prod_last_month[0].output).identity.principalId, null)
    prod_mtd_daily     = try(jsondecode(azapi_resource.cost_export_prod_mtd_daily[0].output).identity.principalId, null)
    prod_manual_custom = try(jsondecode(azapi_resource.cost_export_prod_manual_custom[0].output).identity.principalId, null)

    uat_last_month     = try(jsondecode(azapi_resource.cost_export_uat_last_month[0].output).identity.principalId, null)
    uat_mtd_daily      = try(jsondecode(azapi_resource.cost_export_uat_mtd_daily[0].output).identity.principalId, null)
    uat_manual_custom  = try(jsondecode(azapi_resource.cost_export_uat_manual_custom[0].output).identity.principalId, null)

    core_np_last_month    = try(jsondecode(azapi_resource.cost_export_core_nonprod_last_month[0].output).identity.principalId, null)
    core_np_mtd_daily     = try(jsondecode(azapi_resource.cost_export_core_nonprod_mtd_daily[0].output).identity.principalId, null)
    core_np_manual_custom = try(jsondecode(azapi_resource.cost_export_core_nonprod_manual_custom[0].output).identity.principalId, null)

    core_pr_last_month    = try(jsondecode(azapi_resource.cost_export_core_prod_last_month[0].output).identity.principalId, null)
    core_pr_mtd_daily     = try(jsondecode(azapi_resource.cost_export_core_prod_mtd_daily[0].output).identity.principalId, null)
    core_pr_manual_custom = try(jsondecode(azapi_resource.cost_export_core_prod_manual_custom[0].output).identity.principalId, null)
  }

  ce_role_targets = merge(
    contains(local.cost_export_targets, "dev")  ? { dev_last_month = true, dev_mtd_daily = true, dev_manual_custom = true } : {},
    contains(local.cost_export_targets, "qa")   ? { qa_last_month  = true, qa_mtd_daily  = true, qa_manual_custom  = true } : {},
    contains(local.cost_export_targets, "prod") ? { prod_last_month = true, prod_mtd_daily = true, prod_manual_custom = true } : {},
    contains(local.cost_export_targets, "uat")  ? { uat_last_month = true, uat_mtd_daily = true, uat_manual_custom = true } : {},

    (local.cost_exports_enabled && local.env_effective == "dev")  ? { core_np_last_month = true, core_np_mtd_daily = true, core_np_manual_custom = true } : {},
    (local.cost_exports_enabled && local.env_effective == "prod") ? { core_pr_last_month = true, core_pr_mtd_daily = true, core_pr_manual_custom = true } : {}
  )

  ce_sa_scope = local.cost_exports_enabled ? azurerm_storage_account.cost_exports[0].id : null
}

resource "azurerm_role_assignment" "cost_exports_blob_contrib" {
  provider = azurerm.core

  for_each = local.cost_exports_enabled ? local.ce_role_targets : {}

  scope                = local.ce_sa_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.ce_principal_ids[each.key]

  depends_on = [
    azurerm_resource_provider_registration.cost_exports_rp_core,
    time_sleep.wait_cost_exports_rp_core,
    azurerm_storage_account.cost_exports,
    azurerm_storage_container.cost_exports,
    azurerm_resource_provider_registration.cost_exports_rp_dev,
    time_sleep.wait_cost_exports_rp_dev,
    azurerm_resource_provider_registration.cost_exports_rp_qa,
    time_sleep.wait_cost_exports_rp_qa,
    azurerm_resource_provider_registration.cost_exports_rp_uat,
    time_sleep.wait_cost_exports_rp_uat,
    azurerm_resource_provider_registration.cost_exports_rp_prod,
    time_sleep.wait_cost_exports_rp_prod,
  ]

  lifecycle {
    precondition {
      condition     = local.ce_sa_scope != null
      error_message = "Cost exports storage account scope not resolved."
    }
    precondition {
      condition     = local.ce_principal_ids[each.key] != null
      error_message = "PrincipalId not resolved for ${each.key}. Ensure the corresponding export resource is being created."
    }
  }
}
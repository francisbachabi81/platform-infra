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
    contains(["dev","qa"], local.env_effective) ? "nonprod" : "prod"
  )

  plane_full = local.plane_effective
  plane_code = local.plane_effective == "nonprod" ? "np" : "pr"

  activity_alert_location = "Global"

  ag_name_default = "ag-obs-${var.product}-${local.env_effective}-${var.region}-01"

  # Policy / compliance wiring
  egst_policy_name = "egst-${var.product}-${local.plane_code}-${var.region}-policy-compliance"
  la_policy_name   = "la-${var.product}-${local.plane_code}-${var.region}-policy-alerts"
  eges_policy_name = "eges-${var.product}-${local.plane_code}-${var.region}-policy-to-la"
}

locals {
  # Storage Accounts
  sa_log_categories = [
    "StorageRead",
    "StorageWrite",
    "StorageDelete",
  ]

  # Service Bus Namespace
  sbns_log_categories = [
    "OperationalLogs",
  ]

  # Event Hubs Namespace
  ehns_log_categories = [
    "OperationalLogs",
  ]

  # PostgreSQL Flexible Server
  pg_log_categories = [
    "PostgreSQLLogs",
    "QueryStoreRuntimeStatistics",
    "QueryStoreWaitStatistics",
  ]

  # Azure Cache for Redis
  redis_log_categories = [
    "ConnectedClientList",
    "CacheRead",
    "CacheWrite",
    "CacheDelete",
  ]

  # Application Insights component
  appi_log_categories = [
    "AppRequests",
    "AppSystemEvents",
    "AppPerformanceCounters",
    "AppAvailabilityResults",
    "AppDependencies",
    "AppExceptions",
    "AppPageViews",
    "AppTraces",
  ]

  # VPN Gateway
  vpng_log_categories = [
    "GatewayDiagnosticLog",
    "TunnelDiagnosticLog",
    "RouteDiagnosticLog",
  ]

  # Function Apps
  fa_log_categories = [
    "FunctionAppLogs",
    "AppServicePlatformLogs",
  ]

  # Web Apps
  web_log_categories = [
    "AppServiceHTTPLogs",
    "AppServiceConsoleLogs",
    "AppServiceAppLogs",
  ]

  # Application Gateway
  appgw_log_categories = [
    "ApplicationGatewayAccessLog",
    "ApplicationGatewayPerformanceLog",
    "ApplicationGatewayFirewallLog",
  ]

  # Azure Front Door / WAF
  afd_log_categories = [
    "FrontdoorAccessLog",
    "FrontdoorWebApplicationFirewallLog",
  ]

  # Filter RSV targets so we skip ones with no logs/metrics at all
  rsv_diag_targets = {
    for id, cats in data.azurerm_monitor_diagnostic_categories.rsv :
    id => cats
    if length(try(cats.logs, [])) > 0 || length(try(cats.metrics, [])) > 0
  }
}

# Prefer the Platform stack's subscription/tenant if it emitted them; otherwise fall back to workflow-injected vars.
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

# Remote state lookups
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

# Subscriptions resolved once
locals {
  product_env = var.product == "hrz" ? "usgovernment" : "public"
  core_sub    = trimspace(coalesce(var.core_subscription_id, var.subscription_id))
  core_tenant = trimspace(coalesce(var.core_tenant_id,     var.tenant_id))
  env_sub     = trimspace(var.env_subscription_id)
  env_tenant  = trimspace(coalesce(var.env_tenant_id, var.tenant_id))
}

# Explicit ENV alias
provider "azurerm" {
  alias           = "env"
  features {}
  subscription_id = local.env_sub
  tenant_id       = local.env_tenant
  environment     = local.product_env
}

# Explicit CORE alias
provider "azurerm" {
  alias           = "core"
  features {}
  subscription_id = local.core_sub
  tenant_id       = local.core_tenant
  environment     = local.product_env
}

# Who am I
data "azurerm_client_config" "core" { provider = azurerm.core }
data "azurerm_client_config" "env"  { provider = azurerm.env  }

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
  sub_core_resolved       = try(data.azurerm_client_config.core.subscription_id, null)
  sub_env_resolved        = try(data.azurerm_client_config.env.subscription_id, null)
  rg_env_name_resolved    = try(data.azurerm_resource_group.env_rg[0].name, null)
  rg_env_id_resolved      = try(data.azurerm_resource_group.env_rg[0].id,   null)
  rg_core_name_resolved   = try(data.azurerm_resource_group.core_rg[0].name, null)

  rg_core_location_resolved = try(data.azurerm_resource_group.core_rg[0].location, null)
  rg_core_id_resolved      = try(data.azurerm_resource_group.core_rg[0].id, null)
}

# Gather IDs and RGs
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

  rg_core_name = try(data.terraform_remote_state.core.outputs.meta.rg_core_name, null)
  rg_app_name  = coalesce(
    var.env_rg_name,
    try(data.terraform_remote_state.platform.outputs.meta.rg_name, null)
  )

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
      try(local.platform_ids.cosmos,                       null),
      try(local.platform_ids.cosmos1,                      null),
      try(local.platform_ids.cdb1,                         null),
      try(data.terraform_remote_state.platform.outputs.ids.cosmosdb,          null),
      try(data.terraform_remote_state.platform.outputs.cosmos.account_id,     null),
      try(data.terraform_remote_state.platform.outputs.cosmosdb.account_id,   null)
    ],
    var.cosmos_account_ids
  ))

  ids_aks = compact([
    try(data.terraform_remote_state.platform.outputs.aks.id, null),
    try(data.terraform_remote_state.platform.outputs.aks_id, null),
    try(data.terraform_remote_state.platform.outputs.ids.aks, null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ])

  ids_funcapps = compact([
    try(local.platform_ids.funcapp1, null),
    try(local.platform_ids.funcapp2, null),
    try(local.platform_ids.plan1_func, null),
  ])

  ids_webapps = compact([
    try(local.platform_ids.webapp, null),
    try(local.platform_app.web_app_id, null),
    try(local.platform_ids.app, null),
  ])

  ids_appgws = compact([
    try(data.terraform_remote_state.network.outputs.app_gateway.id, null),
    try(data.terraform_remote_state.network.outputs.application_gateway.id, null),
  ])

  ids_frontdoor = compact([
    try(data.terraform_remote_state.network.outputs.frontdoor.profile_id,  null)
  ])

  nsg_ids_flat = concat(
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.hub,  {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.dev,  {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.qa,   {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.prod, {})),
    values(try(data.terraform_remote_state.network.outputs.nsg_ids_by_env.uat,  {}))
  )

  ids_nsg = compact(local.nsg_ids_flat)


  kv_map    = { for id in local.ids_kv    : id => id }
  sa_map    = { for id in local.ids_sa    : id => id }
  sbns_map  = { for id in local.ids_sbns  : id => id }
  ehns_map  = { for id in local.ids_ehns  : id => id }
  pg_map    = { for id in local.ids_pg    : id => id }
  redis_map = { for id in local.ids_redis : id => id }
  rsv_map   = { for id in local.ids_rsv   : id => id }
  appi_map  = { for id in local.ids_appi  : id => id }
  vpng_map  = { for id in local.ids_vpng  : id => id }
  cosmos_map = { for id in local.ids_cosmos : id => id }

  fa_map     = { for id in local.ids_funcapps  : id => id }
  web_map    = { for id in local.ids_webapps   : id => id }
  appgw_map  = { for id in local.ids_appgws    : id => id }
  afd_map    = { for id in local.ids_frontdoor : id => id }

  nsg_map = {
    for id in local.ids_nsg :
    id => id
  }
}

# Diagnostic categories
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

# Diagnostic settings (to LAW)
locals {
  sub_env_target_id = local.sub_env_resolved != null ? "/subscriptions/${local.sub_env_resolved}" : null
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = {
    for id, cats in data.azurerm_monitor_diagnostic_categories.nsg :
    id => cats
    if length(try(cats.log_category_types, [])) > 0 || length(try(cats.metrics, [])) > 0
  }

  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in [
        "NetworkSecurityGroupEvent",
        "NetworkSecurityGroupRuleCounter",
      ] :
      c if contains(try(each.value.log_category_types, []), c)
    ])
    content {
      category = enabled_log.value
    }
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
  count                      = local.sub_env_target_id == null ? 0 : 1
  name                       = var.diag_name
  target_resource_id         = local.sub_env_target_id
  log_analytics_workspace_id = local.law_id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "ServiceHealth" }
  enabled_log { category = "Alert" }
  enabled_log { category = "Recommendation" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Autoscale" }
  enabled_log { category = "ResourceHealth" }

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

  enabled_log { category = "AuditEvent" }
  enabled_log { category = "AzurePolicyEvaluationDetails" }
  
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
      error_message = "LAW workspace ID could not be resolved for Key Vault diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sa" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.sa
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  # Logs: only enable StorageRead/Write/Delete if supported
  dynamic "enabled_log" {
    for_each = toset([
      for c in local.sa_log_categories :
      c if contains(try(each.value.logs, []), c)
    ])
    content { category = enabled_log.value }
  }

  # Metrics: enable all available categories
  dynamic "metric" {
    for_each = toset(try(each.value.metrics, []))
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sbns" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.sbns
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.sbns_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "ehns" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.ehns
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.ehns_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "pg" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.pg
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.pg_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "redis" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.redis
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.redis_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  for_each                   = local.rsv_map
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  enabled_log { category = "AzureSiteRecoveryJobs" }
  enabled_log { category = "AzureSiteRecoveryEvents" }
  enabled_log { category = "CoreAzureBackup" }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Recovery Services Vault diagnostics."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "appi" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.appi
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.appi_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "vpng" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.vpng
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.vpng_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "fa" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.fa
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.fa_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "web" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.web
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.web_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.appgw
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.appgw_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "afd" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.afd
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset([
      for c in local.afd_log_categories :
      c if contains(try(each.value.logs, []), c)
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

resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  for_each                   = var.enable_cosmos_diagnostics ? data.azurerm_monitor_diagnostic_categories.cosmos : {}
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  enabled_log { category = "DataPlaneRequests" }
  enabled_log { category = "QueryRuntimeStatistics" }
  enabled_log { category = "PartitionKeyRUConsumption" }
  enabled_log { category = "ControlPlaneRequests" }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for Cosmos diagnostics."
    }
  }
}

# Alerts & workbook
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

# AKS diagnostics (env-gated)
locals {
  aks_ids = toset(compact([
    try(data.terraform_remote_state.platform.outputs.ids.aks,       null),
    try(data.terraform_remote_state.platform.outputs.aks_id,        null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ]))

  aks_map          = { for id in local.aks_ids : id => id }
  aks_env_enabled  = contains(["dev","uat","prod"], local.env_effective)
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

  # Map each policy source key → RG name for the event subscription resource
  policy_system_topic_rg_name_by_key = {
    for label, cfg in var.policy_source_subscriptions :
    label => (
      label == "core"
        ? local.rg_core_name_resolved
        : try(
            data.terraform_remote_state.network.outputs.resource_groups[replace(label, "-", "_")].name,
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
      # subscription-scoped source, per entry
      source    = "/subscriptions/${each.value.subscription_id}"
      topicType = "Microsoft.PolicyInsights.PolicyStates"
    }
  }
}


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
        "inputs" = {}
      }
    }

    "actions" = {
      # 1) First handle Event Grid subscription validation handshake
      "If_SubscriptionValidation" = {
        "type"       = "If"
        "expression" = "@equals(triggerOutputs()['headers']['aeg-event-type'], 'SubscriptionValidation')"
        "actions" = {
          "Return_SubscriptionValidation_Response" = {
            "type" = "Response"
            "kind" = "Http"
            "inputs" = {
              "statusCode" = 200
              "body" = {
                # Event Grid usually posts an *array* of events for EventGridSchema
                # If your events come as an array, first(triggerBody()) is the first event.
                "validationResponse" = "@first(triggerBody())?['data']?['validationCode']"
              }
            }
          }
        }
        "else" = {
          # 2) Your original NonCompliant flow stays intact in the ELSE branch
          "If_NonCompliant" = {
            "type"       = "If"
            "expression" = "@equals(triggerBody()?['data']?['complianceState'], 'NonCompliant')"
            "actions" = {
              "Send_Email" = {
                "type"   = "ApiConnection"
                "inputs" = {
                  "host" = {
                    "connection" = {
                      "name" = "@parameters('$connections')['office365']['connectionId']"
                    }
                  }
                  "method" = "post"
                  "path"   = "/v2/Mail"
                  "body" = {
                    "To"              = var.policy_alert_email
                    "Subject"         = "FedRAMP Policy Non-Compliance Detected"
                    "Body"            = "<p><strong>FedRAMP Moderate non-compliant resource detected.</strong></p><p><strong>Resource:</strong> @{triggerBody()?['data']?['resourceId']}</p><p><strong>Policy Assignment:</strong> @{triggerBody()?['data']?['policyAssignmentId']}</p><p><strong>Policy Definition:</strong> @{triggerBody()?['data']?['policyDefinitionId']}</p><p><strong>Compliance State:</strong> @{triggerBody()?['data']?['complianceState']}</p><p><strong>Time:</strong> @{triggerBody()?['eventTime']}</p><p>Please remediate according to the FedRAMP Moderate baseline or move this workload out of the FedRAMP boundary.</p>"
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

    "outputs" = {}
  }
}

resource "azurerm_api_connection" "office365" {
  provider = azurerm.core
  name                = "office365"
  resource_group_name = local.rg_core_name_resolved
  display_name   = "Office 365"
  managed_api_id = "/subscriptions/${local.sub_core_resolved}/providers/Microsoft.Web/locations/${local.rg_core_location_resolved}/managedApis/office365"

  # You can usually leave parameter_values empty and then
  # go into the portal once to "Authorize" with an account.
  parameter_values = {}
}

resource "azurerm_resource_group_template_deployment" "logicapp" {
  provider = azurerm.core
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

resource "azapi_resource" "policy_to_logicapp" {
  for_each = (var.enable_policy_compliance_alerts && local.policy_alerts_enabled_for_env) ? azapi_resource.policy_state_changes : {}

  type      = "Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15"
  name      = "egsub-${var.product}-${local.plane_code}-${var.region}-policy-noncompliant-${each.key}"
  parent_id = each.value.id   # full system topic ID, including subscription & RG

  body = {
    properties = {
      destination = {
        endpointType = "WebHook"
        properties = {
          endpointUrl = data.azurerm_logic_app_workflow.policy_alerts.access_endpoint
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
        maxDeliveryAttempts        = 30
        eventTimeToLiveInMinutes   = 1440
      }
    }
  }

  depends_on = [
    azurerm_resource_group_template_deployment.logicapp,
  ]
}
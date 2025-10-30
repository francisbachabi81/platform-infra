locals {
  plane_full = contains(["dev", "qa"], var.env) ? "nonprod" : "prod"
  plane_code = contains(["dev", "qa"], var.env) ? "np" : "pr"
}

provider "azurerm" {
  features {}

  subscription_id = coalesce(
    var.subscription_id,
    try(data.terraform_remote_state.platform.outputs.meta.subscription, null)
  )

  tenant_id = coalesce(
    var.tenant_id,
    try(data.terraform_remote_state.platform.outputs.meta.tenant, null)
  )

  environment = var.product == "hrz" ? "usgovernment" : "public"
}

# -------------------------
# Remote state lookups
# -------------------------
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
    key                  = "platform-app/${var.product}/${var.env}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# -------------------------
# Gather IDs and RGs
# -------------------------
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
  rg_app_name  = try(data.terraform_remote_state.platform.outputs.meta.rg_name, null)

  # Per-type ID lists (skip nulls)
  ids_kv    = compact([try(local.platform_ids.kv1, null)])
  ids_sa    = compact([try(local.platform_ids.sa1, null)])
  ids_sbns  = compact([try(local.platform_ids.sbns1, null)])
  ids_ehns  = compact([try(data.terraform_remote_state.platform.outputs.eventhub.namespace_id, null)])
  ids_pg    = compact([try(local.platform_ids.postgres, null), try(local.platform_ids.cdbpg1, null)])
  ids_redis = compact([try(local.platform_ids.redis, null)])
  ids_rsv   = compact([try(local.core_ids.rsv, null)])
  ids_appi  = compact([try(local.core_ids.appi, null)])
  ids_vpng  = compact([local.net_vpng])

  ids_aks = compact([
    try(data.terraform_remote_state.platform.outputs.aks.id, null),
    try(data.terraform_remote_state.platform.outputs.aks_id, null),
    try(data.terraform_remote_state.platform.outputs.ids.aks, null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ])

  # Function Apps / Web Apps (Microsoft.Web/sites)
  ids_funcapps = compact([
    try(local.platform_ids.fa1, null),
    try(local.platform_ids.function_app, null),
    try(local.platform_app.function_app_id, null),
  ])

  ids_webapps = compact([
    try(local.platform_ids.webapp, null),
    try(local.platform_app.web_app_id, null),
    try(local.platform_ids.app, null),
  ])

  # App Gateway & Front Door
  ids_appgws = compact([
    try(data.terraform_remote_state.network.outputs.app_gateway.id, null),
    try(data.terraform_remote_state.network.outputs.application_gateway.id, null),
  ])

  ids_frontdoor = compact([
    try(data.terraform_remote_state.network.outputs.azure_front_door.profile_id, null),
    try(data.terraform_remote_state.network.outputs.front_door.id, null),
  ])

  # For-each maps
  kv_map    = { for id in local.ids_kv    : id => id }
  sa_map    = { for id in local.ids_sa    : id => id }
  sbns_map  = { for id in local.ids_sbns  : id => id }
  ehns_map  = { for id in local.ids_ehns  : id => id }
  pg_map    = { for id in local.ids_pg    : id => id }
  redis_map = { for id in local.ids_redis : id => id }
  rsv_map   = { for id in local.ids_rsv   : id => id }
  appi_map  = { for id in local.ids_appi  : id => id }
  vpng_map  = { for id in local.ids_vpng  : id => id }

  fa_map     = { for id in local.ids_funcapps  : id => id }
  web_map    = { for id in local.ids_webapps   : id => id }
  appgw_map  = { for id in local.ids_appgws    : id => id }
  afd_map    = { for id in local.ids_frontdoor : id => id }

  # aks_map = { for id in local.ids_aks : id => id }
}

# -------------------------
# Diagnostic categories
# -------------------------
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

# New: Web/Functions/AppGW/Front Door
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

# -------------------------
# Diagnostic settings (to LAW)
# NOTE: the toset(try(..., [])) pattern avoids empty dynamic "content" issues
# -------------------------
resource "azurerm_monitor_diagnostic_setting" "kv" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.kv
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "sa" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.sa
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "sbns" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.sbns
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "ehns" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.ehns
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "pg" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.pg
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "redis" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.redis
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.rsv
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "appi" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.appi
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "vpng" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.vpng
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

# New: Function Apps / Web Apps / App Gateway / Front Door
resource "azurerm_monitor_diagnostic_setting" "fa" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.fa
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "web" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.web
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.appgw
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

resource "azurerm_monitor_diagnostic_setting" "afd" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.afd
  name                       = var.diag_name
  target_resource_id         = each.key
  log_analytics_workspace_id = local.law_id

  dynamic "enabled_log" {
    for_each = toset(try(each.value.logs, []))
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
}

# -------------------------
# Alerts & workbook
# -------------------------
locals {
  action_group_id = try(data.terraform_remote_state.core.outputs.action_group.id, null)
}

resource "random_string" "sfx" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_monitor_action_group" "fallback" {
  count               = local.action_group_id == null ? 1 : 0
  name                = "ag-${var.product}-${var.env}-${random_string.sfx.result}"
  resource_group_name = coalesce(local.rg_core_name, local.rg_app_name)
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
  ag_id = coalesce(local.action_group_id, try(azurerm_monitor_action_group.fallback[0].id, null))
}

resource "azurerm_monitor_activity_log_alert" "rg_changes" {
  count               = local.rg_app_name != null && local.ag_id != null ? 1 : 0
  name                = "rg-change-${var.product}-${var.env}"
  location            = var.location
  resource_group_name = local.rg_app_name
  scopes              = ["/subscriptions/${coalesce(var.subscription_id, try(data.terraform_remote_state.platform.outputs.meta.subscription, ""))}/resourceGroups/${local.rg_app_name}"]
  description         = "Alert on administrative operations in platform RG"

  criteria {
    category = "Administrative"
  }

  action {
    action_group_id = local.ag_id
  }
}

resource "azurerm_monitor_activity_log_alert" "service_health" {
  count               = local.ag_id != null ? 1 : 0
  name                = "service-health-${var.product}-${var.env}"
  location            = var.location
  resource_group_name = coalesce(local.rg_core_name, local.rg_app_name)
  scopes              = ["/subscriptions/${coalesce(var.subscription_id, try(data.terraform_remote_state.platform.outputs.meta.subscription, ""))}"]
  description         = "Service Health incidents in this subscription"

  criteria {
    category = "ServiceHealth"
  }

  action {
    action_group_id = local.ag_id
  }
}

resource "azapi_resource" "monitor_workbook_overview" {
  count = local.rg_core_name != null ? 1 : 0

  type      = "Microsoft.Insights/workbooks@2022-04-01"
  name      = "wk-${var.product}-${var.env}-overview-${random_string.sfx.result}"
  parent_id = "/subscriptions/${coalesce(var.subscription_id, try(data.terraform_remote_state.platform.outputs.meta.subscription, ""))}/resourceGroups/${local.rg_core_name}"
  location  = var.location

  body = jsonencode({
    location   = var.location
    properties = {
      displayName    = "Observability Overview (${var.product}-${var.env})"
      version        = "1.0"
      sourceId       = "/subscriptions/${coalesce(var.subscription_id, try(data.terraform_remote_state.platform.outputs.meta.subscription, ""))}"
      category       = "workbook"
      serializedData = jsonencode({
        version = "Notebook/1.0",
        items = [{
          type = 1,
          content = {
            json = {
              query         = "AppRequests | where TimeGenerated > ago(1h) | summarize Requests = count()"
              size          = 0
              queryType     = 0
              resourceType  = "microsoft.operationalinsights/workspaces"
              visualization = "tile"
              tileSettings  = { title = "Requests (1h)", subtitle = "" }
            }
          }
        }],
        isLocked = false
      })
    }
    kind = "shared"
  })
}

# -------------------------
# AKS IDs: always read from platform outputs (even for dev)
# dev AKS lives in core subscription, but platform-app still outputs the id, so this is consistent.
# qa has none → compact() will just return [] and we won't create resources.
# -------------------------
locals {
  aks_ids = compact([
    try(data.terraform_remote_state.platform.outputs.ids.aks, null),
    try(data.terraform_remote_state.platform.outputs.aks_id, null),
    try(data.terraform_remote_state.platform.outputs.kubernetes.id, null),
  ])

  aks_map = { for id in local.aks_ids : id => id }
}

data "azurerm_monitor_diagnostic_categories" "aks" {
  for_each    = local.aks_map
  resource_id = each.value
}

locals {
  # Gate by env if you want to hard-disable for qa:
  aks_env_enabled = contains(["dev","uat","prod"], var.env)
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
      enabled = true 
    }
  }

  lifecycle {
    precondition {
      condition     = local.law_id != null
      error_message = "LAW workspace ID could not be resolved for AKS diagnostics."
    }
  }
}
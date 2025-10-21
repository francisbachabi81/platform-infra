# terraform & providers
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.9.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# locals (plane-scoped)
locals {
  # product gates
  enable_public_features = var.product == "pub"
  enable_hrz_features    = var.product == "hrz"
  enable_both            = local.enable_public_features || local.enable_hrz_features

  plane_norm = contains(["np","nonprod"], lower(var.plane)) ? "nonprod" : contains(["pr","prod"], lower(var.plane)) ? "prod" : var.plane
  plane_code = local.plane_norm == "nonprod" ? "np" : "pr"
  plane_full = local.plane_norm

  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }
  plane_overlay_tags = local.plane_code == "np" ? { shared_with = "dev,qa",  criticality = "medium" } : { shared_with = "uat,prod", criticality = "high" }
  runtime_tags       = { managed_by = "terraform", deployed_via = "github-actions", layer = "core-resources" }
  tags_common        = merge(local.org_base_tags, local.plane_overlay_tags, local.runtime_tags, var.tags)

  law_name  = "law-${var.product}-${local.plane_code}-${var.region}-01"
  appi_name = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  rsv_name  = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
  rg_name_core = "rg-${var.product}-${local.plane_code}-${var.region}-core-01"

  # choose ONE of these to control scope:
  create_scope_pub  = local.enable_public_features
  create_scope_hrz  = local.enable_hrz_features
  create_scope_both = local.enable_both
}

# shared-network state (optional)
data "terraform_remote_state" "shared" {
  count   = var.shared_state_enabled ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = "shared-network/${var.product}/${local.plane_full}/terraform.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}

module "rg_core_platform" {
  # pick one scope below by swapping create_scope_*:
  count    = (var.create_rg_core_platform && local.create_scope_both) ? 1 : 0
  source   = "../../modules/resource-group"
  name     = local.rg_name_core
  location = var.location
  tags     = merge(local.tags_common, { purpose = "core-resources" })
}

resource "azurerm_log_analytics_workspace" "plane" {
  count               = (var.create_log_analytics && local.create_scope_both) ? 1 : 0
  name                = local.law_name
  location            = var.location
  resource_group_name = local.rg_name_core
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags                = merge(local.tags_common, { service = "log-analytics", plane = local.plane_code })
  depends_on          = [module.rg_core_platform]
}

resource "azurerm_application_insights" "plane" {
  count                      = (var.create_application_insights && var.create_log_analytics && local.create_scope_both) ? 1 : 0
  name                       = local.appi_name
  location                   = var.location
  resource_group_name        = local.rg_name_core
  application_type           = "web"
  workspace_id               = azurerm_log_analytics_workspace.plane[0].id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags                       = merge(local.tags_common, { service = "application-insights", plane = local.plane_code })
  depends_on                 = [module.rg_core_platform, azurerm_log_analytics_workspace.plane]
}

resource "azurerm_recovery_services_vault" "plane" {
  count               = (var.create_recovery_vault && local.create_scope_both) ? 1 : 0
  name                = local.rsv_name
  location            = var.location
  resource_group_name = local.rg_name_core
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = merge(local.tags_common, { service = "recovery-services-vault", plane = local.plane_code })
  depends_on          = [module.rg_core_platform]
}

locals {
  action_group_name = "ag-${var.product}-${local.plane_code}-${var.region}-core-01"
}

resource "azurerm_monitor_action_group" "core" {
  count               = (var.create_action_group && local.create_scope_both) ? 1 : 0
  name                = local.action_group_name
  resource_group_name = local.rg_name_core
  short_name          = var.action_group_short_name
  enabled             = true
  tags                = merge(local.tags_common, { service = "monitor-action-group", plane = local.plane_code })

  dynamic "email_receiver" {
    for_each = var.action_group_email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = try(email_receiver.value.use_common_alert_schema, true)
    }
  }

  depends_on = [module.rg_core_platform]
}

data "azurerm_resource_group" "core" {
  name = local.rg_name_core
}

resource "azurerm_monitor_activity_log_alert" "rg_admin_ops" {
  name                = "ala-${var.product}-${local.plane_code}-${var.region}-core-admin"
  resource_group_name = local.rg_name_core
  scopes              = [data.azurerm_resource_group.core.id]
  description         = "Admin ops on core RG"
  enabled             = true
  location = var.location

  criteria {
    category       = "Administrative"
    resource_group = local.rg_name_core
    operation_name = [
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete"
    ]
    # you can add more filters like status, caller, etc.
  }

  action {
    action_group_id = azurerm_monitor_action_group.core[0].id
  }
}

resource "azurerm_monitor_metric_alert" "appi_failures" {
  count               = length(azurerm_application_insights.plane) > 0 ? 1 : 0
  name                = "mal-${var.product}-${local.plane_code}-${var.region}-core-appi-fail"
  resource_group_name = local.rg_name_core
  scopes              = [azurerm_application_insights.plane[0].id]
  description         = "App Insights request failures > 0"
  severity            = 2
  enabled             = true
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.core[0].id
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "heartbeat_missing" {
  count               = length(azurerm_log_analytics_workspace.plane) > 0 ? 1 : 0
  name                = "sq-${var.product}-${local.plane_code}-${var.region}-core-heartbeat"
  resource_group_name = local.rg_name_core
  location            = var.location
  enabled             = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
  severity             = 2
  scopes               = [azurerm_log_analytics_workspace.plane[0].id]
  display_name         = "Heartbeat missing (10m)"

  criteria {
    query = <<KQL
Heartbeat
| where TimeGenerated > ago(10m)
| summarize hb = count()
    KQL
    time_aggregation_method = "Count"
    operator                = "LessThan"
    threshold               = 1
  }

  action {
    action_groups = [azurerm_monitor_action_group.core[0].id]
  }
}

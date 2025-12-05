terraform {
  required_version = ">= 1.6.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

# Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Locals – plane, tags, naming
locals {
  enable_public_features = var.product == "pub"
  enable_hrz_features    = var.product == "hrz"
  enable_both            = local.enable_public_features || local.enable_hrz_features

  plane_norm = contains(["np", "nonprod"], lower(var.plane)) ? "nonprod" : contains(["pr", "prod"],   lower(var.plane)) ? "prod"    : var.plane

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

  runtime_tags = {
    managed_by    = "terraform"
    deployed_via  = "github-actions"
    layer         = "core-resources"
  }

  tags_common = merge(
    local.org_base_tags,
    local.plane_overlay_tags,
    local.runtime_tags,
    var.tags,
  )

  law_name     = "law-${var.product}-${local.plane_code}-${var.region}-01"
  appi_name    = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  rsv_name     = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
  rg_name_core = "rg-${var.product}-${local.plane_code}-${var.region}-core-01"

  # Scope switches
  create_scope_pub  = local.enable_public_features
  create_scope_hrz  = local.enable_hrz_features
  create_scope_both = local.enable_both

  acs_name       = "acs-${var.product}-${local.plane_code}-${var.region}-01"
  email_svc_name = "acse-${var.product}-${local.plane_code}-${var.region}-01"

  # Azure Gov (hrz) = "usgov", Azure Commercial (pub) = "United States"
  acs_data_location   = var.product == "hrz" ? "usgov" : "United States"
  email_data_location = local.acs_data_location
}

# Remote state – shared-network
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

# Core RG
module "rg_core_platform" {
  count    = (var.create_rg_core_platform && local.create_scope_both) ? 1 : 0
  source   = "../../modules/resource-group"
  name     = local.rg_name_core
  location = var.location

  tags = merge(local.tags_common, { purpose = "core-resources" })
}

data "azurerm_resource_group" "core" {
  count = var.create_rg_core_platform ? 0 : 1
  name  = local.rg_name_core
}

locals {
  core_rg_id = var.create_rg_core_platform ? module.rg_core_platform[0].id : data.azurerm_resource_group.core[0].id
}

# Log Analytics, App Insights, Recovery Vault
resource "azurerm_log_analytics_workspace" "plane" {
  count               = (var.create_log_analytics && local.create_scope_both) ? 1 : 0
  name                = local.law_name
  location            = var.location
  resource_group_name = local.rg_name_core
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  daily_quota_gb    = var.law_daily_quota_gb

  tags = merge(local.tags_common, {
    service = "log-analytics"
    plane   = local.plane_code
  })

  depends_on = [module.rg_core_platform]
}

resource "time_sleep" "after_law" {
  count           = length(azurerm_log_analytics_workspace.plane)
  depends_on      = [azurerm_log_analytics_workspace.plane]
  create_duration = "300s"
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

  tags = merge(local.tags_common, {
    service = "application-insights"
    plane   = local.plane_code
  })

  depends_on = [
    module.rg_core_platform,
    azurerm_log_analytics_workspace.plane,
  ]
}

resource "azurerm_recovery_services_vault" "plane" {
  count               = (var.create_recovery_vault && local.create_scope_both) ? 1 : 0
  name                = local.rsv_name
  location            = var.location
  resource_group_name = local.rg_name_core
  sku                 = "Standard"
  soft_delete_enabled = true

  tags = merge(local.tags_common, {
    service = "recovery-services-vault"
    plane   = local.plane_code
  })

  depends_on = [module.rg_core_platform]
}

# Action Group
locals {
  action_group_name       = "ag-${var.product}-${local.plane_code}-${var.region}-core-01"
  action_group_short_name = "${upper(var.product)}CoreAG"
}

resource "azurerm_monitor_action_group" "core" {
  count               = (var.create_action_group && local.create_scope_both) ? 1 : 0
  name                = local.action_group_name
  resource_group_name = local.rg_name_core
  short_name          = local.action_group_short_name
  enabled             = true

  tags = merge(local.tags_common, {
    service = "monitor-action-group"
    plane   = local.plane_code
  })

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

# Activity Log Alerts – Core RG
resource "azurerm_monitor_activity_log_alert" "rg_admin_write" {
  name                = "ala-${var.product}-${local.plane_code}-${var.region}-core-admin-write"
  resource_group_name = local.rg_name_core
  scopes              = [local.core_rg_id]
  description         = "Admin WRITE ops on core RG"
  enabled             = true
  location            = "Global"

  criteria {
    category       = "Administrative"
    resource_group = local.rg_name_core
    operation_name = "Microsoft.Resources/subscriptions/resourcegroups/write"
  }

  dynamic "action" {
    for_each = length(azurerm_monitor_action_group.core) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.core[0].id
    }
  }

  depends_on = [
    module.rg_core_platform,
    azurerm_monitor_action_group.core,
  ]
}

resource "azurerm_monitor_activity_log_alert" "rg_admin_delete" {
  name                = "ala-${var.product}-${local.plane_code}-${var.region}-core-admin-delete"
  resource_group_name = local.rg_name_core
  scopes              = [local.core_rg_id]
  description         = "Admin DELETE ops on core RG"
  enabled             = true
  location            = "Global"

  criteria {
    category       = "Administrative"
    resource_group = local.rg_name_core
    operation_name = "Microsoft.Resources/subscriptions/resourcegroups/delete"
  }

  dynamic "action" {
    for_each = length(azurerm_monitor_action_group.core) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.core[0].id
    }
  }

  depends_on = [
    module.rg_core_platform,
    azurerm_monitor_action_group.core,
  ]
}

# Metrics / Scheduled Query Alerts
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
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0
  }

  dynamic "action" {
    for_each = length(azurerm_monitor_action_group.core) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.core[0].id
    }
  }

  depends_on = [
    module.rg_core_platform,
    azurerm_application_insights.plane,
    azurerm_monitor_action_group.core,
  ]
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "heartbeat_missing" {
  count                = length(azurerm_log_analytics_workspace.plane) > 0 ? 1 : 0
  name                 = "sq-${var.product}-${local.plane_code}-${var.region}-core-heartbeat"
  resource_group_name  = azurerm_log_analytics_workspace.plane[0].resource_group_name
  location             = azurerm_log_analytics_workspace.plane[0].location
  enabled              = true
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

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  dynamic "action" {
    for_each = length(azurerm_monitor_action_group.core) > 0 ? [1] : []
    content {
      action_groups = [azurerm_monitor_action_group.core[0].id]
    }
  }

  depends_on = [
    module.rg_core_platform,
    azurerm_log_analytics_workspace.plane,
    time_sleep.after_law,
    azurerm_monitor_action_group.core,
  ]
}

# Communication Services
module "communication" {
  source = "../../modules/communication"

  resource_group_name = local.rg_name_core
  location            = var.location
  acs_name            = local.acs_name
  email_service_name  = local.email_svc_name

  # geography, not Azure region
  data_location = local.acs_data_location

  enable_custom_domain    = var.enable_custom_domain
  custom_domain_name      = var.custom_domain_name
  associate_custom_domain = var.associate_custom_domain

  tags = merge(local.tags_common, { service = "communication" })

  depends_on = [module.rg_core_platform]
}

# Core VM (GHA runner)
locals {
  core_vm_subnet_id = var.shared_state_enabled ? lookup(
        lookup(data.terraform_remote_state.shared[0].outputs.subnet_ids_by_env, "hub", {}),
        "internal",
        null,) : null

  core_vm_name = "vm-${var.product}-${local.plane_code}-${var.region}-gha"
}

module "core_vm" {
  count = (var.create_core_vm && var.shared_state_enabled) ? 1 : 0

  source = "../../modules/linux-vm"

  name                = local.core_vm_name
  resource_group_name = local.rg_name_core
  location            = var.location

  subnet_id          = local.core_vm_subnet_id
  private_ip_address = var.core_vm_private_ip

  admin_username = var.core_vm_admin_username
  admin_password = var.core_vm_admin_password

  vm_size         = var.core_runner_vm_size
  image_publisher = var.core_runner_vm_image_publisher
  image_offer     = var.core_runner_vm_image_offer
  image_sku       = var.core_runner_vm_image_sku
  image_version   = var.core_runner_vm_image_version

  tags = merge(local.tags_common, { purpose = "gha-runner" })

  depends_on = [module.rg_core_platform]
}
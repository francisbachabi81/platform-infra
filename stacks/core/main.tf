############################################
# terraform & providers
############################################
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

############################################
# locals (plane-scoped)
############################################
locals {
  plane_code = var.plane
  plane_full = var.plane == "np" ? "nonprod" : "prod"

  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }
  plane_overlay_tags = local.plane_code == "np" ? { shared_with = "dev,qa",  criticality = "medium" } : { shared_with = "uat,prod", criticality = "high" }
  runtime_tags       = { managed_by = "terraform", deployed_via = "github-actions", layer = "plane-resources" }
  tags_common        = merge(local.org_base_tags, local.plane_overlay_tags, local.runtime_tags, var.tags)

  # names
  law_name  = "law-${var.product}-${local.plane_code}-${var.region}-01"
  appi_name = "appi-${var.product}-${local.plane_code}-${var.region}-01"
  rsv_name  = "rsv-${var.product}-${local.plane_code}-${var.region}-01"
}

############################################
# shared-network state (for consistency, not strictly required here)
############################################
data "terraform_remote_state" "shared" {
  count   = var.shared_state_enabled ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_rg_name
    storage_account_name = var.state_sa_name
    container_name       = var.state_container_name
    key                  = "shared-network/${local.plane_full}/terraform.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}

############################################
# log analytics workspace (plane)
############################################
resource "azurerm_log_analytics_workspace" "plane" {
  name                = local.law_name
  location            = var.location
  resource_group_name = var.rg_plane_name
  sku                 = var.law_sku
  retention_in_days   = var.law_retention_days
  tags                = merge(local.tags_common, { service = "log-analytics", plane = local.plane_code })
}

############################################
# application insights (workspace-based)
############################################
resource "azurerm_application_insights" "plane" {
  name                       = local.appi_name
  location                   = var.location
  resource_group_name        = var.rg_plane_name
  application_type           = "web"
  workspace_id               = azurerm_log_analytics_workspace.plane.id
  internet_ingestion_enabled = var.appi_internet_ingestion_enabled
  internet_query_enabled     = var.appi_internet_query_enabled
  tags                       = merge(local.tags_common, { service = "application-insights", plane = local.plane_code })
}

############################################
# recovery services vault (plane)
############################################
resource "azurerm_recovery_services_vault" "plane" {
  name                = local.rsv_name
  location            = var.location
  resource_group_name = var.rg_plane_name
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = merge(local.tags_common, { service = "recovery-services-vault", plane = local.plane_code })
}
# terraform + provider (Azure Gov only)
terraform {
  required_version = ">= 1.6.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  environment     = "usgovernment"       # Always Azure Gov for ACR
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# locals
locals {
  product    = "global"     # Registry is only for hrz
  plane_full = "prod"    # Always prod
  plane_code = "pr"

  org_base_tags = {
    product      = local.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }

  plane_overlay_tags = {
    shared_with = "all"
    criticality = "high"
  }

  runtime_tags = {
    managed_by   = "terraform"
    deployed_via = "github-actions"
    layer        = "platform-registry"
  }

  tags_common = merge(
    local.org_base_tags,
    local.plane_overlay_tags,
    local.runtime_tags,
    var.tags
  )

  rg_name = "rg-core-${local.plane_code}-${var.region}-01-reg"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location

  tags = merge(
    local.tags_common,
    { purpose = "platform-registry" }
  )
}

# ACR
module "acr" {
  source = "../../modules/acr"

  registry_name       = var.registry_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku                        = var.acr_sku
  admin_enabled              = false
  public_network_access      = true
  anonymous_pull_enabled     = false
  retention_untagged_days    = var.retention_untagged_days
  retention_untagged_enabled = true
  zone_redundancy_enabled    = var.zone_redundancy_enabled

  georeplication_locations = var.georeplication_locations

  role_assignments = var.role_assignments

  tags = local.tags_common
}
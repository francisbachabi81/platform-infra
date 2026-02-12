terraform {
  required_version = ">= 1.6.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.7"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }

  # Required so your `terraform init -backend-config="..."` has a backend to override
  backend "azurerm" {}
}

# AzAPI provider (needed for workbook via AzAPI)
provider "azapi" {}

provider "azapi" {
  alias           = "core"
  subscription_id = coalesce(var.core_subscription_id, var.subscription_id)
  tenant_id       = coalesce(var.core_tenant_id, var.tenant_id)
}
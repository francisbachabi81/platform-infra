terraform {
  required_version = ">= 1.6.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }

  # Required so your `terraform init -backend-config="..."` has a backend to override
  backend "azurerm" {}
}

# AzAPI provider (needed for workbook via AzAPI)
provider "azapi" {}

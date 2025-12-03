
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name                               = var.name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  kind                                = "GlobalDocumentDB"
  offer_type                          = "Standard"
  public_network_access_enabled       = false
  is_virtual_network_filter_enabled   = true

  # Cap the sum of provisioned RU/s across the account
  dynamic "capacity" {
    for_each = var.total_throughput_limit == null ? [] : [1]
    content {
      total_throughput_limit = var.total_throughput_limit
    }
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  ip_range_filter = []
  tags            = var.tags
}

locals {
  cosmos_name_cleaned     = length(trimspace(var.name)) > 0 ? replace(lower(trimspace(var.name)), "-", "") : "cosmosdb"
  sql_pdns_name_public = "privatelink.documents.azure.com"
  sql_pdns_name_gov    = "privatelink.documents.azure.us"

  sql_pdns_name = var.product == "hrz" ? local.sql_pdns_name_gov : local.sql_pdns_name_public

  sql_pdns_id = lookup(var.private_dns_zone_ids, local.sql_pdns_name, null)

  pe_sql_name_effective   = coalesce(var.pe_sql_name,  "pep-${local.cosmos_name_cleaned}-sql")
  psc_sql_name_effective  = coalesce(var.psc_sql_name, "psc-${local.cosmos_name_cleaned}-sql")
  sql_zone_group_name     = coalesce(var.sql_zone_group_name, "pdns-${local.cosmos_name_cleaned}-sql")
}

resource "azurerm_private_endpoint" "sql" {
  name                = local.pe_sql_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_sql_name_effective
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.sql_pdns_id == null ? [] : [1]
    content {
      name                 = local.sql_zone_group_name
      private_dns_zone_ids = [local.sql_pdns_id]
    }
  }

  tags = var.tags
}

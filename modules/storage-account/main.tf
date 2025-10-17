terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_storage_account" "sa" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.replication_type
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  tags                            = var.tags
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.container_names)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

locals {
  sa_name_cleaned = replace(lower(trimspace(var.name)), "-", "")

  blob_pdns_id = lookup(var.private_dns_zone_ids, "privatelink.blob.core.windows.net", null)
  file_pdns_id = lookup(var.private_dns_zone_ids, "privatelink.file.core.windows.net",  null)

  pe_blob_name_effective   = coalesce(var.pe_blob_name,  "pep-${local.sa_name_cleaned}-blob")
  psc_blob_name_effective  = coalesce(var.psc_blob_name, "psc-${local.sa_name_cleaned}-blob")
  blob_zone_group_effective = coalesce(var.blob_zone_group_name, "pdns-${local.sa_name_cleaned}-blob")

  pe_file_name_effective   = coalesce(var.pe_file_name,  "pep-${local.sa_name_cleaned}-file")
  psc_file_name_effective  = coalesce(var.psc_file_name, "psc-${local.sa_name_cleaned}-file")
  file_zone_group_effective = coalesce(var.file_zone_group_name, "pdns-${local.sa_name_cleaned}-file")
}

resource "azurerm_private_endpoint" "blob" {
  name                = local.pe_blob_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_blob_name_effective
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.blob_pdns_id == null ? [] : [1]
    content {
      name                 = local.blob_zone_group_effective
      private_dns_zone_ids = [local.blob_pdns_id]
    }
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "file" {
  name                = local.pe_file_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_file_name_effective
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.file_pdns_id == null ? [] : [1]
    content {
      name                 = local.file_zone_group_effective
      private_dns_zone_ids = [local.file_pdns_id]
    }
  }

  depends_on = [azurerm_private_endpoint.blob]
  tags       = var.tags
}
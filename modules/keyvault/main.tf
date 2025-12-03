terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  name_clean              = lower(trimspace(var.name))
  name_nodash             = replace(local.name_clean, "-", "")
  is_hrz = var.product == "hrz"
  kv_pdz_pub = "privatelink.vaultcore.azure.net"
  kv_pdz_gov = "privatelink.vaultcore.usgovcloudapi.net"
  kv_pdz_name = local.is_hrz ? local.kv_pdz_gov : local.kv_pdz_pub
  kv_pdns_zone_id = lookup(var.private_dns_zone_ids, local.kv_pdz_name, null)

  pe_name_effective       = coalesce(var.pe_name,               "pep-${local.name_nodash}")
  psc_name_effective      = coalesce(var.psc_name,              "psc-${local.name_nodash}")
  zone_group_name_effective = coalesce(var.pe_dns_zone_group_name, "pdns-${local.name_nodash}")
}

resource "azurerm_key_vault" "this" {
  name                      = var.name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tenant_id                 = var.tenant_id
  sku_name                  = var.sku_name
  enable_rbac_authorization = true

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days

  public_network_access_enabled = false
  tags                           = var.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = local.pe_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_name_effective
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = var.subresource_names
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.kv_pdns_zone_id == null ? [] : [1]
    content {
      name                 = local.zone_group_name_effective
      private_dns_zone_ids = [local.kv_pdns_zone_id]
    }
  }

  tags = var.tags
}

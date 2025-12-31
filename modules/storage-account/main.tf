terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  cmk_effective = var.cmk_enabled && var.cmk_key_vault_id != null && var.cmk_key_name != null
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

  # Explicit deny-by-default (helps satisfy "restrict network access" findings)
  dynamic "network_rules" {
    for_each = var.restrict_network_access ? [1] : []
    content {
      default_action = "Deny"
      bypass         = ["AzureServices"]
    }
  }

  # Required for CMK (only when enabled)
  dynamic "identity" {
    for_each = local.cmk_effective ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.cmk[0].id]
    }
  }
}

resource "azurerm_user_assigned_identity" "cmk" {
  count               = local.cmk_effective ? 1 : 0
  name                = coalesce(var.cmk_identity_name, "uai-${replace(lower(var.name), "-", "")}-cmk-01")
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "cmk_kv_crypto" {
  count                = local.cmk_effective ? 1 : 0
  scope                = var.cmk_key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.cmk[0].principal_id
}

resource "azurerm_storage_account_customer_managed_key" "cmk" {
  count                    = local.cmk_effective ? 1 : 0
  storage_account_id       = azurerm_storage_account.sa.id

  key_vault_id             = var.cmk_key_vault_id
  key_name                 = var.cmk_key_name
  key_version              = var.cmk_key_version # optional (null = latest)

  user_assigned_identity_id = azurerm_user_assigned_identity.cmk[0].id

  depends_on = [
    azurerm_role_assignment.cmk_kv_crypto
  ]
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.container_names)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

locals {
  sa_name_cleaned = replace(lower(trimspace(var.name)), "-", "")

  is_hrz = var.product == "hrz"

  blob_pdz_pub = "privatelink.blob.core.windows.net"
  blob_pdz_gov = "privatelink.blob.core.usgovcloudapi.net"

  file_pdz_pub = "privatelink.file.core.windows.net"
  file_pdz_gov = "privatelink.file.core.usgovcloudapi.net"

  blob_pdz_name = local.is_hrz ? local.blob_pdz_gov : local.blob_pdz_pub
  file_pdz_name = local.is_hrz ? local.file_pdz_gov : local.file_pdz_pub

  blob_pdns_id = lookup(var.private_dns_zone_ids, local.blob_pdz_name, null)
  file_pdns_id = lookup(var.private_dns_zone_ids, local.file_pdz_name, null)

  pe_blob_name_effective    = coalesce(var.pe_blob_name, "pep-${local.sa_name_cleaned}-blob")
  psc_blob_name_effective   = coalesce(var.psc_blob_name, "psc-${local.sa_name_cleaned}-blob")
  blob_zone_group_effective = coalesce(var.blob_zone_group_name, "pdns-${local.sa_name_cleaned}-blob")

  pe_file_name_effective    = coalesce(var.pe_file_name, "pep-${local.sa_name_cleaned}-file")
  psc_file_name_effective   = coalesce(var.psc_file_name, "psc-${local.sa_name_cleaned}-file")
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
    for_each = (var.pe_subnet_id != null && local.blob_pdns_id != null) ? [1] : []
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
    for_each = (var.pe_subnet_id != null && local.file_pdns_id != null) ? [1] : []
    content {
      name                 = local.file_zone_group_effective
      private_dns_zone_ids = [local.file_pdns_id]
    }
  }

  depends_on = [azurerm_private_endpoint.blob]
  tags       = var.tags
}
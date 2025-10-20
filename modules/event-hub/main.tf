terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# locals
locals {
  is_premium_sku          = lower(var.namespace_sku) == "premium"
  ns_name_clean           = replace(lower(trimspace(var.namespace_name)), "-", "")
  create_pe               = var.enable_private_endpoint && var.pe_subnet_id != null && var.private_dns_zone_id != null
  pe_name_effective       = coalesce(var.pe_name,            "pep-${local.ns_name_clean}-namespace")
  psc_name_effective      = coalesce(var.psc_name,           "psc-${local.ns_name_clean}-namespace")
  pe_zone_group_effective = coalesce(var.pe_zone_group_name, "pdns-${local.ns_name_clean}-namespace")
}

# event hubs namespace
resource "azurerm_eventhub_namespace" "ns" {
  name                = var.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku      = var.namespace_sku
  capacity = local.is_premium_sku ? var.namespace_capacity : null

  auto_inflate_enabled     = var.auto_inflate_enabled
  maximum_throughput_units = var.auto_inflate_enabled ? var.maximum_throughput_units : null

  minimum_tls_version           = var.min_tls_version
  public_network_access_enabled = var.public_network_access_enabled

  tags = merge(var.tags, {
    service = "event-hubs"
    purpose = "streaming-ingest"
  })
}

# event hub
resource "azurerm_eventhub" "hub" {
  name                = var.eventhub_name
  namespace_id   = azurerm_eventhub_namespace.ns.id
  # namespace_name      = azurerm_eventhub_namespace.ns.name
  # resource_group_name = var.resource_group_name

  partition_count   = var.partition_count
  message_retention = var.message_retention_in_days
}

# private endpoint (optional)
resource "azurerm_private_endpoint" "pe" {
  count               = local.create_pe ? 1 : 0
  name                = local.pe_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_name_effective
    private_connection_resource_id = azurerm_eventhub_namespace.ns.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = local.pe_zone_group_effective
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = merge(var.tags, { purpose = "event-hubs-pe" })
}
locals {
  has_workers = try(var.node_count, 0) > 0
}

# ---------- Variant A: WITH workers ----------
resource "azurerm_cosmosdb_postgresql_cluster" "with_workers" {
  count               = local.has_workers ? 1 : 0
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Coordinator
  coordinator_server_edition      = var.coordinator_server_edition
  coordinator_vcore_count         = var.coordinator_vcore_count
  coordinator_storage_quota_in_mb = var.coordinator_storage_quota_in_mb

  # Workers (present only in this variant)
  node_count               = var.node_count
  node_vcores              = var.node_vcore_count
  node_server_edition      = var.node_server_edition
  node_storage_quota_in_mb = var.node_storage_quota_in_mb

  citus_version          = var.citus_version
  preferred_primary_zone = var.preferred_primary_zone

  administrator_login_password = var.administrator_login_password
  tags                         = var.tags
}

# ---------- Variant B: NO workers (node_count = 0) ----------
resource "azurerm_cosmosdb_postgresql_cluster" "no_workers" {
  count               = local.has_workers ? 0 : 1
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Coordinator
  coordinator_server_edition      = var.coordinator_server_edition
  coordinator_vcore_count         = var.coordinator_vcore_count
  coordinator_storage_quota_in_mb = var.coordinator_storage_quota_in_mb

  # No worker settings at all; just set count to 0
  node_count = 0

  citus_version          = var.citus_version
  preferred_primary_zone = var.preferred_primary_zone

  administrator_login_password = var.administrator_login_password
  tags                         = var.tags
}

# Unified handles to "the cluster" regardless of variant
locals {
  cluster_id   = coalesce(try(azurerm_cosmosdb_postgresql_cluster.with_workers[0].id, null),
                          try(azurerm_cosmosdb_postgresql_cluster.no_workers[0].id, null))
  cluster_name = coalesce(try(azurerm_cosmosdb_postgresql_cluster.with_workers[0].name, null),
                          try(azurerm_cosmosdb_postgresql_cluster.no_workers[0].name, null))

  cluster_name_clean    = replace(lower(trimspace(var.name)), "-", "")
  pe_name_effective     = coalesce(var.pe_coordinator_name,  "pep-${local.cluster_name_clean}-coordinator")
  psc_name_effective    = coalesce(var.psc_coordinator_name, "psc-${local.cluster_name_clean}-coordinator")
  zone_group_name       = coalesce(var.coordinator_zone_group_name, "pdns-${local.cluster_name_clean}-coordinator")
}

# Private Endpoint points at whichever cluster exists
resource "azurerm_private_endpoint" "pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = local.pe_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.privatelink_subnet_id

  private_service_connection {
    name                           = local.psc_name_effective
    private_connection_resource_id = local.cluster_id
    subresource_names              = ["coordinator"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id == null ? [] : [1]
    content {
      name                 = local.zone_group_name
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

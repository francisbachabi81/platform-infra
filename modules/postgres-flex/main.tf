terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  is_private                    = var.network_mode == "private"
  public_network_access_enabled = !local.is_private

  # Auto-naming for replicas (only if enabled)
  effective_name = var.replica_enabled && var.auto_replica_name ? "${var.name}${var.replica_name_suffix}" : var.name
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                = local.effective_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # Primary vs Replica
  create_mode      = var.replica_enabled ? "Replica" : "Default"
  source_server_id = var.replica_enabled ? var.source_server_id : null

  # Core
  version                = var.pg_version
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_login_password
  sku_name               = var.sku_name
  storage_mb             = var.storage_mb
  zone                   = var.zone

  # Networking
  public_network_access_enabled = local.public_network_access_enabled
  delegated_subnet_id           = local.is_private ? var.delegated_subnet_id : null
  private_dns_zone_id           = local.is_private ? var.private_dns_zone_id : null

  # HA (skip when replica)
  dynamic "high_availability" {
    for_each = (!var.replica_enabled && var.ha_enabled) ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.ha_zone
    }
  }

  # Maintenance window (skip when replica)
  dynamic "maintenance_window" {
    for_each = var.replica_enabled ? [] : [1]
    content {
      day_of_week  = var.maintenance_day
      start_hour   = var.maintenance_hour
      start_minute = 0
    }
  }

  # Backups (Azure ignores these on replicas; safe to send either way)
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  # Auth (allowed for primary; ignored on replica)
  authentication {
    active_directory_auth_enabled = var.aad_auth_enabled
    password_auth_enabled         = true
    tenant_id = var.aad_auth_enabled ? coalesce(var.aad_tenant_id, data.azurerm_client_config.current.tenant_id) : null
  }

  lifecycle {
    precondition {
      condition     = !local.is_private || (var.delegated_subnet_id != null && var.private_dns_zone_id != null)
      error_message = "network_mode=private requires delegated_subnet_id and private_dns_zone_id."
    }
    precondition {
      condition     = !var.replica_enabled || (var.source_server_id != null)
      error_message = "replica_enabled=true requires source_server_id."
    }
    precondition {
      condition     = var.replica_enabled || !var.ha_enabled || (var.zone != null && var.ha_zone != null && var.zone != var.ha_zone)
      error_message = "When ha_enabled=true on a primary, zone and ha_zone must be set and different."
    }
  }

  tags = merge(
    var.tags,
    {
      role = var.replica_enabled ? "replica" : "primary"
    }
  )
}

# Databases only on primary (replica is read-only)
resource "azurerm_postgresql_flexible_server_database" "dbs" {
  for_each  = toset(var.replica_enabled ? [] : var.databases)
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}


# Firewall rules only if public mode and primary
resource "azurerm_postgresql_flexible_server_firewall_rule" "rules" {
  for_each = (!var.replica_enabled && !local.is_private) ? { for r in var.firewall_rules : r.name => r } : {}

  name              = each.key
  server_id         = azurerm_postgresql_flexible_server.pg.id
  start_ip_address  = each.value.start_ip
  end_ip_address    = each.value.end_ip
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  count     = var.enable_postgis ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.pg.id
  value     = "POSTGIS"   # comma-separate for more, e.g. "POSTGIS,PG_TRGM"
}
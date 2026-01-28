terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  is_private                    = var.network_mode == "private"
  public_network_access_enabled = !local.is_private

  api_version = coalesce(var.api_version, "2023-03-02-preview")

  cluster_body = {
    properties = {
      # NOTE:
      # AzAPI embedded schema may treat administratorLogin as read-only in some versions.
      # So we omit it and only send the password.
      administratorLoginPassword = var.administrator_login_password

      postgresqlVersion = var.pg_version
      citusVersion      = var.citus_version

      coordinatorEnablePublicIpAccess = local.public_network_access_enabled
      nodeEnablePublicIpAccess        = local.public_network_access_enabled

      coordinatorServerEdition    = var.coordinator_server_edition
      coordinatorVCores           = var.coordinator_vcores
      coordinatorStorageQuotaInMb = var.coordinator_storage_mb

      nodeCount            = var.worker_count
      nodeServerEdition    = var.worker_server_edition
      nodeVCores           = var.worker_vcores
      nodeStorageQuotaInMb = var.worker_storage_mb

      enableHa = var.ha_enabled

      maintenanceWindow = (
        var.maintenance_day == null ? null : {
          dayOfWeek   = var.maintenance_day
          startHour   = var.maintenance_hour
          startMinute = 0
        }
      )
    }
  }

  cluster_body_pruned = {
    properties = {
      for k, v in local.cluster_body.properties : k => v if v != null
    }
  }
}

resource "azapi_resource" "cluster" {
  type      = "Microsoft.DBforPostgreSQL/serverGroupsv2@${local.api_version}"
  name      = var.name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  tags = var.tags

  # AzAPI v2+: body must be an object (NOT jsonencoded string)
  body = local.cluster_body_pruned

  # If you still run into schema drift, uncomment this:
  # schema_validation_enabled = false

  lifecycle {
    precondition {
      condition     = !local.is_private || (var.private_endpoint_subnet_id != null && var.private_dns_zone_id != null)
      error_message = "network_mode=private requires private_endpoint_subnet_id and private_dns_zone_id."
    }
  }
}

resource "azurerm_private_endpoint" "pe" {
  count               = local.is_private ? 1 : 0
  name                = coalesce(var.private_endpoint_name, "pe-${var.name}")
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = coalesce(var.private_service_connection_name, "psc-${var.name}")
    private_connection_resource_id = azapi_resource.cluster.id
    is_manual_connection           = false
    subresource_names              = var.private_endpoint_subresource_names
  }

  # Prefer this over azurerm_private_dns_zone_group resource for compatibility
  private_dns_zone_group {
    name                 = coalesce(var.private_dns_zone_group_name, "pdzg-${var.name}")
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azapi_resource" "firewall_rule" {
  for_each = (!local.is_private && length(var.firewall_rules) > 0) ? { for r in var.firewall_rules : r.name => r } : {}

  type      = "Microsoft.DBforPostgreSQL/serverGroupsv2/firewallRules@${local.api_version}"
  name      = each.key
  parent_id = azapi_resource.cluster.id

  body = {
    properties = {
      startIpAddress = each.value.start_ip
      endIpAddress   = each.value.end_ip
    }
  }
}

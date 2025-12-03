terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_redis_cache" "redis" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name             = var.sku_name
  family               = var.redis_sku_family
  capacity             = var.capacity
  minimum_tls_version  = "1.2"
  non_ssl_port_enabled = false
  public_network_access_enabled = false

  tags = var.tags
}

locals {
  redis_name_clean         = replace(lower(trimspace(var.name)), "-", "")
  is_hrz = var.product == "hrz"
  redis_pdz_pub = "privatelink.redis.cache.windows.net"
  redis_pdz_gov = "privatelink.redis.cache.usgovcloudapi.net"
  redis_pdz_name = local.is_hrz ? local.redis_pdz_gov : local.redis_pdz_pub
  redis_pdns_zone_id = lookup(var.private_dns_zone_ids, local.redis_pdz_name, null)
  pe_name_effective        = coalesce(var.pe_name,              "pep-${local.redis_name_clean}")
  psc_name_effective       = coalesce(var.psc_name,             "psc-${local.redis_name_clean}")
  zone_group_name_effective= coalesce(var.zone_group_name,      "pdns-${local.redis_name_clean}")
}

resource "azurerm_private_endpoint" "redis" {
  name                = local.pe_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_name_effective
    private_connection_resource_id = azurerm_redis_cache.redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = (var.pe_subnet_id != null && local.redis_pdns_zone_id != null) ? [1] : []
    content {
      name                 = local.zone_group_name_effective
      private_dns_zone_ids = [local.redis_pdns_zone_id]
    }
  }

  tags = var.tags
}

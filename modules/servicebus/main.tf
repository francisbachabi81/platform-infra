terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  sb_is_premium = lower(var.sku) == "premium"
  create_pe     = local.sb_is_premium && var.privatelink_subnet_id != null && var.private_dns_zone_id != null

  name_clean            = replace(lower(trimspace(var.name)), "-", "")
  pe_name_effective     = coalesce(var.pe_name,  "pep-${local.name_clean}-namespace")
  psc_name_effective    = coalesce(var.psc_name, "psc-${local.name_clean}-namespace")
  zone_group_effective  = coalesce(var.zone_group_name, "pdns-${local.name_clean}-namespace")

  # sanitize collections (drop null/empty/whitespace)
  queues_set = toset([for q in coalesce(var.queues, []) : trimspace(q) if trimspace(q) != ""])
  topics_set = toset([for t in coalesce(var.topics, []) : trimspace(t) if trimspace(t) != ""])

  # optional auth rule name
  manage_policy_name_clean = try(trimspace(var.manage_policy_name), "")
}

resource "azurerm_servicebus_namespace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku      = var.sku
  capacity = local.sb_is_premium ? var.capacity : null
  # zone_redundant = local.sb_is_premium ? var.zone_redundant : false

  minimum_tls_version            = var.min_tls_version
  public_network_access_enabled  = var.public_network_access_enabled
  local_auth_enabled             = var.local_auth_enabled

  tags = var.tags
}

resource "azurerm_servicebus_queue" "q" {
  for_each     = local.queues_set
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id
}

resource "azurerm_servicebus_topic" "t" {
  for_each     = local.topics_set
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id
}

resource "azurerm_private_endpoint" "sb" {
  count               = local.create_pe ? 1 : 0
  name                = local.pe_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.privatelink_subnet_id

  private_service_connection {
    name                           = local.psc_name_effective
    private_connection_resource_id = azurerm_servicebus_namespace.this.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = local.zone_group_effective
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# resource "azurerm_servicebus_namespace_authorization_rule" "manage" {
#   count        = var.manage_policy_name != null ? 1 : 0
#   name         = var.manage_policy_name
#   namespace_id = azurerm_servicebus_namespace.this.id
#   listen       = true
#   send         = true
#   manage       = true
# }

locals {
  # legacy single rule -> map form
  legacy_rule = var.manage_policy_name != null ? {
    legacy_manage = {
      name   = var.manage_policy_name
      listen = true
      send   = true
      manage = true
    }
  } : {}

  # merge legacy + new (new wins if key collisions, names can still be different)
  auth_rules_effective = merge(local.legacy_rule, var.authorization_rules)
}

resource "azurerm_servicebus_namespace_authorization_rule" "auth" {
  for_each     = local.auth_rules_effective

  name         = each.value.name
  namespace_id = azurerm_servicebus_namespace.this.id

  listen = try(each.value.listen, true)
  send   = try(each.value.send,   true)
  manage = try(each.value.manage, true)
}

locals {
  enable_ruleset = length(var.forwarding_rules) > 0

  rules_map = {
    for idx, r in var.forwarding_rules :
    format(
      "%02d-%s",
      idx,
      regexreplace(
        regexreplace(
          regexreplace(
            lower(regexreplace(r.domain_name, "\\.$", "")),
            "[^0-9a-z-]", "-"
          ),
          "-{2,}", "-"
        ),
        "-+$", ""
      )
    ) => r
  }
  name_nodash = replace(lower(trimspace(var.name)), "-", "")
}

resource "azurerm_private_dns_resolver" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.hub_vnet_id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "pdnsri-${local.name_nodash}"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id

  ip_configurations {
    private_ip_allocation_method = var.inbound_static_ip != null ? "Static" : "Dynamic"
    subnet_id                    = var.inbound_subnet_id
    private_ip_address           = var.inbound_static_ip
  }

  tags = var.tags
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "pdnsro-${local.name_nodash}"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  subnet_id               = var.outbound_subnet_id
  tags                    = var.tags
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "rs" {
  count               = local.enable_ruleset ? 1 : 0
  name                = "pdnsrs-${local.name_nodash}"
  location            = var.location
  resource_group_name = var.resource_group_name

  private_dns_resolver_outbound_endpoint_ids = [
    azurerm_private_dns_resolver_outbound_endpoint.outbound.id
  ]

  tags = var.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "rules" {
  for_each                  = local.enable_ruleset ? local.rules_map : {}
  name                      = "rule-${each.key}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.rs[0].id
  domain_name               = each.value.domain_name
  enabled                   = true

  dynamic "target_dns_servers" {
    for_each = each.value.target_ips
    content {
      ip_address = target_dns_servers.value
      port       = 53
    }
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "links" {
  for_each                  = local.enable_ruleset ? var.vnet_links : {}
  name                      = "lnk-${each.key}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.rs[0].id
  virtual_network_id        = each.value
}

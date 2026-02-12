terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "subnets" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = (
    length(coalesce(try(each.value.address_prefixes, []), [])) > 0 ? coalesce(each.value.address_prefixes, []) : [each.value.cidr]
  )

  service_endpoints                     = try(each.value.service_endpoints, null)
  private_endpoint_network_policies     = try(each.value.private_endpoint_network_policies, null)
  # private_link_service_network_policies = try(each.value.private_link_service_network_policies, null)
  private_link_service_network_policies_enabled = try(each.value.private_link_service_network_policies_enabled, true)

  dynamic "delegation" {
    for_each = coalesce(try(each.value.delegations, []), [])
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service
        actions = coalesce(try(delegation.value.actions, []), [])
      }
    }
  }

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = { for k, s in var.subnets : k => s if try(s.nsg_id, null) != null }
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = each.value.nsg_id
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = { for k, s in var.subnets : k => s if try(s.route_table_id, null) != null }
  subnet_id      = azurerm_subnet.subnets[each.key].id
  route_table_id = each.value.route_table_id
}
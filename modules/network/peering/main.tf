locals {
  l2r_name = coalesce(var.left_to_right_name,  "peer-${var.left_vnet_name}-to-${var.right_vnet_name}")
  r2l_name = coalesce(var.right_to_left_name, "peer-${var.right_vnet_name}-to-${var.left_vnet_name}")
}

# Left to Right
resource "azurerm_virtual_network_peering" "left_to_right" {
  name                      = local.l2r_name
  resource_group_name       = var.left_rg
  virtual_network_name      = var.left_vnet_name
  remote_virtual_network_id = var.right_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.left_allow_gateway_transit
  use_remote_gateways          = false

  lifecycle {
    precondition {
      condition = !(var.left_allow_gateway_transit && var.right_allow_gateway_transit)
      error_message = "Only one side may set allow_gateway_transit=true."
    }
  }
}

# Right to Left
resource "azurerm_virtual_network_peering" "right_to_left" {
  name                      = local.r2l_name
  resource_group_name       = var.right_rg
  virtual_network_name      = var.right_vnet_name
  remote_virtual_network_id = var.left_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.right_use_remote_gateways

  lifecycle {
    precondition {
      condition = !(var.left_use_remote_gateways && var.right_use_remote_gateways)
      error_message = "Only one side may set use_remote_gateways=true."
    }
    precondition {
      condition = (
        (var.right_use_remote_gateways && var.left_allow_gateway_transit) ||
        (!var.right_use_remote_gateways && !var.left_allow_gateway_transit)
      )
      error_message = "If right_use_remote_gateways=true, left_allow_gateway_transit must be true (and vice versa)."
    }
  }
}

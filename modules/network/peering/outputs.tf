output "left_to_right_id" {
  value       = azurerm_virtual_network_peering.left_to_right.id
  description = "LEFT to RIGHT peering ID."
}

output "right_to_left_id" {
  value       = azurerm_virtual_network_peering.right_to_left.id
  description = "RIGHT to LEFT peering ID."
}

output "names" {
  value = {
    left_to_right  = azurerm_virtual_network_peering.left_to_right.name
    right_to_left  = azurerm_virtual_network_peering.right_to_left.name
  }
  description = "Effective peering resource names."
}

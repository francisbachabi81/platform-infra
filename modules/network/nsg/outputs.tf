output "nsg_ids" { value = { for k, n in azurerm_network_security_group.nsg : k => n.id } }

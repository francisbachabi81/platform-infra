output "vm_id" {
  description = "ID of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "nic_id" {
  description = "ID of the network interface attached to the VM."
  value       = azurerm_network_interface.this.id
}

output "private_ip_address" {
  description = "Static private IP address assigned to the VM."
  value       = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}
resource "azurerm_network_interface" "this" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_address
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "guest_config_linux" {
  name               = "AzurePolicyforLinux"  # required instance name for GC / Azure Policy
  virtual_machine_id = azurerm_linux_virtual_machine.this.id

  publisher            = "Microsoft.GuestConfiguration"
  type                 = "ConfigurationForLinux"
  type_handler_version = "1.0"

  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}
variable "name" {
  type        = string
  description = "Name of the VM (and base for NIC / OS disk)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group in which to create the VM and NIC."
}

variable "location" {
  type        = string
  description = "Azure region for the VM and NIC."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the NIC will be placed."
}

variable "private_ip_address" {
  type        = string
  description = "Static private IP address for the NIC within the subnet."
}

variable "admin_username" {
  type        = string
  description = "Admin username for the Linux VM."
}

variable "admin_password" {
  type        = string
  description = "Admin password for the Linux VM (pass via TF_VAR_ or var-file, sourced from a secret)."
  sensitive   = true
}

variable "vm_size" {
  type        = string
  description = "VM SKU/size (e.g. Standard_D2s_v5)."
  default     = "Standard_D2s_v5"
}

variable "image_publisher" {
  type        = string
  description = "Image publisher for the VM (e.g. Canonical)."
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "Image offer for the VM."
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type        = string
  description = "Image SKU for the VM."
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  type        = string
  description = "Image version (use \"latest\" for most recent)."
  default     = "latest"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the VM and NIC."
  default     = {}
}
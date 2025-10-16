variable "name" {
  description = "Recovery Services Vault name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "sku" {
  description = "Vault SKU."
  type        = string
  default     = "Standard"
  validation {
    condition     = var.sku == "Standard"
    error_message = "Only 'Standard' is supported for Recovery Services Vault."
  }
}

variable "soft_delete_enabled" {
  description = "Enable soft delete for protected items."
  type        = bool
  default     = true
}

variable "storage_mode_type" {
  description = "Backup storage redundancy."
  type        = string
  default     = "LocallyRedundant"
  validation {
    condition     = contains(["GeoRedundant", "LocallyRedundant", "ZoneRedundant"], var.storage_mode_type)
    error_message = "storage_mode_type must be one of: GeoRedundant, LocallyRedundant, ZoneRedundant."
  }
}

variable "cross_region_restore_enabled" {
  description = "Enable cross-region restore."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

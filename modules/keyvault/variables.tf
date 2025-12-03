variable "name" {
  type        = string
  description = "Key Vault name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "product" {
  type        = string
  description = "Cloud/product selector: 'hrz' (Azure Gov) or 'pub' (Azure public)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID."
}

variable "sku_name" {
  type        = string
  description = "Key Vault SKU (standard | premium)."
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], lower(var.sku_name))
    error_message = "sku_name must be 'standard' or 'premium'."
  }
}

variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID for the Private Endpoint."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Map of private DNS zone name ➜ ID (expects key 'privatelink.vaultcore.azure.net')."
  default     = {}
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection."
  default     = false
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Soft-delete retention days (7–90)."
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "pe_name" {
  type        = string
  description = "Custom Private Endpoint name (null = default)."
  default     = null
}

variable "psc_name" {
  type        = string
  description = "Custom Private Service Connection name (null = default)."
  default     = null
}

variable "pe_dns_zone_group_name" {
  type        = string
  description = "Custom Private DNS zone group name (null = default)."
  default     = null
}

variable "subresource_names" {
  type        = list(string)
  description = "Private Link subresource names."
  default     = ["vault"]
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}

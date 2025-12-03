variable "name" {
  description = "Redis cache name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "product" {
  type        = string
  description = "Cloud/product selector: 'hrz' (Azure Gov) or 'pub' (Azure public)"
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "sku_name" {
  description = "SKU tier."
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "sku_name must be one of: Basic, Standard, Premium."
  }
}

variable "redis_sku_family" {
  description = "SKU family: C (Basic/Standard) or P (Premium)."
  type        = string
  default     = "C"
  validation {
    condition     = contains(["C", "P"], var.redis_sku_family)
    error_message = "redis_sku_family must be 'C' or 'P'."
  }
}

variable "capacity" {
  description = "Size (e.g., 0..6 depending on tier/family)."
  type        = number
  default     = 1
}

variable "pe_subnet_id" {
  description = "Subnet ID for the Private Endpoint (privatelink subnet)."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to IDs."
  type        = map(string)
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "pe_name" {
  description = "Custom Private Endpoint name (null = auto)."
  type        = string
  default     = null
}

variable "psc_name" {
  description = "Custom Private Service Connection name (null = auto)."
  type        = string
  default     = null
}

variable "zone_group_name" {
  description = "Custom DNS zone group name (null = auto)."
  type        = string
  default     = null
}

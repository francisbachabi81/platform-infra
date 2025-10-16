variable "name" {
  description = "acr name (lowercase alphanumeric, 5–50 chars)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.name))
    error_message = "name must match ^[a-z0-9]{5,50}$."
  }
}

variable "resource_group_name" {
  description = "resource group name"
  type        = string
}

variable "location" {
  description = "azure region"
  type        = string
}

variable "sku" {
  description = "acr sku"
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "enable admin user"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "public network access"
  type        = bool
  default     = true
}

variable "network_rule_bypass_option" {
  description = "bypass: None | AzureServices"
  type        = string
  default     = "AzureServices"
  validation {
    condition     = contains(["None", "AzureServices"], var.network_rule_bypass_option)
    error_message = "network_rule_bypass_option must be None or AzureServices."
  }
}

variable "anonymous_pull_enabled" {
  description = "allow anonymous pull"
  type        = bool
  default     = false
}

variable "data_endpoint_enabled" {
  description = "enable data endpoint"
  type        = bool
  default     = false
}

variable "zone_redundancy_enabled" {
  description = "enable zone redundancy"
  type        = bool
  default     = false
}

variable "tags" {
  description = "resource tags"
  type        = map(string)
  default     = {}
}

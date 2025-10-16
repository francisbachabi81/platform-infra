variable "name" {
  type        = string
  description = "Service Bus Namespace name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "SKU tier."
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be one of: Basic, Standard, Premium."
  }
}

variable "capacity" {
  type        = number
  default     = 1
  description = "Messaging units (Premium only)."
}

variable "zone_redundant" {
  type        = bool
  default     = false
  description = "Zone redundancy (Premium, supported regions only)."
}

variable "min_tls_version" {
  type        = string
  default     = "1.2"
  description = "Minimum TLS version."
  validation {
    condition     = contains(["1.0", "1.1", "1.2"], var.min_tls_version)
    error_message = "min_tls_version must be one of: 1.0, 1.1, 1.2."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Enable public network access."
}

variable "local_auth_enabled" {
  type        = bool
  default     = false
  description = "Enable SAS (local) auth."
}

variable "queues" {
  type        = list(string)
  default     = []
  description = "Queue names to create."
}

variable "topics" {
  type        = list(string)
  default     = []
  description = "Topic names to create."
}

variable "privatelink_subnet_id" {
  type        = string
  default     = null
  description = "Privatelink subnet ID for the Private Endpoint (Premium)."
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "Private DNS zone ID for privatelink.servicebus.windows.net."
}

variable "manage_policy_name" {
  type        = string
  default     = null
  description = "Optional SAS policy name with Manage permissions."
}

variable "pe_name" {
  type        = string
  default     = null
  description = "Custom Private Endpoint name (null = default)."
}

variable "psc_name" {
  type        = string
  default     = null
  description = "Custom Private Service Connection name (null = default)."
}

variable "zone_group_name" {
  type        = string
  default     = null
  description = "Custom Private DNS zone group name (null = default)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}

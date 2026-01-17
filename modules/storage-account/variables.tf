variable "name" {
  type        = string
  description = "Storage account name (lowercase alphanumeric, 3–24 chars)."
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

variable "replication_type" {
  type        = string
  default     = "ZRS"
  description = "LRS | ZRS | RAGRS | GZRS | RAGZRS."
  validation {
    condition     = contains(["LRS", "ZRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of: LRS, ZRS, RAGRS, GZRS, RAGZRS."
  }
}

variable "container_names" {
  type        = list(string)
  default     = []
  description = "Containers to create."
}

variable "pe_subnet_id" {
  type        = string
  description = "Privatelink subnet ID."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  default     = {}
  description = "Map of Private DNS zone names to IDs (keys like privatelink.blob.core.windows.net, privatelink.file.core.windows.net)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}

variable "pe_blob_name" {
  type        = string
  default     = null
  description = "Custom Private Endpoint name for blob (null = default)."
}

variable "psc_blob_name" {
  type        = string
  default     = null
  description = "Custom Private Service Connection name for blob (null = default)."
}

variable "blob_zone_group_name" {
  type        = string
  default     = null
  description = "Custom DNS zone group name for blob (null = default)."
}

variable "pe_file_name" {
  type        = string
  default     = null
  description = "Custom Private Endpoint name for file (null = default)."
}

variable "psc_file_name" {
  type        = string
  default     = null
  description = "Custom Private Service Connection name for file (null = default)."
}

variable "file_zone_group_name" {
  type        = string
  default     = null
  description = "Custom DNS zone group name for file (null = default)."
}

variable "restrict_network_access" {
  type    = bool
  default = true
}

# variable "cmk_enabled" {
#   type    = bool
#   default = false
# }

# variable "cmk_key_vault_id" {
#   type    = string
#   default = null
# }

# variable "cmk_identity_name" {
#   type    = string
#   default = null
# }

# variable "cmk_key_name" {
#   type    = string
#   default = null
# }

# variable "cmk_key_version" {
#   type    = string
#   default = null
# }

variable "identity_type" {
  type    = string
  default = null # "UserAssigned" or null
}

variable "identity_ids" {
  type    = list(string)
  default = []
}
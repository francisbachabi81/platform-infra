variable "name" {
  type        = string
  description = "Cluster name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "node_count" {
  type        = number
  default     = 0
  description = "Worker node count (0 = coordinator-only; >=2 = multi-node)."
}

variable "coordinator_vcore_count" {
  type        = number
  description = "Coordinator vCores."
}

variable "coordinator_storage_quota_in_mb" {
  type        = number
  description = "Coordinator storage (MB)."
}

variable "coordinator_server_edition" {
  type        = string
  default     = "GeneralPurpose"
  description = "Coordinator edition (e.g., BurstableGeneralPurpose, GeneralPurpose, MemoryOptimized)."
}

variable "node_vcore_count" {
  type        = number
  description = "Worker vCores per node."
}

variable "node_server_edition" {
  type        = string
  default     = "GeneralPurpose"
  description = "Worker edition (e.g., BurstableGeneralPurpose, GeneralPurpose, MemoryOptimized)."
}

variable "node_storage_quota_in_mb" {
  type        = number
  description = "Worker storage per node (MB)."
}

variable "citus_version" {
  type        = string
  default     = null
  description = "Optional Citus version to pin."
}

variable "administrator_login_password" {
  type        = string
  sensitive   = true
  description = "Password for default 'citus' admin."
  validation {
    condition     = var.administrator_login_password != null && length(trimspace(var.administrator_login_password)) > 0
    error_message = "administrator_login_password must be non-empty."
  }
}

variable "enable_private_endpoint" {
  type        = bool
  default     = false
  description = "Create a Private Endpoint to the coordinator."
}

variable "privatelink_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for the Private Endpoint."
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "Private DNS zone ID for 'privatelink.postgres.cosmos.azure.com'."
}

variable "pe_coordinator_name" {
  type        = string
  default     = null
  description = "Override Private Endpoint name (null = auto)."
}

variable "psc_coordinator_name" {
  type        = string
  default     = null
  description = "Override Private Service Connection name (null = auto)."
}

variable "coordinator_zone_group_name" {
  type        = string
  default     = null
  description = "Override DNS zone group name (null = auto)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}

variable "preferred_primary_zone" {
  type        = string
  default     = null
  description = "Preferred primary AZ for the cluster (\"1\", \"2\", or \"3\"). Null = let Azure choose."
  validation {
    condition     = var.preferred_primary_zone == null || contains(["1","2","3"], var.preferred_primary_zone)
    error_message = "preferred_primary_zone must be one of: \"1\", \"2\", \"3\" (or null)."
  }
}

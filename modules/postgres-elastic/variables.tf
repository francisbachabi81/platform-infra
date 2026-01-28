variable "name" {
  type        = string
  description = "Elastic cluster name (serverGroupsv2)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the cluster."
}

variable "location" {
  type        = string
  description = "Azure region display name (e.g., Central US, USGov Arizona)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the cluster and (if created) private endpoint."
}

variable "api_version" {
  type        = string
  default     = null
  description = "AzAPI api-version for serverGroupsv2. If null, defaults to 2023-03-02-preview."
}

variable "network_mode" {
  type        = string
  default     = "private"
  description = "private|public. Private uses a Private Endpoint + Private DNS Zone Group."
  validation {
    condition     = contains(["private", "public"], var.network_mode)
    error_message = "network_mode must be 'private' or 'public'."
  }
}

# ----------------------------
# Admin / versions
# ----------------------------
variable "administrator_login" {
  type        = string
  default     = "pgadmin"
  description = "Admin username."
}

variable "administrator_login_password" {
  type        = string
  sensitive   = true
  description = "Admin password."
}

variable "pg_version" {
  type        = string
  default     = "15"
  description = "PostgreSQL version (string)."
}

variable "citus_version" {
  type        = string
  default     = null
  description = "Optional Citus version (string)."
}

# ----------------------------
# Sizing
# ----------------------------
variable "coordinator_server_edition" {
  type        = string
  default     = "GeneralPurpose"
  description = "Coordinator server edition."
}

variable "coordinator_vcores" {
  type        = number
  default     = 4
  description = "Coordinator vCores."
}

variable "coordinator_storage_mb" {
  type        = number
  default     = 131072
  description = "Coordinator storage in MB."
}

variable "worker_count" {
  type        = number
  default     = 2
  description = "Worker node count."
}

variable "worker_server_edition" {
  type        = string
  default     = "GeneralPurpose"
  description = "Worker server edition."
}

variable "worker_vcores" {
  type        = number
  default     = 4
  description = "Worker vCores."
}

variable "worker_storage_mb" {
  type        = number
  default     = 131072
  description = "Worker storage in MB."
}

variable "ha_enabled" {
  type        = bool
  default     = false
  description = "Enable HA if supported."
}

# Maintenance (optional)
variable "maintenance_day" {
  type        = number
  default     = null
  description = "0-6 depending on API expectation for day-of-week; set both day+hour or leave null."
}

variable "maintenance_hour" {
  type        = number
  default     = 2
  description = "0-23 maintenance hour."
}

# ----------------------------
# Private Endpoint inputs (private mode)
# ----------------------------
variable "private_endpoint_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for the private endpoint (required when network_mode=private)."
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "Private DNS zone ID for the private endpoint DNS zone group (required when network_mode=private)."
}

variable "private_endpoint_subresource_names" {
  type        = list(string)
  default     = ["coordinator"]
  description = "Private endpoint subresource names (groupIds). Keep configurable across clouds/regions."
}

variable "private_endpoint_name" {
  type        = string
  default     = null
  description = "Optional override for Private Endpoint name."
}

variable "private_service_connection_name" {
  type        = string
  default     = null
  description = "Optional override for PSC name."
}

variable "private_dns_zone_group_name" {
  type        = string
  default     = null
  description = "Optional override for Private DNS Zone Group name."
}

# ----------------------------
# Public firewall rules (public mode only)
# ----------------------------
variable "firewall_rules" {
  type = list(object({
    name     = string
    start_ip = string
    end_ip   = string
  }))
  default     = []
  description = "Firewall rules (only applied when network_mode=public)."
}
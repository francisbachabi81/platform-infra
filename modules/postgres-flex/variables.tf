variable "name" {
  description = "Server name."
  type        = string
}

variable "resource_group_name" {
  description = "Target resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "pg_version" {
  description = "PostgreSQL major version (e.g., 14, 15, 16)."
  type        = string
  default     = "16"
}

variable "administrator_login" {
  description = "Admin login name."
  type        = string
  default     = "pgadmin"
}

variable "administrator_login_password" {
  description = "Admin password (use secret store / TF_VAR_...)."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "SKU (e.g., B_Standard_B1ms, GP_Standard_D2s_v3, MO_Standard_E4ds_v4)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage in MB."
  type        = number
  default     = 32768
}

variable "zone" {
  description = "Primary AZ (e.g., 1, 2, 3)."
  type        = string
  default     = "1"
}

variable "ha_enabled" {
  description = "Enable zone-redundant HA."
  type        = bool
  default     = false
}

variable "ha_zone" {
  description = "Standby AZ when HA is enabled (must differ from zone)."
  type        = string
  default     = "2"
}

variable "ha_mode" {
  type        = string
  default     = null
  description = <<EOT
PostgreSQL Flexible Server HA mode:
- "ZoneRedundant" (default when null)
- "SameZone"

Note: In Azure Gov ("hrz" product) you should use "SameZone". In Azure Commercial ("pub"), use "ZoneRedundant".
EOT
}

variable "backup_retention_days" {
  description = "Backup retention in days."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups."
  type        = bool
  default     = false
}

variable "maintenance_day" {
  description = "Maintenance day (0=Sun .. 6=Sat)."
  type        = number
  default     = 0
}

variable "maintenance_hour" {
  description = "Maintenance start hour (0..23)."
  type        = number
  default     = 2
}

variable "network_mode" {
  description = "Access mode: private (VNet + Private DNS) or public (internet + optional firewall)."
  type        = string
  default     = "private"
  validation {
    condition     = contains(["private", "public"], var.network_mode)
    error_message = "network_mode must be 'private' or 'public'."
  }
}

variable "delegated_subnet_id" {
  description = "Delegated subnet ID (required when network_mode=private)."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for privatelink.postgres.database.azure.com (required when network_mode=private)."
  type        = string
  default     = null
}

variable "databases" {
  description = "Databases to create."
  type        = list(string)
  default     = ["appdb"]
}

variable "firewall_rules" {
  description = "Firewall rules when network_mode=public."
  type = list(object({
    name     = string
    start_ip = string
    end_ip   = string
  }))
  default = []
}

variable "aad_auth_enabled" {
  description = "Enable Entra ID authentication."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "replica_enabled" {
  description = "If true, creates this server as a read replica."
  type        = bool
  default     = false
}

variable "source_server_id" {
  description = "Source PostgreSQL Flexible Server ID when creating a replica."
  type        = string
  default     = null
}

variable "auto_replica_name" {
  description = "When true and replica_enabled, suffix the name automatically."
  type        = bool
  default     = true
}

variable "replica_name_suffix" {
  description = "Suffix used when auto_replica_name=true (applied to 'name')."
  type        = string
  default     = "-replica-01"
}

variable "enable_postgis" {
  description = "Enable PostGIS on the server and install it in each non-replica database."
  type        = bool
  default     = false
}

variable "aad_tenant_id" {
  description = "AAD tenant id used for the server's authentication block. Defaults to the current provider tenant."
  type        = string
  default     = null
}


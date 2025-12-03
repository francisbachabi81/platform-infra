variable "name" {
  type        = string
  description = "Cosmos DB account name."
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

variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Map of Private DNS zone names to IDs (expects key 'privatelink.documents.azure.com')."
  default     = {}
}

variable "pe_sql_name" {
  type        = string
  description = "Override name for the SQL private endpoint (null = auto)."
  default     = null
}

variable "psc_sql_name" {
  type        = string
  description = "Override name for the SQL private service connection (null = auto)."
  default     = null
}

variable "sql_zone_group_name" {
  type        = string
  description = "Override name for the SQL DNS zone group (null = auto)."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}

variable "total_throughput_limit" {
  description = "Optional account-level RU/s cap. Applies to the sum of manual and autoscale max RU/s across all DBs/containers. Omit or null for no cap."
  type        = number
  default     = null
}

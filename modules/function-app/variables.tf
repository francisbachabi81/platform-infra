variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "product" {
  type        = string
  description = "Cloud/product selector: 'hrz' (Azure Gov) or 'pub' (Azure public)"
}

variable "resource_group_name" {
  type = string
}

variable "service_plan_id" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "storage_account_access_key" {
  type      = string
  sensitive = true
}

variable "functions_extension_version" {
  type    = string
  default = "~4"
}

variable "always_on" {
  type    = bool
  default = true
}

variable "stack" {
  type = object({
    node_version            = optional(string)
    python_version          = optional(string)
    dotnet_version          = optional(string)
    java_version            = optional(string)
    powershell_core_version = optional(string)
  })
  default = {}
}

variable "website_run_from_package" {
  type    = string
  default = "1"
}

variable "functions_worker_process_count" {
  type    = number
  default = 1
}

variable "app_settings" {
  type    = map(string)
  default = {}
}

variable "vnet_integration_subnet_id" {
  type    = string
  default = null
}

variable "enable_private_endpoint" {
  type    = bool
  default = true
}

variable "enable_scm_private_endpoint" {
  type    = bool
  default = false
}

variable "pe_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_ids" {
  type    = map(string)
  default = {}
}

variable "pe_site_name" {
  type    = string
  default = null
}

variable "psc_site_name" {
  type    = string
  default = null
}

variable "site_zone_group_name" {
  type    = string
  default = null
}

variable "pe_scm_name" {
  type    = string
  default = null
}

variable "psc_scm_name" {
  type    = string
  default = null
}

variable "scm_zone_group_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "os_type" {
  type    = string
  default = "linux"
  validation {
    condition     = contains(["linux", "windows"], lower(var.os_type))
    error_message = "os_type must be 'linux' or 'windows'."
  }
}

variable "plan_sku_name" {
  type = string
}

variable "application_insights_connection_string" {
  type        = string
  default     = null
  sensitive = true
  description = "Application Insights connection string. If set, will be injected into app settings."
}
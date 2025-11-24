# plane / product / env
variable "plane" {
  description = "deployment plane: np/pr or nonprod/prod"
  type        = string
  validation {
    condition     = contains(["np","pr","nonprod","prod"], lower(var.plane))
    error_message = "plane must be one of: np, pr, nonprod, prod."
  }
}

variable "product" {
  description = "product code: hrz or pub"
  type        = string
  validation {
    condition     = contains(["hrz","pub"], lower(var.product))
    error_message = "product must be either 'hrz' or 'pub'."
  }
}

variable "region" {
  description = "short region code, e.g. usaz or cus"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2,8}$", var.region))
    error_message = "region should be a short lowercase code like 'cus' or 'usaz'."
  }
}

variable "location" {
  description = "azure location display name, e.g. 'usgov arizona' or 'central us'"
  type        = string
  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location cannot be empty."
  }
}

# provider identity
variable "subscription_id" {
  description = "target subscription id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a guid."
  }
}

variable "tenant_id" {
  description = "entra tenant id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a guid."
  }
}

# tags
variable "tags" {
  description = "base tags applied to all resources"
  type        = map(string)
  default     = {}
}

# observability
variable "law_sku" {
  description = "log analytics sku"
  type        = string
  default     = "PerGB2018"
  validation {
    condition = contains(["PerGB2018","CapacityReservation","PerNode","Free","Standalone"], var.law_sku)
    error_message = "law_sku must be one of: PerGB2018, CapacityReservation, PerNode, Free, Standalone."
  }
}

variable "law_retention_days" {
  description = "log analytics retention in days"
  type        = number
  default     = 30
  validation {
    condition     = var.law_retention_days >= 7 && var.law_retention_days <= 730
    error_message = "law_retention_days must be between 7 and 730."
  }
}

variable "appi_internet_ingestion_enabled" {
  description = "app insights ingestion over internet"
  type        = bool
  default     = true
}

variable "appi_internet_query_enabled" {
  description = "app insights queries over internet"
  type        = bool
  default     = true
}

# remote state (optional)
variable "shared_state_enabled" {
  description = "read remote state for cross-stack wiring"
  type        = bool
  default     = true
}

variable "state_rg_name" {
  description = "remote state resource group"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_rg_name, ""))) > 0 : true
    error_message = "state_rg_name is required when shared_state_enabled is true."
  }
}

variable "state_sa_name" {
  description = "remote state storage account"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_sa_name, ""))) > 0 : true
    error_message = "state_sa_name is required when shared_state_enabled is true."
  }
}

variable "state_container_name" {
  description = "remote state blob container"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_container_name, ""))) > 0 : true
    error_message = "state_container_name is required when shared_state_enabled is true."
  }
}

# create toggles
variable "create_rg_core_platform" {
  type    = bool
  default = true
}

variable "create_log_analytics" {
  type    = bool
  default = true
}

variable "create_application_insights" {
  type    = bool
  default = true
}

variable "create_recovery_vault" {
  type    = bool
  default = true
}

variable "create_action_group" {
  type    = bool
  default = true
}

variable "action_group_email_receivers" {
  type = list(object({
    name                    = string
    email_address           = string
    use_common_alert_schema = optional(bool, true)
  }))
  default = []
}

variable "enable_custom_domain" {
  description = "Whether to create a customer-managed email domain for ACS."
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom email domain (e.g. mail.example.com). Required if enable_custom_domain = true."
  type        = string
  default     = null
}

variable "associate_custom_domain" {
  description = "Whether to associate the custom domain with ACS (set true only after DNS is verified)."
  type        = bool
  default     = false
}

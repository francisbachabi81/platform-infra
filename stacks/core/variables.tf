# Core deployment identity & scope
variable "subscription_id" {
  description = "Target subscription id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a guid."
  }
}

variable "tenant_id" {
  description = "Entra tenant id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a guid."
  }
}

variable "product" {
  description = "Product code: hrz (US Gov) or pub (Commercial)"
  type        = string
  validation {
    condition     = contains(["hrz", "pub"], lower(var.product))
    error_message = "product must be either 'hrz' or 'pub'."
  }
}

variable "plane" {
  description = "Deployment plane: np/pr or nonprod/prod"
  type        = string
  validation {
    condition     = contains(["np", "pr", "nonprod", "prod"], lower(var.plane))
    error_message = "plane must be one of: np, pr, nonprod, prod."
  }
}

variable "region" {
  description = "Short region code, e.g. usaz or cus"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2,8}$", var.region))
    error_message = "region should be a short lowercase code like 'cus' or 'usaz'."
  }
}

variable "location" {
  description = "Azure location display name, e.g. 'USGov Arizona' or 'Central US'"
  type        = string
  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location cannot be empty."
  }
}

# Tags
variable "tags" {
  description = "Base tags applied to all resources"
  type        = map(string)
  default     = {}
}

# Observability (LAW + App Insights)
variable "law_sku" {
  description = "Log Analytics SKU"
  type        = string
  default     = "PerGB2018"
  validation {
    condition = contains(
      ["PerGB2018", "CapacityReservation", "PerNode", "Free", "Standalone"],
      var.law_sku
    )
    error_message = "law_sku must be one of: PerGB2018, CapacityReservation, PerNode, Free, Standalone."
  }
}

variable "law_daily_quota_gb" {
  description = "Daily ingestion quota for Log Analytics workspace in GB (e.g. 1 = 1 GB/day)."
  type        = number
  default     = 1
}

variable "law_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
  validation {
    condition     = var.law_retention_days >= 7 && var.law_retention_days <= 730
    error_message = "law_retention_days must be between 7 and 730."
  }
}

variable "appi_internet_ingestion_enabled" {
  description = "App Insights ingestion over internet"
  type        = bool
  default     = true
}

variable "appi_internet_query_enabled" {
  description = "App Insights queries over internet"
  type        = bool
  default     = true
}

# Remote state (shared-network)
variable "shared_state_enabled" {
  description = "Read remote state for cross-stack wiring"
  type        = bool
  default     = true
}

variable "state_rg_name" {
  description = "Remote state resource group"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_rg_name, ""))) > 0 : true
    error_message = "state_rg_name is required when shared_state_enabled is true."
  }
}

variable "state_sa_name" {
  description = "Remote state storage account"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_sa_name, ""))) > 0 : true
    error_message = "state_sa_name is required when shared_state_enabled is true."
  }
}

variable "state_container_name" {
  description = "Remote state blob container"
  type        = string
  default     = null
  validation {
    condition     = var.shared_state_enabled ? length(trimspace(coalesce(var.state_container_name, ""))) > 0 : true
    error_message = "state_container_name is required when shared_state_enabled is true."
  }
}

# Create toggles (core resources)
variable "create_rg_core_platform" {
  description = "Create the core resource group"
  type        = bool
  default     = true
}

variable "create_log_analytics" {
  description = "Create Log Analytics workspace"
  type        = bool
  default     = true
}

variable "create_application_insights" {
  description = "Create Application Insights linked to LAW"
  type        = bool
  default     = true
}

variable "create_recovery_vault" {
  description = "Create Recovery Services vault"
  type        = bool
  default     = true
}

variable "create_action_group" {
  description = "Create Monitor action group in core RG"
  type        = bool
  default     = true
}

# Monitor Action Group (email receivers)
variable "action_group_email_receivers" {
  description = "Email receivers for the core Monitor action group"
  type = list(object({
    name                    = string
    email_address           = string
    use_common_alert_schema = optional(bool, true)
  }))
  default = []
}

# Communication Services (ACS + email)
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

# Core VM (GitHub Actions runner / jumpbox)
variable "create_core_vm" {
  description = "Whether to create the core Linux VM (for GitHub Actions / jumpbox)."
  type        = bool
  default     = false
}

variable "core_vm_private_ip" {
  description = "Static private IP for the core VM in the hub internal subnet (e.g. 10.10.10.20)."
  type        = string
}

variable "core_vm_admin_username" {
  description = "Admin username for the core Linux VM."
  type        = string
  default     = "coreadmin"
}

variable "core_vm_admin_password" {
  description = "Admin password for the core Linux VM (should come from a secret)."
  type        = string
  sensitive   = true
}

variable "core_runner_vm_size" {
  description = "VM size for the core runner/jumpbox. Example: Standard_D2s_v5 for light CI or Standard_D4s_v5 for heavier workloads."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "core_runner_vm_image_publisher" {
  description = "Image publisher for the core runner VM. Default is Canonical for Ubuntu."
  type        = string
  default     = "Canonical"
}

variable "core_runner_vm_image_offer" {
  description = "Image offer for the core runner VM. Default is Ubuntu 22.04 Jammy offer."
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "core_runner_vm_image_sku" {
  description = "Image SKU for the core runner VM. Default is 22_04-lts-gen2 (Ubuntu 22.04 LTS Gen2)."
  type        = string
  default     = "22_04-lts-gen2"
}

variable "core_runner_vm_image_version" {
  description = "Image version for the core runner VM. Use 'latest' for automatic patching or pin to a specific version if needed."
  type        = string
  default     = "latest"
}

variable "create_query_pack" {
  type        = bool
  description = "Create a Log Analytics Query Pack in the core RG"
  default     = true
}

variable "query_pack_name" {
  type        = string
  description = "Optional override for query pack name"
  default     = null
}

variable "query_pack_queries" {
  description = "Optional map of saved queries to create in the query pack"
  type = map(object({
    display_name   = string
    body           = string
    description    = optional(string)
    categories     = optional(list(string), [])
    resource_types = optional(list(string), [])
    solutions      = optional(list(string), [])
    tags           = optional(map(string), {})
  }))
  default = {}
}

variable "create_core_uami" {
  description = "Create a core user-assigned managed identity (UAMI) for shared core access (e.g., Key Vault reads)."
  type        = bool
  default     = true
}

variable "create_core_key_vault" {
  description = "Create a Key Vault for core secrets/certs used by core and downstream stacks."
  type        = bool
  default     = true
}

variable "core_key_vault_soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault."
  type        = number
  default     = 90
  validation {
    condition     = var.core_key_vault_soft_delete_retention_days >= 7 && var.core_key_vault_soft_delete_retention_days <= 90
    error_message = "core_key_vault_soft_delete_retention_days must be between 7 and 90."
  }
}

variable "core_key_vault_purge_protection_enabled" {
  description = "Enable purge protection on the core Key Vault."
  type        = bool
  default     = true
}

variable "core_key_vault_grant_uami_secrets_user" {
  description = "Grant the core UAMI the 'Key Vault Secrets User' role on the core Key Vault."
  type        = bool
  default     = true
}

variable "core_kv_pe_subnet_id_override" {
  description = "Optional override for the hub privatelink subnet ID used for the core Key Vault private endpoint."
  type        = string
  default     = null
}

variable "core_kv_private_dns_zone_ids_override" {
  description = "Optional override map of private DNS zone IDs used for core Key Vault private endpoint DNS zone group."
  type        = map(string)
  default     = null
}

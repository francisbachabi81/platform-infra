variable "product" {
  type        = string
  description = "hrz (Azure Gov) or pub (Azure Commercial)"
}

variable "env" {
  type        = string
  default     = null
  description = "dev | qa | uat | prod (optional if plane provided)"
  validation {
    condition     = var.env == null || contains(["dev", "qa", "uat", "prod"], lower(var.env))
    error_message = "env must be one of: dev, qa, uat, prod."
  }
}

variable "plane" {
  type        = string
  default     = null
  description = "nonprod | prod (optional if env provided)"
  validation {
    condition     = var.plane == null || contains(["nonprod", "prod"], lower(var.plane))
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "location" {
  type    = string
  default = null
}

variable "subscription_id" {
  type    = string
  default = null
}

variable "tenant_id" {
  type    = string
  default = null
}

# Remote-state settings (for data sources)
variable "state_rg" {
  type    = string
  default = null
}

variable "state_sa" {
  type    = string
  default = null
}

variable "state_container" {
  type    = string
  default = null
}

# Diagnostics / naming
variable "diag_name" {
  type        = string
  default     = "obs-diag"
  description = "Diagnostic setting name to apply to resources."
}

# Optional overrides
variable "ag_name" {
  type        = string
  default     = null
  description = "Optional Action Group name override."
}

variable "law_workspace_id_override" {
  type        = string
  default     = null
  description = "If set, send all diagnostic settings to this LAW id."
}

# Alerting recipients
variable "alert_emails" {
  type        = list(string)
  default     = []
  description = "Email recipients for fallback Action Group (if core AG not found)."
}

# Feature flags
variable "enable_aks_diagnostics" {
  type        = bool
  default     = true
  description = "Enable AKS diagnostic settings when AKS ids are discovered."
}

# Structured receivers
variable "action_group_email_receivers" {
  type = list(object({
    name          = string
    email_address = string
  }))
  default     = []
  description = "Optional structured list of receivers; if set, overrides alert_emails."
}

# Extra tags
variable "tags_extra" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to supported resources (e.g., Action Group)."
}

# Provider scoping
variable "core_subscription_id" {
  type    = string
  default = null
}

variable "core_tenant_id" {
  type    = string
  default = null
}

variable "env_subscription_id" {
  type    = string
  default = null
}

variable "env_tenant_id" {
  type    = string
  default = null
}

# ENV RG override
variable "env_rg_name" {
  type        = string
  default     = null
  description = "ENV subscription resource group name (overrides remote-state value)."
}

variable "enable_cosmos_diagnostics" {
  type        = bool
  default     = true
  description = "Enable Cosmos DB diagnostic settings when account IDs are discovered or provided."
}

variable "cosmos_account_ids" {
  type        = list(string)
  default     = []
  description = "Explicit Cosmos DB account resource IDs to enable diagnostics on."
}

variable "cosmos_log_categories" {
  type = list(string)
  default = [
    "DataPlaneRequests",
    "DataPlaneRequests5M",
    "DataPlaneRequests15M",
    "MongoRequests",
    "QueryRuntimeStatistics",
    "PartitionKeyStatistics",
    "PartitionKeyRUConsumption",
    "ControlPlaneRequests",
    "CassandraRequests",
    "GremlinRequests",
    "TableApiRequests"
  ]
  description = "Cosmos DB diagnostic log categories to enable."
}

variable "enable_kv_diagnostics" {
  type        = bool
  default     = true
  description = "Enable Key Vault diagnostic settings when vault IDs are discovered or provided."
}

variable "key_vault_ids" {
  type        = list(string)
  default     = []
  description = "Explicit Key Vault resource IDs to enable diagnostics on."
}

variable "kv_log_categories" {
  type        = list(string)
  default     = ["AuditEvent","AzurePolicyEvaluationDetails"]
  description = "Key Vault diagnostic log categories to enable."
}

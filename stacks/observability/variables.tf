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

variable "region" {
  type    = string
  default = null
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

# Backend/state settings (you pass these via -backend-config for actual backend; here for remote_state data sources)
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

# Optional overrides carried in your tfvars
variable "ag_name" {
  type        = string
  default     = null
  description = "Optional Action Group name override."
}

variable "law_name" {
  type        = string
  default     = null
  description = "Optional Log Analytics workspace name (informational)."
}

# Optional LAW override if you want to pin a workspace id
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

# NEW: optional, structured receivers (if you prefer name+email objects)
variable "action_group_email_receivers" {
  type = list(object({
    name          = string
    email_address = string
  }))
  default     = []
  description = "Optional structured list of receivers; if set, overrides alert_emails."
}

# NEW: optional extra tags to stamp on resources that support tags
variable "tags_extra" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to supported resources (e.g., Action Group)."
}
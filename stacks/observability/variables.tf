variable "product" {
  description = "Product (hrz = Azure Gov, pub = Azure Commercial)"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.env)
    error_message = "env must be one of dev, qa, uat, prod."
  }
}

variable "subscription_id" {
  description = "Target subscription for this env. If null, pulled from platform-app meta output."
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Tenant for the target subscription. If null, pulled from platform-app meta output."
  type        = string
  default     = null
}

variable "state_rg" {
  description = "Terraform state RG name (shared)"
  type        = string
  default     = "rg-core-infra-state"
}

variable "state_sa" {
  description = "Terraform state storage account name (shared)"
  type        = string
  default     = "sacoretfstateinfra"
}

variable "state_container" {
  description = "Terraform state container"
  type        = string
  default     = "tfstate"
}

variable "diag_name" {
  description = "Name of each diagnostic setting resource"
  type        = string
  default     = "send-to-law"
}

variable "law_workspace_id_override" {
  description = "Override Log Analytics Workspace ID; if null the Core stack LAW will be used."
  type        = string
  default     = null
}

variable "alert_emails" {
  description = "Optional list of email receivers for activity log alerts (used only if Core stack action_group is absent)."
  type        = list(string)
  default     = []
}

variable "location" {
  description = "Azure location for workbook (use same as Core/Platform)"
  type        = string
  default     = "eastus"
}

variable "enable_aks_diagnostics" {
  description = "If true, attach diagnostic settings for AKS clusters discovered in the platform-app remote state."
  type        = bool
  default     = true
}
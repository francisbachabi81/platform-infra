
# core
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where the ACR will be created."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD / Entra ID tenant ID."
}

variable "region" {
  type        = string
  description = "Short region code used in naming (e.g., 'usaz', 'ustx')."
  default     = "usaz"
}

variable "location" {
  type        = string
  description = "Azure Gov region display name (e.g., 'USGov Arizona')."
  default     = "USGov Arizona"
}

variable "registry_name" {
  type        = string
  description = "ACR name (5-50 lowercase alphanumeric). Example: 'acrhrzprusaz01'."
  default     = "acrhrzprusaz01"
}

# acr settings
variable "acr_sku" {
  type        = string
  description = "ACR SKU: Basic | Standard | Premium."
  default     = "Standard"
}

variable "zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy (ZRS) for the ACR where supported."
  default     = true
}

variable "retention_untagged_days" {
  type        = number
  description = "Delete untagged manifests after N days."
  default     = 7
}

# rbac
variable "role_assignments" {
  description = <<EOT
List of role assignments to grant on the ACR.
Example:
[
  { principal_id = "00000000-0000-0000-0000-000000000000", role_definition_name = "AcrPull" },
  { principal_id = "11111111-1111-1111-1111-111111111111", role_definition_name = "AcrPush" }
]
EOT
  type = list(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = []
}

# tags
variable "tags" {
  description = "Additional tags to apply to all resources (merged with standard org/plane/runtime tags)."
  type        = map(string)
  default = {
    org                 = "intterra"
    product             = "intterra"
    plane               = "prod"
    region              = "usaz"
    cost_center         = "shared-global"
    data_classification = "internal"
    owner               = "platform-team"
    environment         = "prod"
  }
}
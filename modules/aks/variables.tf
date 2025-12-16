variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "node_resource_group" {
  type    = string
  default = ""
}

variable "default_nodepool_subnet_id" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.33.3"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "service_cidr" {
  type    = string
  default = "172.120.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "172.120.0.10"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "outbound_public_ip_id" {
  type        = string
  default     = null
  description = "ID of an existing Standard Public IP to use for AKS egress (names it yourself)."
}

variable "outbound_public_ip_prefix_ids" {
  type        = list(string)
  default     = []
  description = "Optional Public IP Prefix IDs to use for AKS egress."
}

variable "managed_outbound_ip_count" {
  type        = number
  default     = 1
  description = "Used only when no outbound IPs/prefixes are supplied."
}

variable "pod_cidr" {
  description = "Overlay Pod CIDR when using Azure CNI overlay (optional)."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "BYO Private DNS zone ID for privatelink.<region>.azmk8s.io (null = system-managed)."
}

variable "sku_tier" {
  description = "AKS control-plane tier: Free | Standard | Premium."
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "enable_aad" {
  type        = bool
  default     = true
  description = "Enable managed Azure AD integration for AKS."
}

variable "aad_admin_group_object_ids" {
  type        = list(string)
  default     = []
  description = "AAD group object IDs that will be cluster admins."
}

variable "enable_azure_rbac" {
  type        = bool
  default     = true
  description = "Use Azure RBAC (instead of Kubernetes RBAC bindings) for AKS."
}

variable "disable_local_accounts" {
  type        = bool
  default     = true
  description = "Disable local (non-AAD) kubeconfig accounts; only valid if AAD is enabled."
}

variable "identity_type" {
  description = "AKS identity type. Use UserAssigned when supplying a custom private_dns_zone_id."
  type        = string
  default     = "SystemAssigned" # or "UserAssigned"
}

variable "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned identity used by AKS (required when identity_type == UserAssigned)."
  type        = string
  default     = null
}

variable "temporary_name_for_rotation" {
  type        = string
  description = "Temporary node pool name used for default node pool rotation (1-12 lowercase alphanumeric, must start with a letter)."
  default     = "rotpool01"
}
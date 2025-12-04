variable "name" {
  type        = string
  description = "DNS Private Resolver name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "hub_vnet_id" {
  type        = string
  description = "Hub VNet ID hosting the resolver."
}

variable "inbound_subnet_id" {
  type        = string
  description = "Subnet ID for inbound endpoint (/27+ empty)."
}

variable "outbound_subnet_id" {
  type        = string
  description = "Subnet ID for outbound endpoint (/28+ empty)."
}

variable "forwarding_rules" {
  description = "Optional list of forwarding rules."
  type = list(object({
    domain_name = string        # typically ends with a dot, e.g., 'corp.contoso.com.'
    target_ips  = list(string)  # DNS servers to forward to
  }))
  default = []
}

variable "vnet_links" {
  type        = map(string)
  description = "Map of {name => VNet ID} to link to the ruleset."
  default     = {}
}

variable "inbound_static_ip" {
  type        = string
  description = "Optional static IP for inbound endpoint (must be within inbound subnet)."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}

variable "enable_outbound" {
  type        = bool
  description = "Whether to create an outbound endpoint and forwarding rules."
  default     = true
}
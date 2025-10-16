variable "name" {
  type        = string
  description = "Virtual Network name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "address_space" {
  type        = list(string)
  description = "Address space CIDR blocks."
  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR."
  }
}

variable "subnets" {
  description = "Map of subnet definitions keyed by subnet name."
  type = map(object({
    address_prefixes                     = optional(list(string))
    cidr                                 = optional(string)
    nsg_id                               = optional(string)
    route_table_id                       = optional(string)
    service_endpoints                    = optional(list(string))
    private_endpoint_network_policies    = optional(string) # Enabled|Disabled
    private_link_service_network_policies= optional(string) # Enabled|Disabled
    delegations = optional(list(object({
      name    = string
      service = string
      actions = optional(list(string))
    })))
  }))
  validation {
    condition = alltrue([
      for s in values(var.subnets) :
      (
        (can(s.address_prefixes) && s.address_prefixes != null && length(s.address_prefixes) > 0)
        ||
        (can(s.cidr) && s.cidr != null)
      )
    ])
    error_message = "Each subnet must set either address_prefixes (non-empty list) or cidr (string)."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}
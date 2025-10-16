variable "resource_group_name" {
  description = "Resource group for the Private DNS zones."
  type        = string
}

variable "zones" {
  description = "List of Private DNS zone names to create."
  type        = list(string)
}

variable "vnet_links" {
  description = "List of VNet links to create to the zones."
  type = list(object({
    name    = string  # link resource name
    zone    = string  # zone name (must exist in var.zones)
    vnet_id = string  # target VNet ID
  }))
  default = []

  validation {
    condition = length(var.vnet_links) == length(distinct([
      for l in var.vnet_links : "${l.name}|${l.zone}|${l.vnet_id}"
    ]))
    error_message = "Duplicate vnet_links entries detected (same name+zone+vnet_id)."
  }
}

variable "link_registration_enabled" {
  description = "Whether to enable auto-registration on all VNet links."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to zones and links."
  type        = map(string)
  default     = {}
}

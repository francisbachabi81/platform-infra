variable "left_rg" {
  type        = string
  description = "Resource group of LEFT VNet."
}

variable "left_vnet_name" {
  type        = string
  description = "LEFT VNet name."
}

variable "left_vnet_id" {
  type        = string
  description = "LEFT VNet ID."
}

variable "right_rg" {
  type        = string
  description = "Resource group of RIGHT VNet."
}

variable "right_vnet_name" {
  type        = string
  description = "RIGHT VNet name."
}

variable "right_vnet_id" {
  type        = string
  description = "RIGHT VNet ID."
}

variable "left_allow_gateway_transit" {
  type        = bool
  default     = false
  description = "Whether LEFT advertises its gateway to RIGHT."
}

variable "right_use_remote_gateways" {
  type        = bool
  default     = false
  description = "Whether RIGHT uses LEFT's advertised gateway."
}

variable "left_to_right_name" {
  type        = string
  default     = null
  description = "Optional custom name for LEFT→RIGHT peering."
}

variable "right_to_left_name" {
  type        = string
  default     = null
  description = "Optional custom name for RIGHT→LEFT peering."
}

variable "right_allow_gateway_transit" {
  type        = bool
  default     = false
  description = "Set true only if RIGHT advertises its gateway (rare)."
}

variable "left_use_remote_gateways" {
  type        = bool
  default     = false
  description = "Set true only if LEFT uses RIGHT's advertised gateway (rare)."
}

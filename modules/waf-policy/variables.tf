variable "name" {
  type        = string
  description = "WAF policy name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "mode" {
  type        = string
  default     = "Prevention"
  description = "WAF mode."
  validation {
    condition     = contains(["Prevention", "Detection"], var.mode)
    error_message = "mode must be either \"Prevention\" or \"Detection\"."
  }
}

variable "managed_rule_set_type" {
  type        = string
  default     = "OWASP"
  description = "Managed rule set type."
}

variable "managed_rule_set_version" {
  type        = string
  default     = "3.2"
  description = "Managed rule set version."
}

variable "exclusions" {
  description = "Optional managed rule exclusions."
  type = list(object({
    match_variable          = string   # e.g., RequestHeaderNames, RequestArgNames, RequestCookieNames
    selector_match_operator = string   # Equals | StartsWith | EndsWith | Contains | EqualsAny
    selector                = string
  }))
  default = []
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}
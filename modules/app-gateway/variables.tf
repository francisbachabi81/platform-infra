variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "public_ip_enabled" {
  type    = bool
  default = true
}

variable "sku_name" {
  type    = string
  default = "WAF_v2"
}

variable "sku_tier" {
  type    = string
  default = "WAF_v2"
}

variable "capacity" {
  type    = number
  default = 1
}

variable "waf_policy_id" {
  type    = string
  default = null
}

variable "cookie_based_affinity" {
  type    = string
  default = "Disabled"
  validation {
    condition     = contains(["Enabled", "Disabled"], var.cookie_based_affinity)
    error_message = "cookie_based_affinity must be Enabled or Disabled."
  }
}

variable "rule_priority" {
  type    = number
  default = 100
}

variable "public_ip_name" {
  type    = string
  default = null
}

variable "public_ip_id" {
  type    = string
  default = null
}

variable "private_ip_allocation" {
  type        = string
  default     = "Dynamic"
  description = "used when public_ip_enabled = false"
  validation {
    condition     = contains(["Dynamic", "Static"], var.private_ip_allocation)
    error_message = "private_ip_allocation must be Dynamic or Static."
  }
}

variable "private_ip_address" {
  type        = string
  default     = null
  description = "required when private_ip_allocation = Static"
}

variable "tags" {
  type    = map(string)
  default = {}
}
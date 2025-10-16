variable "namespace_name" {
  type = string
}

variable "eventhub_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "namespace_sku" {
  type    = string
  default = "Standard" # basic | standard | premium
}

variable "namespace_capacity" {
  type    = number
  default = 1 # premium only
}

variable "auto_inflate_enabled" {
  type    = bool
  default = false
}

variable "maximum_throughput_units" {
  type    = number
  default = 0 # used when auto_inflate_enabled = true
}

variable "partition_count" {
  type    = number
  default = 2
}

variable "message_retention_in_days" {
  type    = number
  default = 7
}

variable "min_tls_version" {
  type    = string
  default = "1.2"
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "enable_private_endpoint" {
  type    = bool
  default = false
}

variable "pe_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type        = string
  default     = null
  description = "private dns zone id for event hubs (privatelink.servicebus.windows.net)."
}

variable "pe_name" {
  type    = string
  default = null
}

variable "psc_name" {
  type    = string
  default = null
}

variable "pe_zone_group_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
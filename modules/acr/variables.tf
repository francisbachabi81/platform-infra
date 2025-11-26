variable "registry_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

variable "admin_enabled" {
  type    = bool
  default = false
}

variable "public_network_access" {
  type    = bool
  default = true
}

variable "anonymous_pull_enabled" {
  type    = bool
  default = false
}

variable "retention_untagged_enabled" {
  type    = bool
  default = true
}

variable "retention_untagged_days" {
  type    = number
  default = 7
}

variable "zone_redundancy_enabled" {
  type    = bool
  default = true
}

variable "role_assignments" {
  type = list(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "georeplication_locations" {
  description = <<EOT
List of Azure regions for ACR geo-replication (Premium only).
Examples (commercial): ["eastus2", "westus3"]
Examples (Azure Gov):  ["usgovvirginia"]
EOT
  type    = list(string)
  default = []
}

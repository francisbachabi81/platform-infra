variable "name" {
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
  default = "VpnGw1"
}

variable "gateway_subnet_id" {
  type = string
}

variable "create_public_ip" {
  type    = bool
  default = false
}

variable "public_ip_id" {
  type    = string
  default = null
}

variable "public_ip_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

# p2s
variable "p2s_enable" {
  type    = bool
  default = true
}

variable "p2s_address_space" {
  type    = list(string)
  default = ["192.168.1.0/24"]
}

variable "p2s_vpn_client_protocols" {
  type    = list(string)
  default = ["OpenVPN"]
}

variable "p2s_vpn_auth_types" {
  type    = list(string)
  default = ["AAD"]
  validation {
    condition     = alltrue([for t in var.p2s_vpn_auth_types : contains(["AAD", "Certificate", "Radius"], t)])
    error_message = "p2s_vpn_auth_types must contain only AAD, Certificate, and/or Radius."
  }
}

variable "tenant_id" {
  type    = string
  default = null
}

variable "p2s_aad_audience" {
  type    = string
  default = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
}

variable "p2s_aad_tenant_id_override" {
  type    = string
  default = null
}

variable "p2s_aad_issuer_uri_override" {
  type    = string
  default = null
}

variable "p2s_aad_tenant_uri_override" {
  type    = string
  default = null
}

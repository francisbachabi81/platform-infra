variable "product" { 
  type = string 
  } # hrz | pub

variable "env" {
  type        = string
  default     = null
  description = "(Optional) used only for tagging/labels. Do NOT use for state selection."
}

variable "tags" { 
  type = map(string) 
  default = {} 
}

variable "plane" {
  type        = string
  default     = null
  description = "nonprod | prod (optional if env provided)"
  validation {
    condition     = var.plane == null || contains(["nonprod", "prod"], lower(var.plane))
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "location" {
  type    = string
  default = null
}

variable "region" {
  description = "short region code, e.g. usaz or cus"
  type        = string
}

# Remote state wiring
variable "shared_network_state" {
  description = "Remote state config for stacks/shared-network."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
}

variable "core_state" {
  description = "(Optional) Remote state config for stack that outputs key_vault (id, vault_uri)."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
}

# Application Gateway runtime configuration
variable "frontend_ports" {
  description = "Map of frontend port name => port number."
  type        = map(number)
  default     = {
    feport-80  = 80
    feport-443 = 443
  }
}

variable "backend_pools" {
  description = "Map of backend pool name => backend targets. Use either ip_addresses or fqdns (or both)."
  type = map(object({
    ip_addresses = optional(list(string), [])
    fqdns        = optional(list(string), [])
  }))
  default = {}
}

variable "probes" {
  description = "Map of probe name => probe settings."
  type = map(object({
    protocol            = string # Http|Https
    host                = optional(string)
    path                = string
    interval            = optional(number, 30)
    timeout             = optional(number, 30)
    unhealthy_threshold = optional(number, 3)
    port                = optional(number)
    match_status_codes  = optional(list(string), ["200-399"])
  }))
  default = {}
}

variable "backend_http_settings" {
  description = "Map of backend HTTP settings name => settings."
  type = map(object({
    port                                = number
    protocol                            = string # Http|Https
    request_timeout                     = optional(number, 20)
    cookie_based_affinity               = optional(string, "Disabled")
    probe_name                          = optional(string)
    host_name                           = optional(string)
    pick_host_name_from_backend_address = optional(bool, false)
  }))
  default = {}
}

variable "listeners" {
  description = "Map of listener name => listener settings."
  type = map(object({
    frontend_port_name             = string
    protocol                       = string # Http|Https
    host_name                      = optional(string)
    ssl_certificate_name           = optional(string)
    require_sni                    = optional(bool, false)
    frontend_ip_configuration_name = optional(string, "feip")
  }))
  default = {}
}

variable "routing_rules" {
  description = "List of routing rules. Provide either backend_* OR redirect_configuration_name."
  type = list(object({
    name                        = string
    priority                    = number
    rule_type                   = optional(string, "Basic")
    http_listener_name          = string

    backend_address_pool_name   = optional(string)
    backend_http_settings_name  = optional(string)

    redirect_configuration_name = optional(string)
  }))
  default = []
}

variable "redirect_configurations" {
  description = "Map of redirect configuration name => redirect settings (commonly HTTP -> HTTPS)."
  type = map(object({
    target_listener_name   = string
    redirect_type          = optional(string, "Permanent") # Permanent|Found|SeeOther|Temporary
    include_path           = optional(bool, true)
    include_query_string   = optional(bool, true)
  }))
  default = {}
}

variable "ssl_certificates" {
  description = "Map of AGW sslCertificate name => Key Vault secret reference."
  type = map(object({
    key_vault_secret_id = optional(string)  # full https://.../secrets/.../version
    secret_name         = optional(string)  # if building from kv_uri
    secret_version      = optional(string)
  }))
  default = {}
}

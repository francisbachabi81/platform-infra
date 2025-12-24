variable "product" { type = string } # hrz | pub
variable "env"     { type = string } # dev | qa | prod

variable "tags" { 
  type = map(string) 
  default = {} 
}

variable "subscription_id" {
  description = "Target subscription id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a guid."
  }
}

variable "tenant_id" {
  description = "Entra tenant id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a guid."
  }
}

# -------------------------------------------------------------------
# Remote state wiring
# -------------------------------------------------------------------
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

# Optional: if shared-network does not provide Key Vault outputs yet,
# you can also point this stack at core/platform-app state to look up the KV.
variable "core_state" {
  description = "(Optional) Remote state config for stack that outputs key_vault (id, vault_uri)."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
  default = null
}

# -------------------------------------------------------------------
# SSL certificate sourcing (Key Vault)
# -------------------------------------------------------------------
# Preferred: provide the full secret ID (URI with version)
variable "ssl_key_vault_secret_id" {
  description = "Full Key Vault Secret ID/URI (with version) used by Application Gateway sslCertificates[].keyVaultSecretId."
  type        = string
  default     = null
}

# Alternative: provide name (+ optionally version) and we will build the secret ID using vault_uri.
variable "ssl_secret_name" {
  description = "Key Vault secret name containing the PFX for Application Gateway (e.g. 'wildcard-contoso-com')."
  type        = string
  default     = null
}

variable "ssl_secret_version" {
  description = "(Optional) Key Vault secret version. If null, the latest version is used (requires read access to secret metadata)."
  type        = string
  default     = null
}

# -------------------------------------------------------------------
# Application Gateway runtime configuration (owned by this stack)
# -------------------------------------------------------------------
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

variable "ssl_certificate_name" {
  description = "Name to assign to the Application Gateway sslCertificate object that references Key Vault. Listeners should reference this name when protocol=Https."
  type        = string
  default     = "kv-ssl"
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

variable "product" { type = string } # hrz|pub (matches your convention)
variable "plane" { type = string }   # nonprod|prod
variable "env" { type = string }     # dev|qa|uat|prod (optional but useful for naming patterns)
variable "region" { type = string }  # usaz|cus|...
variable "location" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

variable "shared_network_state" {
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
}

variable "core_state" {
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
}

# For WAF policy placement (often same hub/net RG)
variable "waf_resource_group_name" {
  type        = string
  description = "Resource group where the Front Door WAF policy should live."
}

# -------------------------
# AFD config objects
# -------------------------
variable "origin_groups" {
  type = map(object({
    additional_latency_in_ms    = optional(number)
    sample_size                 = optional(number)
    successful_samples_required = optional(number)
    probe = object({
      interval_in_seconds = optional(number)
      path                = optional(string)
      protocol            = optional(string) # Http|Https
      request_type        = optional(string) # GET|HEAD
    })
  }))
  default = {}
}

variable "origins" {
  type = map(object({
    origin_group_key = string
    host_name        = string

    enabled            = optional(bool, true)
    http_port          = optional(number, 80)
    https_port         = optional(number, 443)
    origin_host_header = optional(string)
    priority           = optional(number, 1)
    weight             = optional(number, 1000)

    certificate_name_check_enabled = optional(bool, true)
  }))
  default = {}
}

variable "rule_sets" {
  type    = map(object({}))
  default = {}
}

variable "rules" {
  type = map(object({
    rule_set_key      = string
    order             = number
    behavior_on_match = optional(string)

    match_https_only = optional(bool)

    url_redirect = optional(object({
      destination_hostname = string           # REQUIRED
      redirect_type        = optional(string) # Moved | Found | TemporaryRedirect
      destination_path     = optional(string)
      query_string         = optional(string)
      destination_fragment = optional(string)
    }))

    response_headers = optional(list(object({
      action = string # Append | Overwrite | Delete
      name   = string
      value  = optional(string)
    })))
  }))
  default = {}
}

variable "customer_certificates" {
  description = "Customer certs stored in Key Vault for Front Door custom domains."
  type = map(object({
    key_vault_certificate_id = string
  }))
  default = {}
}

variable "custom_domains" {
  type = map(object({
    host_name                = string
    certificate_type         = string # ManagedCertificate|CustomerCertificate
    customer_certificate_key = optional(string)
    minimum_tls_version      = optional(string)
  }))
  default = {}
}

variable "routes" {
  type = map(object({
    origin_group_key = string
    origin_keys      = list(string)

    enabled                = optional(bool)
    forwarding_protocol    = optional(string) # HttpOnly|HttpsOnly|MatchRequest
    https_redirect_enabled = optional(bool)

    patterns_to_match   = optional(list(string))
    supported_protocols = optional(list(string))

    custom_domain_keys = optional(list(string))
    rule_set_keys      = optional(list(string))
  }))
  default = {}
}

variable "waf_policy" {
  type = object({
    sku_name = string # Standard_AzureFrontDoor|Premium_AzureFrontDoor
    mode     = string # Detection|Prevention

    managed_rule = object({
      type    = string
      version = string
    })

    custom_rules = optional(list(object({
      name               = string
      priority           = number
      action             = string # Allow|Block|Log
      match_variable     = string
      operator           = string
      match_values       = list(string)
      negation_condition = optional(bool)
      transforms         = optional(list(string))
    })), [])

    associated_custom_domain_keys = list(string)
    patterns_to_match             = optional(list(string))
  })
  default = null
}
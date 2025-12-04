# context
variable "plane" {
  description = "deployment plane: nonprod or prod"
  type        = string
  validation {
    condition     = contains(["nonprod","prod"], lower(var.plane))
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "product" {
  description = "product code: hrz or pub"
  type        = string
  default     = "hrz"
  validation {
    condition     = contains(["hrz","pub"], lower(var.product))
    error_message = "product must be hrz or pub."
  }
}

variable "location" {
  description = "azure location (e.g. westus3, usgovvirginia)"
  type        = string
  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location cannot be empty."
  }
}

variable "region" {
  description = "short region code used in naming (e.g. cus, usaz)"
  type        = string
  default     = "cus"
  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.region))
    error_message = "region should be 2-12 lowercase letters/digits."
  }
}

variable "seq" {
  description = "sequence used in names (e.g. 01)"
  type        = string
  default     = "01"
  validation {
    condition     = can(regex("^[0-9]{2}$", var.seq))
    error_message = "seq must be two digits like 01."
  }
}

variable "tags" {
  description = "base tags merged onto resources"
  type        = map(string)
  default     = {}
}

# subscriptions
variable "hub_subscription_id" {
  description = "hub subscription id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.hub_subscription_id))
    error_message = "hub_subscription_id must be a guid."
  }
}

variable "hub_tenant_id" {
  description = "hub tenant id"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.hub_tenant_id))
    error_message = "hub_tenant_id must be a guid."
  }
}

variable "dev_subscription_id" {
  description = "optional dev subscription override"
  type        = string
  default     = null
}

variable "dev_tenant_id" {
  description = "optional dev tenant override"
  type        = string
  default     = null
}

variable "qa_subscription_id" {
  description = "optional qa subscription override"
  type        = string
  default     = null
}

variable "qa_tenant_id" {
  description = "optional qa tenant override"
  type        = string
  default     = null
}

variable "prod_subscription_id" {
  description = "optional prod subscription override"
  type        = string
  default     = null
}

variable "prod_tenant_id" {
  description = "optional prod tenant override"
  type        = string
  default     = null
}

variable "uat_subscription_id" {
  description = "optional uat subscription override"
  type        = string
  default     = null
}

variable "uat_tenant_id" {
  description = "optional uat tenant override"
  type        = string
  default     = null
}

# hub & spokes (vnets)
variable "nonprod_hub" {
  description = "nonprod hub vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

variable "dev_spoke" {
  description = "dev spoke vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

variable "qa_spoke" {
  description = "qa spoke vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

variable "prod_hub" {
  description = "prod hub vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

variable "prod_spoke" {
  description = "prod spoke vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

variable "uat_spoke" {
  description = "uat spoke vnet definition"
  type = object({
    rg    = optional(string)
    vnet  = optional(string)
    cidrs = list(string)
    subnets = map(object({
      address_prefixes                      = optional(list(string))
      cidr                                  = optional(string)
      nsg_id                                = optional(string)
      route_table_id                        = optional(string)
      service_endpoints                     = optional(list(string))
      private_endpoint_network_policies     = optional(string)
      private_link_service_network_policies = optional(string)
      delegations = optional(list(object({
        name    = string
        service = string
        actions = optional(list(string))
      })))
    }))
  })
  default  = null
  nullable = true
}

# dns
variable "private_zones" {
  description = "private dns zone fqdns to create and link"
  type        = list(string)
}

variable "public_dns_zones" {
  description = "public dns zones to create in the shared rg"
  type        = list(string)
  default     = ["dev.horizon.intterra.io"]
}

# connectivity & ingress
variable "create_vpn_gateway" {
  description = "create p2s vpn gateway in the hub"
  type        = bool
  default     = true
}

variable "vpn_sku" {
  description = "vpn gateway sku"
  type        = string
  default     = "VpnGw1"
}

variable "public_ip_sku" {
  description = "public ip sku for gateways/app gateway"
  type        = string
  default     = "Standard"
}

variable "public_ip_allocation_method" {
  description = "public ip allocation method"
  type        = string
  default     = "Static"
}

variable "create_vpng_public_ip" {
  description = "if true, vpn module creates its own pip; otherwise pass an external pip"
  type        = bool
  default     = false
}

variable "create_app_gateway" {
  description = "create application gateway and waf policy"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "waf policy mode: detection or prevention"
  type        = string
  default     = "Detection"
  validation {
    condition     = contains(["Detection","Prevention"], var.waf_mode)
    error_message = "waf_mode must be Detection or Prevention."
  }
}

variable "appgw_public_ip_enabled" {
  description = "enable public ip for application gateway"
  type        = bool
  default     = true
}

variable "appgw_sku_name" {
  description = "application gateway sku name"
  type        = string
  default     = "WAF_v2"
}

variable "appgw_sku_tier" {
  description = "application gateway sku tier"
  type        = string
  default     = "WAF_v2"
}

variable "appgw_capacity" {
  description = "application gateway capacity"
  type        = number
  default     = 1
}

variable "appgw_cookie_based_affinity" {
  description = "cookie-based affinity: enabled or disabled"
  type        = string
  default     = "Disabled"
  validation {
    condition     = contains(["Enabled","Disabled"], var.appgw_cookie_based_affinity)
    error_message = "appgw_cookie_based_affinity must be Enabled or Disabled."
  }
}

# nsgs & dns resolver
variable "nsg_exclude_subnets" {
  description = "subnets where generic nsgs should not be attached"
  type        = list(string)
  default = [
    "GatewaySubnet",
    "AzureFirewallSubnet",
    "AzureFirewallManagementSubnet",
    "RouteServerSubnet",
    "AzureBastionSubnet",
    "appgw"
  ]
}

variable "create_dns_resolver" {
  description = "create azure dns private resolver in the hub"
  type        = bool
  default     = true
}

variable "dns_forwarding_rules" {
  description = "forwarding rules for dns private resolver"
  type = list(object({
    domain_name = string
    target_ips  = list(string)
  }))
  default = []
}

variable "dnsr_inbound_static_ip" {
  description = "optional static ip for dns private resolver inbound endpoint"
  type        = string
  default     = null
}

variable "fd_create_frontdoor" {
  description = "create azure front door profile"
  type        = bool
  default     = false
}

variable "fd_sku_name" {
  description = "front door sku name"
  type        = string
  default     = "Premium_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor","Premium_AzureFrontDoor"], var.fd_sku_name)
    error_message = "fd_sku_name must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "dnsresolver_enable_outbound" {
  type        = bool
  description = "Whether to create an outbound endpoint and forwarding rules."
  default     = true
}

variable "baseline_allowed_service_tags" {
  type = list(string)
  default = [
    "Storage",
    "AzureMonitor",
    "AzureContainerRegistry",
    # add when needed:
    # "AzureKeyVault",
    # "AzureActiveDirectory",
  ]
}

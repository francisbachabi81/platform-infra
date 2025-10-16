# context
variable "plane" {
  description = "Which lane to deploy: nonprod | prod"
  type        = string
  validation {
    condition     = contains(["nonprod", "prod"], var.plane)
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant (Entra ID) ID."
  type        = string
}

variable "location" {
  description = "Azure region display/name (e.g., Central US)."
  type        = string
}

variable "tags" {
  description = "Base tags to merge onto resources (layer- and plane-specific tags are added automatically)."
  type        = map(string)
  default     = {}
}

variable "product" {
  description = "Product/system code used in resource naming."
  type        = string
  default     = "hrz"
}

variable "region" {
  description = "Short region code used in naming (e.g., cus)."
  type        = string
  default     = "cus"
}

variable "seq" {
  description = "Sequence string used in names (e.g., 01)."
  type        = string
  default     = "01"
}

# hub & spokes
variable "nonprod_hub" {
  description = "Nonprod hub VNet definition."
  type = object({
    rg    = string
    vnet  = string
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
  description = "Dev spoke VNet."
  type = object({
    rg    = string
    vnet  = string
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
  description = "QA spoke VNet."
  type = object({
    rg    = string
    vnet  = string
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
  description = "Prod hub VNet."
  type = object({
    rg    = string
    vnet  = string
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
  description = "Prod spoke VNet."
  type = object({
    rg    = string
    vnet  = string
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
  description = "UAT spoke VNet."
  type = object({
    rg    = string
    vnet  = string
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
variable "shared_network_rg" {
  description = "Resource group for private and public DNS zones."
  type        = string
}

variable "private_zones" {
  description = "List of Private DNS zones to create + link."
  type        = list(string)
}

variable "public_dns_zones" {
  description = "Public DNS zones."
  type        = list(string)
  default     = ["dev.horizon.intterra.io"]
}

# connectivity & ingress
variable "create_vpn_gateway" {
  description = "Create P2S VPN gateway in the hub?"
  type        = bool
  default     = true
}

variable "vpn_sku" {
  description = "VPN Gateway SKU."
  type        = string
  default     = "VpnGw1"
}

variable "public_ip_sku" {
  description = "Public IP SKU for gateways / app gateway."
  type        = string
  default     = "Standard"
}

variable "public_ip_allocation_method" {
  description = "Public IP allocation method."
  type        = string
  default     = "Static"
}

variable "waf_mode" {
  description = "WAF policy mode (Detection | Prevention)."
  type        = string
  default     = "Detection"
}

variable "appgw_public_ip_enabled" {
  description = "Toggle public IP for Application Gateway."
  type        = bool
  default     = true
}

variable "appgw_sku_name" {
  description = "Application Gateway SKU name."
  type        = string
  default     = "WAF_v2"
}

variable "appgw_sku_tier" {
  description = "Application Gateway SKU tier."
  type        = string
  default     = "WAF_v2"
}

variable "appgw_capacity" {
  description = "Application Gateway capacity (instance count)."
  type        = number
  default     = 1
}

variable "appgw_cookie_based_affinity" {
  description = "Cookie based affinity (Enabled | Disabled)."
  type        = string
  default     = "Disabled"
}

# nsg stuff + dns resolver
variable "nsg_exclude_subnets" {
  description = "Subnet names where generic NSGs should NOT be attached."
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
  description = "Create Azure DNS Private Resolver in the hub VNet."
  type        = bool
  default     = true
}

variable "dns_forwarding_rules" {
  description = "Forwarding rules for DNS Private Resolver."
  type = list(object({
    domain_name = string
    target_ips  = list(string)
  }))
  default = []
}

variable "dnsr_inbound_static_ip" {
  description = "optional static ip for the dns private resolver inbound endpoint"
  type        = string
  default     = null
}

variable "create_app_gateway" {
  description = "create application gateway (and waf policy)?"
  type        = bool
  default     = true
}

variable "create_vpng_public_ip" {
  description = "Create a managed vpng Public IP when public_ip_id is not supplied."
  type        = bool
  default     = false
}
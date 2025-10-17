
# Context
variable "plane" {
  description = "Deployment plane: nonprod | prod"
  type        = string
  validation {
    condition     = contains(["nonprod", "prod"], var.plane)
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "product" {
  description = "Product/system code used in naming (hrz | pub)."
  type        = string
  default     = "hrz"
  validation {
    condition     = contains(["hrz", "pub"], var.product)
    error_message = "product must be one of: hrz, pub."
  }
}

variable "location" {
  description = "Azure region name (e.g., westus3, usgovvirginia)."
  type        = string
}

variable "region" {
  description = "Short region code used in naming (e.g., cus, usaz)."
  type        = string
  default     = "cus"
}

variable "seq" {
  description = "Sequence string used in names (e.g., 01)."
  type        = string
  default     = "01"
}

variable "tags" {
  description = "Base tags to merge onto resources (layer- and plane-specific tags are added automatically)."
  type        = map(string)
  default     = {}
}

# Subscriptions
variable "hub_subscription_id" {
  description = "Subscription ID for the HUB (shared-network) resources."
  type        = string
}

variable "hub_tenant_id" {
  description = "Tenant (Entra ID) ID for the HUB subscription."
  type        = string
}

variable "dev_subscription_id" {
  description = "Optional override subscription ID for DEV spoke resources."
  type        = string
  default     = null
}

variable "dev_tenant_id" {
  description = "Optional override tenant ID for DEV spoke resources."
  type        = string
  default     = null
}

variable "qa_subscription_id" {
  description = "Optional override subscription ID for QA spoke resources."
  type        = string
  default     = null
}

variable "qa_tenant_id" {
  description = "Optional override tenant ID for QA spoke resources."
  type        = string
  default     = null
}

variable "prod_subscription_id" {
  description = "Optional override subscription ID for PROD spoke resources."
  type        = string
  default     = null
}

variable "prod_tenant_id" {
  description = "Optional override tenant ID for PROD spoke resources."
  type        = string
  default     = null
}

variable "uat_subscription_id" {
  description = "Optional override subscription ID for UAT spoke resources."
  type        = string
  default     = null
}

variable "uat_tenant_id" {
  description = "Optional override tenant ID for UAT spoke resources."
  type        = string
  default     = null
}

# Hub & Spokes (VNets)
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
  description = "DEV spoke VNet definition."
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
  description = "QA spoke VNet definition."
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
  description = "Prod hub VNet definition."
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
  description = "PROD spoke VNet definition."
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
  description = "UAT spoke VNet definition."
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

# DNS
variable "shared_network_rg" {
  description = "Resource group for Private DNS zones (and optionally Public DNS zones)."
  type        = string
}

variable "private_zones" {
  description = "Private DNS zone FQDNs to create and link (e.g., privatelink.blob.core.usgovcloudapi.net)."
  type        = list(string)
}

variable "public_dns_zones" {
  description = "Public DNS zones to create in the shared network RG."
  type        = list(string)
  default     = ["dev.horizon.intterra.io"]
}


# Connectivity & Ingress

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
  description = "Public IP SKU for gateways / Application Gateway."
  type        = string
  default     = "Standard"
}

variable "public_ip_allocation_method" {
  description = "Public IP allocation method."
  type        = string
  default     = "Static"
}

variable "create_vpng_public_ip" {
  description = "If true, let the VPN Gateway module create its own Public IP; otherwise pass an external PIP."
  type        = bool
  default     = false
}

variable "create_app_gateway" {
  description = "Create Application Gateway (and WAF policy)."
  type        = bool
  default     = true
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
  description = "Cookie based affinity for Application Gateway (Enabled | Disabled)."
  type        = string
  default     = "Disabled"
}

# NSGs & DNS Resolver
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
  description = "Optional static IP for the DNS Private Resolver inbound endpoint."
  type        = string
  default     = null
}

variable "fd_create_frontdoor" {
  type    = bool
  default = false
}

variable "fd_sku_name" {
  type    = string
  default = "Premium_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.fd_sku_name)
    error_message = "fd_sku_name invalid"
  }
}
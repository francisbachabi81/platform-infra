# Core / plane
plane    = "prod"                # nonprod | prod
product  = "pub"                    # hrz | pub
location = "centralus"              # canonical azurerm region name
region   = "cus"                    # short code used in names
seq      = "01"                     # sequence in names

# Private DNS zones (Azure Commercial)
private_zones = [
  # App domains (dev + qa)
  # "public.intterra.io",
  # "uat.public.intterra.io",

  # Storage
  "privatelink.blob.core.windows.net",
  "privatelink.file.core.windows.net",
  "privatelink.queue.core.windows.net",
  "privatelink.table.core.windows.net",
  "privatelink.dfs.core.windows.net",   # Data Lake Gen2
  "privatelink.web.core.windows.net",   # Static website

  # Key Vault
  "privatelink.vaultcore.azure.net",

  # Redis
  "privatelink.redis.cache.windows.net",

  # Cosmos DB (NoSQL)
  "privatelink.documents.azure.com",

  # Azure Database for PostgreSQL (Flexible)
  "privatelink.postgres.database.azure.com",

  # Cosmos DB for PostgreSQL (Citus)
  "privatelink.postgres.cosmos.azure.com",

  # Service Bus / Event Hubs
  "privatelink.servicebus.windows.net",

  # App Service (Web Apps + SCM/Kudu)
  "privatelink.azurewebsites.net",
  "privatelink.scm.azurewebsites.net",

  # AKS (region-specific)
  "privatelink.centralus.azmk8s.io"
]

# Public DNS zones
public_dns_zones = [
  "public.intterra.io",
  "uat.public.intterra.io"
]

# vnets
prod_hub = {
  cidrs = ["172.13.0.0/16"]

  subnets = {
    GatewaySubnet                 = { address_prefixes = ["172.13.0.0/24"] }   # vpn gateway
    AzureFirewallSubnet           = { address_prefixes = ["172.13.1.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["172.13.1.64/26"] }
    RouteServerSubnet             = { address_prefixes = ["172.13.1.128/27"] }
    AzureBastionSubnet            = { address_prefixes = ["172.13.3.0/26"] }
    akspub                        = { address_prefixes = ["172.13.2.0/24"] }
    internal                      = { address_prefixes = ["172.13.13.0/24"] }
    external                      = { address_prefixes = ["172.13.14.0/24"] }
    "shared-svc"                  = { address_prefixes = ["172.13.20.0/24"] }
    appgw                         = { address_prefixes = ["172.13.40.0/27"] }  # app gateway

    "dns-inbound" = {
      address_prefixes = ["172.13.50.0/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "dns-outbound" = {
      address_prefixes = ["172.13.50.32/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    identity = { address_prefixes = ["172.13.60.0/26"] }
    monitor  = { address_prefixes = ["172.13.61.0/26"] }

    "privatelink-hub" = {
      address_prefixes                  = ["172.13.30.0/27"]
      private_endpoint_network_policies = "Disabled"        # required for private endpoints
    }
  }
}

prod_spoke = {
  # rg    = "rg-pub-prod-cus-01"
  # vnet  = "vnet-pub-prod-cus-01"
  cidrs = ["172.14.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["172.14.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["172.14.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["172.14.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["172.14.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["172.14.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["172.14.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["172.14.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["172.14.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["172.14.13.0/24"] }
    external = { address_prefixes = ["172.14.14.0/24"] }
    akspub   = { address_prefixes = ["172.14.2.0/24"] }

    pgflex = {
      address_prefixes = ["172.14.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["172.14.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["172.14.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

uat_spoke = {
  cidrs = ["172.15.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["172.15.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["172.15.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["172.15.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["172.15.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["172.15.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["172.15.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["172.15.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["172.15.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["172.15.13.0/24"] }
    external = { address_prefixes = ["172.15.14.0/24"] }
    akspub   = { address_prefixes = ["172.15.2.0/24"] }

    pgflex = {
      address_prefixes = ["172.15.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["172.15.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["172.15.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

# connectivity & ingress
create_vpn_gateway          = true      # create vpng
vpn_sku                     = "VpnGw1"  # e.g. VpnGw1, VpnGw2, VpnGw3
public_ip_sku               = "Standard"
public_ip_allocation_method = "Static"

# If true → VPN module creates its own PIP; if false → this stack creates an external PIP
create_vpng_public_ip       = false

# App Gateway (disabled in this nonprod example)
create_app_gateway          = true
waf_mode                    = "Detection"   # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"
appgw_private_frontend_ip = "172.13.40.4"

# DNS Private Resolver – optional static inbound IP & forwarding rules
dnsr_inbound_static_ip = "172.13.50.4"
dns_forwarding_rules   = [
  # example:
  # {
  #   domain_name = "corp.contoso.com."
  #   target_ips  = ["10.100.0.10", "10.100.0.11"]
  # }
]

# Tags
tags = {
  product = "pub"
  owner   = "it operations"
  lane    = "nonprod"
}

# Front Door
fd_create_frontdoor = true
fd_sku_name         = "Standard_AzureFrontDoor"

dnsresolver_enable_outbound = false
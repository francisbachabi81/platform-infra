# Core / plane
plane    = "prod"                 # nonprod | prod
product  = "hrz"                  # hrz | pub
location = "usgovarizona"         # canonical region name for azurerm provider
region   = "usaz"                 # short code used in names
seq      = "01"                   # sequence in names

# Private DNS zones (Azure Government)
private_zones = [
  # App domains (prod + uat)
  "horizon.intterra.io",
  "uat.horizon.intterra.io",
  "internal.horizon.intterra.io",
  "internal.uat.horizon.intterra.io",

  # Storage
  "privatelink.blob.core.usgovcloudapi.net",
  "privatelink.file.core.usgovcloudapi.net",
  "privatelink.queue.core.usgovcloudapi.net",
  "privatelink.table.core.usgovcloudapi.net",
  "privatelink.dfs.core.usgovcloudapi.net", # Data Lake Gen2
  "privatelink.web.core.usgovcloudapi.net", # Static website

  # Key Vault
  "privatelink.vaultcore.usgovcloudapi.net",

  # Redis
  "privatelink.redis.cache.usgovcloudapi.net",

  # Cosmos DB (NoSQL)
  "privatelink.documents.azure.us",

  # Azure Database for PostgreSQL (Flexible)
  "privatelink.postgres.database.usgovcloudapi.net",

  # Cosmos DB for PostgreSQL (Citus)
  "privatelink.postgres.cosmos.azure.us",

  # Service Bus / Event Hubs
  "privatelink.servicebus.usgovcloudapi.net",

  # App Service (Web Apps + SCM/Kudu)
  "privatelink.azurewebsites.us",
  "privatelink.scm.azurewebsites.us",

  # AKS (region-specific)
  "privatelink.usgovvirginia.cx.aks.containerservice.azure.us",
  "privatelink.usgovarizona.cx.aks.containerservice.azure.us"
]

# Public DNS zones
public_dns_zones = [
  "horizon.intterra.io",
  "uat.horizon.intterra.io"
]

# VNets — PROD plane: hub + prod + uat
prod_hub = {
  cidrs = ["10.13.0.0/16"]

  subnets = {
    GatewaySubnet                 = { address_prefixes = ["10.13.0.0/24"] }
    AzureFirewallSubnet           = { address_prefixes = ["10.13.1.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["10.13.1.64/26"] }
    RouteServerSubnet             = { address_prefixes = ["10.13.1.128/27"] }
    AzureBastionSubnet            = { address_prefixes = ["10.13.3.0/26"] }
    akshrz                        = { address_prefixes = ["10.13.2.0/24"] }
    internal                      = { address_prefixes = ["10.13.13.0/24"] }
    external                      = { address_prefixes = ["10.13.14.0/24"] }
    "shared-svc"                  = { address_prefixes = ["10.13.20.0/24"] }
    appgw                         = { address_prefixes = ["10.13.40.0/27"] }

    "dns-inbound" = {
      address_prefixes = ["10.13.50.0/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "dns-outbound" = {
      address_prefixes = ["10.13.50.32/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    identity = { address_prefixes = ["10.13.60.0/26"] }
    monitor  = { address_prefixes = ["10.13.61.0/26"] }

    "privatelink-hub" = {
      address_prefixes                  = ["10.13.30.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

prod_spoke = {
  cidrs = ["10.14.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["10.14.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["10.14.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["10.14.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["10.14.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "appsvc-int-windows-01" = {
      address_prefixes = ["10.14.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["10.14.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["10.14.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["10.14.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["10.14.13.0/24"] }
    external = { address_prefixes = ["10.14.14.0/24"] }
    akshrz   = { address_prefixes = ["10.14.2.0/24"] }

    pgflex = {
      address_prefixes = ["10.14.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["10.14.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["10.14.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-pg" = {
      address_prefixes                  = ["10.14.32.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

uat_spoke = {
  cidrs = ["10.15.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["10.15.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["10.15.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["10.15.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["10.15.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "appsvc-int-windows-01" = {
      address_prefixes = ["10.15.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["10.15.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["10.15.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["10.15.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["10.15.13.0/24"] }
    external = { address_prefixes = ["10.15.14.0/24"] }
    akshrz   = { address_prefixes = ["10.15.2.0/24"] }

    pgflex = {
      address_prefixes = ["10.15.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["10.15.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["10.15.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-pg" = {
      address_prefixes                  = ["10.15.32.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

# Connectivity & Ingress
create_vpn_gateway          = true
vpn_sku                     = "VpnGw1"
public_ip_sku               = "Standard"
public_ip_allocation_method = "Static"

# If true → VPN module creates its own PIP; if false → this stack creates an external PIP
create_vpng_public_ip = false

# App Gateway (prod tier)
create_app_gateway          = true
waf_mode                    = "Detection"   # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"
appgw_private_frontend_ip   = "10.13.40.4"

# DNS Private Resolver – optional static inbound IP & forwarding rules
dnsr_inbound_static_ip = "10.13.50.4"
dns_forwarding_rules   = [
  # example:
  # {
  #   domain_name = "corp.contoso.com."
  #   target_ips  = ["10.100.0.10", "10.100.0.11"]
  # }
]

# Tags
tags = {
  product = "hrz"
  owner   = "itops-team"
  lane    = "prod"
}

# Front Door
fd_create_frontdoor = true
fd_sku_name         = "Standard_AzureFrontDoor"

dnsresolver_enable_outbound = false
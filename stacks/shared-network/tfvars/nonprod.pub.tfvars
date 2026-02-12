# Core / plane
plane    = "nonprod"   # nonprod | prod
product  = "pub"       # hrz | pub
location = "centralus" # canonical azurerm region name
region   = "cus"       # short code used in names
seq      = "01"        # sequence in names

# Private DNS zones (Azure Commercial)
private_zones = [
  # App domains (dev + qa)
  "dev.public.intterra.io",
  "qa.public.intterra.io",

  # Storage
  "privatelink.blob.core.windows.net",
  "privatelink.file.core.windows.net",
  "privatelink.queue.core.windows.net",
  "privatelink.table.core.windows.net",
  "privatelink.dfs.core.windows.net", # Data Lake Gen2
  "privatelink.web.core.windows.net", # Static website

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
  "dev.public.intterra.io",
  "qa.public.intterra.io"
]

# VNets — NONPROD plane: hub + dev + qa
nonprod_hub = {
  cidrs = ["172.10.0.0/16"]

  subnets = {
    GatewaySubnet                 = { address_prefixes = ["172.10.0.0/24"] }
    AzureFirewallSubnet           = { address_prefixes = ["172.10.1.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["172.10.1.64/26"] }
    RouteServerSubnet             = { address_prefixes = ["172.10.1.128/27"] }
    AzureBastionSubnet            = { address_prefixes = ["172.10.3.0/26"] }
    akspub                        = { address_prefixes = ["172.10.2.0/24"] }
    internal                      = { address_prefixes = ["172.10.13.0/24"] }
    external                      = { address_prefixes = ["172.10.14.0/24"] }
    # "shared-svc"                  = { address_prefixes = ["172.10.20.0/24"] }
    appgw = { address_prefixes = ["172.10.40.0/27"] }

    "appgw-pl" = {
      address_prefixes                              = ["172.10.40.32/27"]
      private_link_service_network_policies_enabled = false
    }

    "dns-inbound" = {
      address_prefixes = ["172.10.50.0/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    # "dns-outbound" = {
    #   address_prefixes = ["172.10.50.32/27"]
    #   delegations = [{
    #     name    = "Microsoft.Network.dnsResolvers"
    #     service = "Microsoft.Network/dnsResolvers"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }

    # identity = { address_prefixes = ["172.10.60.0/26"] }
    # monitor  = { address_prefixes = ["172.10.61.0/26"] }

    "privatelink-hub" = {
      address_prefixes                  = ["172.10.30.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

dev_spoke = {
  # rg    = "rg-pub-dev-cus-net-01"
  # vnet  = "vnet-pub-dev-cus-01"
  cidrs = ["172.11.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["172.11.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    # "appsvc-int-linux-02" = {
    #   address_prefixes = ["172.11.11.32/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-02"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-linux-03" = {
    #   address_prefixes = ["172.11.11.64/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-03"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-linux-04" = {
    #   address_prefixes = ["172.11.11.96/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-04"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-01" = {
    #   address_prefixes = ["172.11.12.0/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-01"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-02" = {
    #   address_prefixes = ["172.11.12.32/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-02"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-03" = {
    #   address_prefixes = ["172.11.12.64/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-03"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-04" = {
    #   address_prefixes = ["172.11.12.96/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-04"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }

    internal = { address_prefixes = ["172.11.13.0/24"] }
    external = { address_prefixes = ["172.11.14.0/24"] }
    akspub   = { address_prefixes = ["172.11.2.0/24"] }

    pgflex = {
      address_prefixes = ["172.11.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["172.11.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    # "privatelink-cdbpg" = {
    #   address_prefixes                  = ["172.11.31.0/27"]
    #   private_endpoint_network_policies = "Disabled"
    # }

    # "privatelink-pg" = {
    #   address_prefixes                  = ["172.11.32.0/27"]
    #   private_endpoint_network_policies = "Disabled"
    # }

    # pgflex-auth = {
    #   address_prefixes = ["172.11.33.0/27"]
    #   delegations = [{
    #     name    = "pgflex-auth"
    #     service = "Microsoft.DBforPostgreSQL/flexibleServers"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
  }
}

qa_spoke = {
  cidrs = ["172.12.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["172.12.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    # "appsvc-int-linux-02" = {
    #   address_prefixes = ["172.12.11.32/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-02"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-linux-03" = {
    #   address_prefixes = ["172.12.11.64/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-03"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-linux-04" = {
    #   address_prefixes = ["172.12.11.96/27"]
    #   delegations = [{
    #     name    = "appsvc-linux-04"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-01" = {
    #   address_prefixes = ["172.12.12.0/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-01"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-02" = {
    #   address_prefixes = ["172.12.12.32/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-02"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-03" = {
    #   address_prefixes = ["172.12.12.64/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-03"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
    # "appsvc-int-windows-04" = {
    #   address_prefixes = ["172.12.12.96/27"]
    #   delegations = [{
    #     name    = "appsvc-windows-04"
    #     service = "Microsoft.Web/serverFarms"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }

    internal = { address_prefixes = ["172.12.13.0/24"] }
    external = { address_prefixes = ["172.12.14.0/24"] }
    akspub   = { address_prefixes = ["172.12.2.0/24"] }

    pgflex = {
      address_prefixes = ["172.12.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["172.12.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    # "privatelink-cdbpg" = {
    #   address_prefixes                  = ["172.12.31.0/27"]
    #   private_endpoint_network_policies = "Disabled"
    # }

    # "privatelink-pg" = {
    #   address_prefixes                  = ["172.12.32.0/27"]
    #   private_endpoint_network_policies = "Disabled"
    # }

    # pgflex-auth = {
    #   address_prefixes = ["172.12.33.0/27"]
    #   delegations = [{
    #     name    = "pgflex-auth"
    #     service = "Microsoft.DBforPostgreSQL/flexibleServers"
    #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    #   }]
    # }
  }
}

# Connectivity & Ingress
create_vpn_gateway          = true
vpn_sku                     = "VpnGw1"
public_ip_sku               = "Standard"
public_ip_allocation_method = "Static"

# App Gateway
create_app_gateway          = true
waf_mode                    = "Detection" # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"
appgw_private_frontend_ip   = "172.10.40.4"

# DNS Private Resolver – static inbound IP & forwarding rules
dnsr_inbound_static_ip = "172.10.50.4"
dns_forwarding_rules = [
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
fd_sku_name         = "Premium_AzureFrontDoor" # Standard_AzureFrontDoor | Premium_AzureFrontDoor

dnsresolver_enable_outbound = false

enable_s2s                 = true
s2s_peer_gateway_public_ip = "62.11.134.204"
s2s_peer_address_spaces    = ["10.11.3.0/24"]
s2s_shared_key             = "JM8ef6HqbnMg8zsuXoTvAn6UDo4cQhn*.7jWaDjRTrrZM!A7U@"
# Site-to-Site VPN – IPSec/IKE policy (HRZ → PUB)
s2s_ipsec_policy = {
  dh_group         = "DHGroup14"
  ike_encryption   = "AES256"
  ike_integrity    = "SHA256"
  ipsec_encryption = "AES256"
  ipsec_integrity  = "SHA256"
  pfs_group        = "PFS14"
  sa_lifetime      = 3600
}

local_pgflex_subnet_cidrs = {
  dev  = ["172.11.3.0/24"]
  qa   = ["172.12.3.0/24"]
  prod = ["172.14.3.0/24"]
  uat  = ["172.15.3.0/24"]
}

peer_pgflex_subnet_cidrs = {
  dev  = ["10.11.3.0/24"]
  qa   = ["10.12.3.0/24"]
  prod = ["10.14.3.0/24"]
  uat  = ["10.15.3.0/24"]
}
# core / env
plane           = "nonprod"      # nonprod | prod
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"
location        = "USGov Arizona"

# naming
product = "hrz"
region  = "usaz"                  # short region (e.g. cus, eus)
seq     = "01"

# shared network rg
shared_network_rg = "rg-hrz-np-usaz-01"

# private dns zones (privatelink)
private_zones = [
  # Storage (Blob/File/Queue/Table + Data Lake Gen2 + Static Website)
  "privatelink.blob.core.usgovcloudapi.net",
  "privatelink.file.core.usgovcloudapi.net",
  "privatelink.queue.core.usgovcloudapi.net",
  "privatelink.table.core.usgovcloudapi.net",
  "privatelink.dfs.core.usgovcloudapi.net",   # Data Lake Gen2 (dfs)
  "privatelink.web.core.usgovcloudapi.net",   # Static website

  # Key Vault
  "privatelink.vaultcore.usgovcloudapi.net",

  # Redis
  "privatelink.redis.cache.usgovcloudapi.net",

  # Cosmos DB (NoSQL / "documents")
  "privatelink.documents.azure.us",

  # Azure Database for PostgreSQL (Flexible Server)
  "privatelink.postgres.database.usgovcloudapi.net",

  # Cosmos DB for PostgreSQL (Citus)
  "privatelink.postgres.cosmos.azure.us",

  # Service Bus / Event Hubs
  "privatelink.servicebus.usgovcloudapi.net",

  # App Service (Web Apps + SCM/Kudu)
  "privatelink.azurewebsites.us",
  "privatelink.scm.azurewebsites.us",

  # AKS (replace <region> with e.g., usgovvirginia, usgovarizona)
  "privatelink.usgovarizona.azmk8s.us"             # e.g., privatelink.usgovarizona.azmk8s.us
]

# public dns zones
public_dns_zones = [
  "dev.horizon.intterra.io"
]

# vnets
nonprod_hub = {
  rg    = "rg-hrz-np-usaz-01"
  vnet  = "vnet-hrz-np-hub-usaz-01"
  cidrs = ["10.10.0.0/16"]

  subnets = {
    GatewaySubnet                 = { address_prefixes = ["10.10.0.0/24"] }   # vpn gateway
    AzureFirewallSubnet           = { address_prefixes = ["10.10.1.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["10.10.1.64/26"] }
    RouteServerSubnet             = { address_prefixes = ["10.10.1.128/27"] }
    AzureBastionSubnet            = { address_prefixes = ["10.10.3.0/26"] }
    akshrz                        = { address_prefixes = ["10.10.2.0/24"] }
    internal                      = { address_prefixes = ["10.10.13.0/24"] }
    external                      = { address_prefixes = ["10.10.14.0/24"] }
    "shared-svc"                  = { address_prefixes = ["10.10.20.0/24"] }
    appgw                         = { address_prefixes = ["10.10.40.0/27"] }  # app gateway

    "dns-inbound" = {
      address_prefixes = ["10.10.50.0/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "dns-outbound" = {
      address_prefixes = ["10.10.50.32/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    identity = { address_prefixes = ["10.10.60.0/26"] }
    monitor  = { address_prefixes = ["10.10.61.0/26"] }

    "privatelink-hub" = {
      address_prefixes                  = ["10.10.30.0/27"]
      private_endpoint_network_policies = "Disabled"        # required for private endpoints
    }
  }
}

dev_spoke = {
  rg    = "rg-hrz-dev-usaz-01"
  vnet  = "vnet-hrz-dev-usaz-01"
  cidrs = ["10.11.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["10.11.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["10.11.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["10.11.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["10.11.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["10.11.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["10.11.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["10.11.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["10.11.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["10.11.13.0/24"] }
    external = { address_prefixes = ["10.11.14.0/24"] }
    akshrz   = { address_prefixes = ["10.11.2.0/24"] }

    pgflex = {
      address_prefixes = ["10.11.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["10.11.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["10.11.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

qa_spoke = {
  rg    = "rg-hrz-qa-usaz-01"
  vnet  = "vnet-hrz-qa-usaz-01"
  cidrs = ["10.12.0.0/16"]

  subnets = {
    "appsvc-int-linux-01" = {
      address_prefixes = ["10.12.11.0/27"]
      delegations = [{
        name    = "appsvc-linux-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-02" = {
      address_prefixes = ["10.12.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["10.12.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["10.12.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["10.12.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["10.12.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["10.12.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["10.12.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    internal = { address_prefixes = ["10.12.13.0/24"] }
    external = { address_prefixes = ["10.12.14.0/24"] }
    akshrz   = { address_prefixes = ["10.12.2.0/24"] }

    pgflex = {
      address_prefixes = ["10.12.3.0/24"]
      delegations = [{
        name    = "pgflex"
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    privatelink = {
      address_prefixes                  = ["10.12.30.0/24"]
      private_endpoint_network_policies = "Disabled"
    }

    "privatelink-cdbpg" = {
      address_prefixes                  = ["10.12.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

# connectivity & ingress
create_vpn_gateway          = true      # create vpng
vpn_sku                     = "VpnGw1"  # e.g. VpnGw1, VpnGw2, VpnGw3
public_ip_sku               = "Standard"
public_ip_allocation_method = "Static"

create_app_gateway          = false     # create app gw
waf_mode                    = "Detection"   # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"    # Enabled | Disabled

# tags
tags = {
  product = "horizon"
  owner   = "it operations"
}

# dns resolver inbound static ip
dnsr_inbound_static_ip = "10.10.50.4"   # points to dns-inbound endpoint ip
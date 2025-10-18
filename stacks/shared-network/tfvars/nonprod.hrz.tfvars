# Core / plane
plane    = "nonprod"                # nonprod | prod
product  = "hrz"                    # hrz | pub
location = "usgovarizona"           # canonical region name for azurerm provider
region   = "usaz"                   # short code used in names
seq      = "01"                     # sequence in names

# Subscriptions / Tenants (cross-subscription support)
# HUB (shared-network) subscription/tenant — REQUIRED
hub_subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
hub_tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# If DEV/QA VNets live in *different* subscriptions, set these:
dev_subscription_id = null  # e.g. "11111111-2222-3333-4444-555555555555"
dev_tenant_id       = null  # e.g. "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

qa_subscription_id  = null  # e.g. "66666666-7777-8888-9999-000000000000"
qa_tenant_id        = null  # e.g. "ffffffff-1111-2222-3333-444444444444"

# Private DNS zones (Azure Government)
private_zones = [
  # Storage
  "privatelink.blob.core.usgovcloudapi.net",
  "privatelink.file.core.usgovcloudapi.net",
  "privatelink.queue.core.usgovcloudapi.net",
  "privatelink.table.core.usgovcloudapi.net",
  "privatelink.dfs.core.usgovcloudapi.net",   # Data Lake Gen2
  "privatelink.web.core.usgovcloudapi.net",   # Static website
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
  "privatelink.usgovarizona.azmk8s.us"
]

# Public DNS zones
public_dns_zones = [
  "dev.horizon.intterra.io"
]

# VNets — NONPROD plane: hub + dev + qa
nonprod_hub = {
  rg    = "rg-hrz-np-usaz-01-network"
  vnet  = "vnet-hrz-np-hub-usaz-01"
  cidrs = ["10.10.0.0/16"]

  subnets = {
    GatewaySubnet                 = { address_prefixes = ["10.10.0.0/24"] }
    AzureFirewallSubnet           = { address_prefixes = ["10.10.1.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["10.10.1.64/26"] }
    RouteServerSubnet             = { address_prefixes = ["10.10.1.128/27"] }
    AzureBastionSubnet            = { address_prefixes = ["10.10.3.0/26"] }
    akshrz                        = { address_prefixes = ["10.10.2.0/24"] }
    internal                      = { address_prefixes = ["10.10.13.0/24"] }
    external                      = { address_prefixes = ["10.10.14.0/24"] }
    "shared-svc"                  = { address_prefixes = ["10.10.20.0/24"] }
    appgw                         = { address_prefixes = ["10.10.40.0/27"] }

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
      private_endpoint_network_policies = "Disabled"
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

# Connectivity & Ingress
create_vpn_gateway          = true       # create VPN gateway in hub
vpn_sku                     = "VpnGw1"
public_ip_sku               = "Standard"
public_ip_allocation_method = "Static"

# If true → VPN module creates its own PIP; if false → this stack creates an external PIP
create_vpng_public_ip       = false

# App Gateway (disabled for now in nonprod example)
create_app_gateway          = false
waf_mode                    = "Detection"   # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"

# DNS Private Resolver – optional static inbound IP & forwarding rules
dnsr_inbound_static_ip = "10.10.50.4"
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
  lane    = "nonprod"
}

# ── Front Door ────────────────────────────────────
fd_create_frontdoor = true
fd_sku_name         = "Standard_AzureFrontDoor"
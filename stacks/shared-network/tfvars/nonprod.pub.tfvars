# Core / plane
plane    = "nonprod"                # nonprod | prod
product  = "pub"                    # hrz | pub
location = "centralus"              # canonical azurerm region name
region   = "cus"                    # short code used in names
seq      = "01"                     # sequence in names

# pub nonprod
github_sp_object_id = "11111111-2222-3333-4444-555555555555"

# Subscriptions / Tenants (cross-subscription support)
# HUB (shared-network) subscription/tenant — REQUIRED
hub_subscription_id = "ee8a4693-54d4-4de8-842b-b6f35fc0674d"
hub_tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# If DEV/QA VNets live in different subscriptions, set these
dev_subscription_id = "57f8aa30-981c-4764-94f6-6691c4d5c01c" 
dev_tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

qa_subscription_id  = "647feab6-e53a-4db2-99ab-55d04a5997d7"
qa_tenant_id        = "dd58f16c-b85a-4d66-99e1-f86905453853"

# Private DNS zones (Azure Commercial)
private_zones = [
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
  "dev.horizon.intterra.io"
]

# VNets — NONPROD plane: hub + dev + qa
nonprod_hub = {
  rg    = "rg-pub-np-cus-net-01"
  vnet  = "vnet-pub-np-hub-cus-01"
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
    "shared-svc"                  = { address_prefixes = ["172.10.20.0/24"] }
    appgw                         = { address_prefixes = ["172.10.40.0/27"] }

    "dns-inbound" = {
      address_prefixes = ["172.10.50.0/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    "dns-outbound" = {
      address_prefixes = ["172.10.50.32/27"]
      delegations = [{
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

    identity = { address_prefixes = ["172.10.60.0/26"] }
    monitor  = { address_prefixes = ["172.10.61.0/26"] }

    "privatelink-hub" = {
      address_prefixes                  = ["172.10.30.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

dev_spoke = {
  rg    = "rg-pub-dev-cus-net-01"
  vnet  = "vnet-pub-dev-cus-01"
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
    "appsvc-int-linux-02" = {
      address_prefixes = ["172.11.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["172.11.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["172.11.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["172.11.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["172.11.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["172.11.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["172.11.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

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

    "privatelink-cdbpg" = {
      address_prefixes                  = ["172.11.31.0/27"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

qa_spoke = {
  rg    = "rg-pub-qa-cus-net-01"
  vnet  = "vnet-pub-qa-cus-01"
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
    "appsvc-int-linux-02" = {
      address_prefixes = ["172.12.11.32/27"]
      delegations = [{
        name    = "appsvc-linux-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-03" = {
      address_prefixes = ["172.12.11.64/27"]
      delegations = [{
        name    = "appsvc-linux-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-linux-04" = {
      address_prefixes = ["172.12.11.96/27"]
      delegations = [{
        name    = "appsvc-linux-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-01" = {
      address_prefixes = ["172.12.12.0/27"]
      delegations = [{
        name    = "appsvc-windows-01"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-02" = {
      address_prefixes = ["172.12.12.32/27"]
      delegations = [{
        name    = "appsvc-windows-02"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-03" = {
      address_prefixes = ["172.12.12.64/27"]
      delegations = [{
        name    = "appsvc-windows-03"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }
    "appsvc-int-windows-04" = {
      address_prefixes = ["172.12.12.96/27"]
      delegations = [{
        name    = "appsvc-windows-04"
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }]
    }

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

    "privatelink-cdbpg" = {
      address_prefixes                  = ["172.12.31.0/27"]
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
create_vpng_public_ip       = false

# App Gateway (disabled in this nonprod example)
create_app_gateway          = false
waf_mode                    = "Detection"   # Detection | Prevention
appgw_public_ip_enabled     = true
appgw_sku_name              = "WAF_v2"
appgw_sku_tier              = "WAF_v2"
appgw_capacity              = 1
appgw_cookie_based_affinity = "Disabled"

# DNS Private Resolver – optional static inbound IP & forwarding rules
dnsr_inbound_static_ip = "172.10.50.4"
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

# ── Front Door ────────────────────────────────────
fd_create_frontdoor = true
fd_sku_name         = "Standard_AzureFrontDoor"
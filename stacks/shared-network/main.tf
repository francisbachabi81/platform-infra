# ── terraform & providers ─────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9.0"
    }
  }
}

# Default = HUB subscription
provider "azurerm" {
  features {}
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Per-env aliases (fallback to hub if not provided)
provider "azurerm" {
  alias     = "dev"
  features {}
  subscription_id = var.dev_subscription_id != "" ? var.dev_subscription_id : var.hub_subscription_id
  tenant_id       = var.dev_tenant_id       != "" ? var.dev_tenant_id       : var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias     = "qa"
  features {}
  subscription_id = var.qa_subscription_id != "" ? var.qa_subscription_id : var.hub_subscription_id
  tenant_id       = var.qa_tenant_id       != "" ? var.qa_tenant_id       : var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias     = "prod"
  features {}
  subscription_id = var.prod_subscription_id != "" ? var.prod_subscription_id : var.hub_subscription_id
  tenant_id       = var.prod_tenant_id       != "" ? var.prod_tenant_id       : var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias     = "uat"
  features {}
  subscription_id = var.uat_subscription_id != "" ? var.uat_subscription_id : var.hub_subscription_id
  tenant_id       = var.uat_tenant_id       != "" ? var.uat_tenant_id       : var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# ── globals ───────────────────────────────────────────────────────────────────
locals {
  is_nonprod = var.plane == "nonprod"
  is_prod    = var.plane == "prod"
  plane_code = local.is_nonprod ? "np" : "pr"
  lane       = local.is_nonprod ? "nonprod" : "prod"

  rg_layer_by_key = local.is_nonprod ? {
    nphub = "shared-network"
    dev   = "platform-dev"
    qa    = "platform-qa"
  } : {
    prhub = "shared-network"
    prod  = "platform-prod"
    uat   = "platform-uat"
  }

  vnet_layer_by_key = local.is_nonprod ? {
    nphub = "shared-network"
    dev   = "env-dev-network"
    qa    = "env-qa-network"
  } : {
    prhub = "shared-network"
    prod  = "env-prod-network"
    uat   = "env-uat-network"
  }

  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    department   = "it"
    businessunit = "public-safety"
    compliance   = "cjis"
  }

  plane_tags = local.is_nonprod ? {
    lane        = "nonprod"
    purpose     = "shared-nonprod"
    criticality = "medium"
  } : {
    lane        = "prod"
    purpose     = "shared-prod"
    criticality = "high"
  }

  base_layer_tags = {
    layer        = "shared-network"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  }

  # consolidated base for most tags
  tag_base = merge(var.tags, local.org_base_tags, local.base_layer_tags)

  dev_only_tags  = { environment = "dev",  purpose = "env-dev",  criticality = "Low",    patchgroup = "Test",    lane = "nonprod" }
  qa_only_tags   = { environment = "qa",   purpose = "env-qa",   criticality = "Medium", patchgroup = "Test",    lane = "nonprod" }
  uat_only_tags  = { environment = "uat",  purpose = "env-uat",  criticality = "Medium", patchgroup = "Monthly", lane = "prod" }
  prod_only_tags = { environment = "prod", purpose = "env-prod", criticality = "High",   patchgroup = "Monthly", lane = "prod" }

  short_zone_map = {
    # Commercial
    "privatelink.blob.core.windows.net"       = "plb"
    "privatelink.file.core.windows.net"       = "plf"
    "privatelink.queue.core.windows.net"      = "plq"
    "privatelink.table.core.windows.net"      = "plt"
    "privatelink.vaultcore.azure.net"         = "kv"
    "privatelink.redis.cache.windows.net"     = "redis"
    "privatelink.documents.azure.com"         = "cosmos"
    "privatelink.postgres.database.azure.com" = "pg"
    "privatelink.postgres.cosmos.azure.com"   = "cpg"
    "privatelink.servicebus.windows.net"      = "svb"
    "privatelink.azurewebsites.net"           = "app"
    "privatelink.scm.azurewebsites.net"       = "scm"
    "privatelink.centralus.azmk8s.io"         = "azmk8scus"

    # Gov
    "privatelink.blob.core.usgovcloudapi.net"         = "plb"
    "privatelink.file.core.usgovcloudapi.net"         = "plf"
    "privatelink.queue.core.usgovcloudapi.net"        = "plq"
    "privatelink.table.core.usgovcloudapi.net"        = "plt"
    "privatelink.dfs.core.usgovcloudapi.net"          = "pldfs"
    "privatelink.web.core.usgovcloudapi.net"          = "plweb"
    "privatelink.vaultcore.usgovcloudapi.net"         = "kv"
    "privatelink.redis.cache.usgovcloudapi.net"       = "redis"
    "privatelink.documents.azure.us"                  = "cosmos"
    "privatelink.postgres.database.usgovcloudapi.net" = "pg"
    "privatelink.postgres.cosmos.azure.us"            = "cpg"
    "privatelink.servicebus.usgovcloudapi.net"        = "svb"
    "privatelink.azurewebsites.us"                    = "app"
    "privatelink.scm.azurewebsites.us"                = "scm"
    "privatelink.usgovvirginia.cx.aks.containerservice.azure.us" = "azmk8svag"
    "privatelink.usgovarizona.cx.aks.containerservice.azure.us"  = "azmk8sazg"
  }

  zone_token = {
    for z in var.private_zones :
    z => coalesce(lookup(local.short_zone_map, z, null), "z${substr(md5(z), 0, 6)}")
  }

  name_vpng_pip  = "pip-${var.product}-${local.plane_code}-vpng-${var.region}-${var.seq}"
  name_vpng      = "vpng-${var.product}-${local.plane_code}-${var.region}-${var.seq}"
  name_wafp      = "wafp-${var.product}-${local.plane_code}-${var.region}-${var.seq}"
  name_agw_pip   = "pip-${var.product}-${local.plane_code}-agw-${var.region}-${var.seq}"
  name_agw       = "agw-${var.product}-${local.plane_code}-${var.region}-${var.seq}"
  name_appgw_nsg = "nsg-${var.product}-${local.plane_code}-hub-appgw"

  hub_key = local.is_nonprod ? "nphub" : "prhub"
}

# ── resource groups (per-env with proper provider) ────────────────────────────
module "rg_hub" {
  source   = "../../modules/resource-group"
  name     = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  location = var.location
  tags     = merge(local.tag_base, local.plane_tags, { layer = local.is_nonprod ? local.rg_layer_by_key["nphub"] : local.rg_layer_by_key["prhub"] })
}

module "rg_dev" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.dev }
  source    = "../../modules/resource-group"
  name      = var.dev_spoke.rg
  location  = var.location
  tags      = merge(local.tag_base, local.dev_only_tags, { layer = local.rg_layer_by_key["dev"] })
}

module "rg_qa" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.qa }
  source    = "../../modules/resource-group"
  name      = var.qa_spoke.rg
  location  = var.location
  tags      = merge(local.tag_base, local.qa_only_tags, { layer = local.rg_layer_by_key["qa"] })
}

module "rg_prod" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.prod }
  source    = "../../modules/resource-group"
  name      = var.prod_spoke.rg
  location  = var.location
  tags      = merge(local.tag_base, local.prod_only_tags, { layer = local.rg_layer_by_key["prod"] })
}

module "rg_uat" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.uat }
  source    = "../../modules/resource-group"
  name      = var.uat_spoke.rg
  location  = var.location
  tags      = merge(local.tag_base, local.uat_only_tags, { layer = local.rg_layer_by_key["uat"] })
}

# ── vnets (per-env with proper provider) ──────────────────────────────────────
module "vnet_hub" {
  source              = "../../modules/vnet"
  name                = local.is_nonprod ? var.nonprod_hub.vnet : var.prod_hub.vnet
  resource_group_name = local.is_nonprod ? var.nonprod_hub.rg   : var.prod_hub.rg
  location            = var.location
  address_space       = (local.is_nonprod ? var.nonprod_hub : var.prod_hub).cidrs
  subnets             = (local.is_nonprod ? var.nonprod_hub : var.prod_hub).subnets
  tags                = merge(local.tag_base, { purpose = "shared-hub-connectivity" }, { layer = local.is_nonprod ? local.vnet_layer_by_key["nphub"] : local.vnet_layer_by_key["prhub"] })
  depends_on          = [module.rg_hub]
}

module "vnet_dev" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.dev }
  source              = "../../modules/vnet"
  name                = var.dev_spoke.vnet
  resource_group_name = var.dev_spoke.rg
  location            = var.location
  address_space       = var.dev_spoke.cidrs
  subnets             = var.dev_spoke.subnets
  tags                = merge(local.tag_base, local.dev_only_tags, { layer = local.vnet_layer_by_key["dev"] })
  depends_on          = [module.rg_dev]
}

module "vnet_qa" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.qa }
  source              = "../../modules/vnet"
  name                = var.qa_spoke.vnet
  resource_group_name = var.qa_spoke.rg
  location            = var.location
  address_space       = var.qa_spoke.cidrs
  subnets             = var.qa_spoke.subnets
  tags                = merge(local.tag_base, local.qa_only_tags, { layer = local.vnet_layer_by_key["qa"] })
  depends_on          = [module.rg_qa]
}

module "vnet_prod" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.prod }
  source              = "../../modules/vnet"
  name                = var.prod_spoke.vnet
  resource_group_name = var.prod_spoke.rg
  location            = var.location
  address_space       = var.prod_spoke.cidrs
  subnets             = var.prod_spoke.subnets
  tags                = merge(local.tag_base, local.prod_only_tags, { layer = local.vnet_layer_by_key["prod"] })
  depends_on          = [module.rg_prod]
}

module "vnet_uat" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.uat }
  source              = "../../modules/vnet"
  name                = var.uat_spoke.vnet
  resource_group_name = var.uat_spoke.rg
  location            = var.location
  address_space       = var.uat_spoke.cidrs
  subnets             = var.uat_spoke.subnets
  tags                = merge(local.tag_base, local.uat_only_tags, { layer = local.vnet_layer_by_key["uat"] })
  depends_on          = [module.rg_uat]
}

# ── vnet peerings (ensure VPN GW first for transit) ───────────────────────────
resource "azurerm_virtual_network_peering" "hub_to_dev" {
  count                         = local.is_nonprod ? 1 : 0
  name                          = "peer-hub-to-dev"
  resource_group_name           = var.nonprod_hub.rg
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_dev[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng] # critical
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  count                         = local.is_nonprod ? 1 : 0
  provider                      = azurerm.dev
  name                          = "peer-dev-to-hub"
  resource_group_name           = var.dev_spoke.rg
  virtual_network_name          = module.vnet_dev[0].name
  remote_virtual_network_id     = module.vnet_hub.id
  allow_gateway_transit         = false
  allow_forwarded_traffic       = true
  use_remote_gateways           = true
  depends_on                    = [azurerm_virtual_network_peering.hub_to_dev]
}

resource "azurerm_virtual_network_peering" "hub_to_qa" {
  count                         = local.is_nonprod ? 1 : 0
  name                          = "peer-hub-to-qa"
  resource_group_name           = var.nonprod_hub.rg
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_qa[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng] # critical
}

resource "azurerm_virtual_network_peering" "qa_to_hub" {
  count                         = local.is_nonprod ? 1 : 0
  provider                      = azurerm.qa
  name                          = "peer-qa-to-hub"
  resource_group_name           = var.qa_spoke.rg
  virtual_network_name          = module.vnet_qa[0].name
  remote_virtual_network_id     = module.vnet_hub.id
  allow_gateway_transit         = false
  allow_forwarded_traffic       = true
  use_remote_gateways           = true
  depends_on                    = [azurerm_virtual_network_peering.hub_to_qa]
}

resource "azurerm_virtual_network_peering" "hub_to_prod" {
  count                         = local.is_prod ? 1 : 0
  name                          = "peer-hub-to-prod"
  resource_group_name           = var.prod_hub.rg
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_prod[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng] # critical
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  count                         = local.is_prod ? 1 : 0
  provider                      = azurerm.prod
  name                          = "peer-prod-to-hub"
  resource_group_name           = var.prod_spoke.rg
  virtual_network_name          = module.vnet_prod[0].name
  remote_virtual_network_id     = module.vnet_hub.id
  allow_gateway_transit         = false
  allow_forwarded_traffic       = true
  use_remote_gateways           = true
  depends_on                    = [azurerm_virtual_network_peering.hub_to_prod]
}

resource "azurerm_virtual_network_peering" "hub_to_uat" {
  count                         = local.is_prod ? 1 : 0
  name                          = "peer-hub-to-uat"
  resource_group_name           = var.prod_hub.rg
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_uat[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng] # critical
}

resource "azurerm_virtual_network_peering" "uat_to_hub" {
  count                         = local.is_prod ? 1 : 0
  provider                      = azurerm.uat
  name                          = "peer-uat-to-hub"
  resource_group_name           = var.uat_spoke.rg
  virtual_network_name          = module.vnet_uat[0].name
  remote_virtual_network_id     = module.vnet_hub.id
  allow_gateway_transit         = false
  allow_forwarded_traffic       = true
  use_remote_gateways           = true
  depends_on                    = [azurerm_virtual_network_peering.hub_to_uat]
}

# ── private dns (zones + links) ───────────────────────────────────────────────
locals {
  vnet_links_nonprod_map = local.is_nonprod ? merge(
    { for z in var.private_zones :
      "hub-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-hub-${local.plane_code}"
        zone    = z
        vnet_id = module.vnet_hub.id
      }
    },
    { for z in var.private_zones :
      "dev-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-spk-dev"
        zone    = z
        vnet_id = module.vnet_dev[0].id
      }
    },
    { for z in var.private_zones :
      "qa-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-spk-qa"
        zone    = z
        vnet_id = module.vnet_qa[0].id
      }
    }
  ) : {}

  vnet_links_prod_map = local.is_prod ? merge(
    { for z in var.private_zones :
      "hub-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-hub-${local.plane_code}"
        zone    = z
        vnet_id = module.vnet_hub.id
      }
    },
    { for z in var.private_zones :
      "prod-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-spk-prod"
        zone    = z
        vnet_id = module.vnet_prod[0].id
      }
    },
    { for z in var.private_zones :
      "uat-${local.zone_token[z]}" => {
        name    = "lnk-${local.zone_token[z]}-spk-uat"
        zone    = z
        vnet_id = module.vnet_uat[0].id
      }
    }
  ) : {}

  vnet_links = merge(local.vnet_links_nonprod_map, local.vnet_links_prod_map)
}

module "pdns" {
  source              = "../../modules/private-dns"
  resource_group_name = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  zones               = var.private_zones
  vnet_links          = local.vnet_links
  tags                = merge(local.tag_base, { purpose = "private-dns" })
  depends_on          = [module.rg_hub]
}

# ── connectivity: vpn gateway ─────────────────────────────────────────────────
locals {
  create_vpng_effective     = var.create_vpn_gateway
  vpng_hub_rg               = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  vpng_gateway_subnet_id    = try(module.vnet_hub.subnet_ids["GatewaySubnet"], null)
  create_external_vpng_pip  = local.create_vpng_effective && !var.create_vpng_public_ip
}

resource "azurerm_public_ip" "vpngw" {
  count               = local.create_external_vpng_pip ? 1 : 0
  name                = local.name_vpng_pip
  location            = var.location
  resource_group_name = local.vpng_hub_rg
  allocation_method   = var.public_ip_allocation_method
  sku                 = var.public_ip_sku
  tags = merge(local.tag_base, {
    purpose = "p2s-vpn-gateway-pip"
    service = "connectivity"
    lane    = local.lane
  })
  depends_on = [module.rg_hub] # keep RG creation edge only
}

module "vpng" {
  count               = local.create_vpng_effective ? 1 : 0
  source              = "../../modules/vpn-gateway"
  name                = local.name_vpng
  location            = var.location
  resource_group_name = local.vpng_hub_rg
  sku                 = var.vpn_sku
  create_public_ip    = var.create_vpng_public_ip
  public_ip_id        = local.create_external_vpng_pip ? azurerm_public_ip.vpngw[0].id : null
  gateway_subnet_id   = local.vpng_gateway_subnet_id
  tenant_id           = var.hub_tenant_id
  tags = merge(local.tag_base, {
    purpose = "p2s-vpn-gateway"
    service = "connectivity"
    lane    = local.lane
  })
  depends_on = [module.vnet_hub, module.nsg] # ensure GatewaySubnet exists
}

# ── ingress: waf & appgw ──────────────────────────────────────────────────────
locals {
  appgw_hub_rg     = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  has_appgw_subnet = local.is_nonprod ? contains(keys(var.nonprod_hub.subnets), "appgw") : contains(keys(var.prod_hub.subnets), "appgw")
  appgw_subnet_id  = try(module.vnet_hub.subnet_ids["appgw"], null)
  appgw_enabled    = var.create_app_gateway && local.has_appgw_subnet && local.appgw_subnet_id != null
}

module "waf" {
  count               = local.appgw_enabled ? 1 : 0
  source              = "../../modules/waf-policy"
  name                = local.name_wafp
  location            = var.location
  resource_group_name = local.appgw_hub_rg
  mode                = var.waf_mode
  tags                = merge(local.tag_base, { purpose = "app-gateway-waf-policy", service = "ingress", lane = local.lane })
  depends_on          = [module.rg_hub]
}

resource "azurerm_network_security_group" "appgw_nsg" {
  count               = local.appgw_enabled ? 1 : 0
  name                = local.name_appgw_nsg
  location            = var.location
  resource_group_name = local.appgw_hub_rg
  tags                = merge(local.tag_base, { purpose = "app-gateway-subnet-nsg", lane = local.lane })
  depends_on          = [module.rg_hub]
}

resource "azurerm_network_security_rule" "appgw_allow_gwmgr" {
  count                       = length(azurerm_network_security_group.appgw_nsg)
  name                        = "allow-gwmgr-65200-65535"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

# Only if public listeners are enabled:
resource "azurerm_network_security_rule" "appgw_allow_https_public" {
  count                       = var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-https-from-internet"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http_public" {
  count                       = var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-http-from-internet"
  priority                    = 125
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_subnet_network_security_group_association" "appgw_assoc" {
  count                     = local.appgw_enabled ? 1 : 0
  subnet_id                 = local.appgw_subnet_id
  network_security_group_id = azurerm_network_security_group.appgw_nsg[0].id
  depends_on = [
    azurerm_network_security_rule.appgw_allow_alb,
    azurerm_network_security_rule.appgw_allow_inbound_snat
  ]
}

module "appgw" {
  count                 = local.appgw_enabled ? 1 : 0
  source                = "../../modules/app-gateway"
  name                  = local.name_agw
  location              = var.location
  resource_group_name   = local.appgw_hub_rg
  public_ip_enabled     = var.appgw_public_ip_enabled
  public_ip_name        = local.name_agw_pip
  subnet_id             = local.appgw_subnet_id
  sku_name              = var.appgw_sku_name
  sku_tier              = var.appgw_sku_tier
  capacity              = var.appgw_capacity
  cookie_based_affinity = var.appgw_cookie_based_affinity
  waf_policy_id         = try(module.waf[0].id, null)
  tags                  = merge(local.tag_base, { purpose = "app-gateway-waf", service = "ingress", lane = local.lane })
  depends_on            = [azurerm_subnet_network_security_group_association.appgw_assoc]
}

# ── generic nsgs (except excluded) ────────────────────────────────────────────
locals {
  _np_hub_subnet_names  = local.is_nonprod ? keys(var.nonprod_hub.subnets) : []
  _np_dev_subnet_names  = local.is_nonprod ? keys(var.dev_spoke.subnets) : []
  _np_qa_subnet_names   = local.is_nonprod ? keys(var.qa_spoke.subnets) : []
  _pr_hub_subnet_names  = local.is_prod ? keys(var.prod_hub.subnets) : []
  _pr_prod_subnet_names = local.is_prod ? keys(var.prod_spoke.subnets) : []
  _pr_uat_subnet_names  = local.is_prod ? keys(var.uat_spoke.subnets) : []

  _exclude = concat(var.nsg_exclude_subnets, ["appgw", "GatewaySubnet"])

  nsg_keys = local.is_nonprod ? concat(
    [for s in local._np_hub_subnet_names  : "hub-${s}"  if !contains(local._exclude, s)],
    [for s in local._np_dev_subnet_names  : "dev-${s}"  if !contains(local._exclude, s)],
    [for s in local._np_qa_subnet_names   : "qa-${s}"   if !contains(local._exclude, s)]
  ) : concat(
    [for s in local._pr_hub_subnet_names  : "hub-${s}"  if !contains(local._exclude, s)],
    [for s in local._pr_prod_subnet_names : "prod-${s}" if !contains(local._exclude, s)],
    [for s in local._pr_uat_subnet_names  : "uat-${s}"  if !contains(local._exclude, s)]
  )

  nsg_name_by_key = {
    for k in local.nsg_keys :
    k => substr(replace(replace(replace("nsg-${var.product}-${k}", " ", "-"), "_", "-"), ".", "-"), 0, 80)
  }

  subnet_id_by_key = {
    for k in local.nsg_keys :
    k => (
      can(regex("^hub-",  k)) ? try(module.vnet_hub.subnet_ids[replace(k, "hub-",  "")], null) :
      can(regex("^dev-",  k)) ? try(module.vnet_dev[0].subnet_ids[replace(k, "dev-",  "")], null) :
      can(regex("^qa-",   k)) ? try(module.vnet_qa[0].subnet_ids[replace(k, "qa-",   "")], null) :
      can(regex("^prod-", k)) ? try(module.vnet_prod[0].subnet_ids[replace(k, "prod-", "")], null) :
      can(regex("^uat-",  k)) ? try(module.vnet_uat[0].subnet_ids[replace(k, "uat-",  "")], null) :
      null
    )
  }

  subnet_nsgs_all = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], subnet_id = local.subnet_id_by_key[k] }
  }
}

module "nsg" {
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  subnet_nsgs         = local.subnet_nsgs_all
  tags                = merge(local.tag_base, { lane = local.lane })
  # implicit deps via subnet IDs are sufficient
}

# ── nsg rules: isolation & baseline ───────────────────────────────────────────
locals {
  all_plane_nsg_targets = {
    for k in local.nsg_keys :
    k => local.nsg_name_by_key[k]
    if !can(regex("privatelink", k)) && !can(regex("-appgw$", k))
  }

  dev_nsg_targets_np  = local.is_nonprod ? { for k in local.nsg_keys : k => local.nsg_name_by_key[k] if can(regex("^dev-",  k)) } : {}
  qa_nsg_targets_np   = local.is_nonprod ? { for k in local.nsg_keys : k => local.nsg_name_by_key[k] if can(regex("^qa-",   k)) } : {}
  prod_nsg_targets_pr = local.is_prod    ? { for k in local.nsg_keys : k => local.nsg_name_by_key[k] if can(regex("^prod-", k)) } : {}
  uat_nsg_targets_pr  = local.is_prod    ? { for k in local.nsg_keys : k => local.nsg_name_by_key[k] if can(regex("^uat-",  k)) } : {}

  dev_vnet_cidr  = local.is_nonprod ? lookup(var.dev_spoke,  "cidrs", ["0.0.0.0/32"])[0] : null
  qa_vnet_cidr   = local.is_nonprod ? lookup(var.qa_spoke,   "cidrs", ["0.0.0.0/32"])[0] : null
  prod_vnet_cidr = local.is_prod    ? lookup(var.prod_spoke, "cidrs", ["0.0.0.0/32"])[0] : null
  uat_vnet_cidr  = local.is_prod    ? lookup(var.uat_spoke,  "cidrs", ["0.0.0.0/32"])[0] : null
}

resource "azurerm_network_security_rule" "deny_all_to_internet" {
  for_each                    = local.all_plane_nsg_targets
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "deny_dev_to_qa_np" {
  for_each                    = local.dev_nsg_targets_np
  name                        = "deny-to-qa"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.qa_vnet_cidr
  resource_group_name         = var.nonprod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "deny_qa_to_dev_np" {
  for_each                    = local.qa_nsg_targets_np
  name                        = "deny-to-dev"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.dev_vnet_cidr
  resource_group_name         = var.nonprod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "deny_prod_to_uat_pr" {
  for_each                    = local.prod_nsg_targets_pr
  name                        = "deny-to-uat"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.uat_vnet_cidr
  resource_group_name         = var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "deny_uat_to_prod_pr" {
  for_each                    = local.uat_nsg_targets_pr
  name                        = "deny-to-prod"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.prod_vnet_cidr
  resource_group_name         = var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

# ── baseline egress on workload nsgs ──────────────────────────────────────────
locals {
  _workload_pairs = {
    for k in local.nsg_keys :
    k => {
      nsg_name    = local.nsg_name_by_key[k]
      subnet_key  = k
      subnet_name = element(split("-", k), length(split("-", k)) - 1)
    }
  }

  workload_nsg_targets = {
    for k, v in local._workload_pairs :
    k => v.nsg_name
    if !contains(var.nsg_exclude_subnets, v.subnet_name) && !can(regex("privatelink", k))
  }
}

resource "azurerm_network_security_rule" "allow_dns_to_azure" {
  for_each                    = local.workload_nsg_targets
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure" {
  for_each                    = local.workload_nsg_targets
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "allow_storage_egress" {
  for_each                    = local.workload_nsg_targets
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "allow_azuremonitor_egress" {
  for_each                    = local.workload_nsg_targets
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

# ── pep rules (private endpoints allow/deny) ──────────────────────────────────
locals {
  _pe_keys_plane = [for k in local.nsg_keys : k if can(regex("privatelink", k))]

  _pe_role_by_key = {
    for k in local._pe_keys_plane :
    k => (
      startswith(k, "hub-")  ? "hub"  :
      startswith(k, "dev-")  ? "dev"  :
      startswith(k, "qa-")   ? "qa"   :
      startswith(k, "prod-") ? "prod" :
      startswith(k, "uat-")  ? "uat"  : "other"
    )
  }

  cidr_np_hub = local.is_nonprod ? lookup(var.nonprod_hub, "cidrs", ["0.0.0.0/32"])[0] : null
  cidr_np_dev = local.is_nonprod ? lookup(var.dev_spoke,  "cidrs", ["0.0.0.0/32"])[0]  : null
  cidr_np_qa  = local.is_nonprod ? lookup(var.qa_spoke,   "cidrs", ["0.0.0.0/32"])[0]  : null

  cidr_pr_hub  = local.is_prod ? lookup(var.prod_hub,  "cidrs", ["0.0.0.0/32"])[0] : null
  cidr_pr_prod = local.is_prod ? lookup(var.prod_spoke,"cidrs", ["0.0.0.0/32"])[0] : null
  cidr_pr_uat  = local.is_prod ? lookup(var.uat_spoke, "cidrs", ["0.0.0.0/32"])[0] : null

  _lane_prefixes = local.is_nonprod ? {
    hub = compact([local.cidr_np_hub, local.cidr_np_dev, local.cidr_np_qa])
    dev = compact([local.cidr_np_hub, local.cidr_np_dev])
    qa  = compact([local.cidr_np_hub, local.cidr_np_qa])
  } : {
    hub  = compact([local.cidr_pr_hub, local.cidr_pr_prod, local.cidr_pr_uat])
    prod = compact([local.cidr_pr_hub, local.cidr_pr_prod])
    uat  = compact([local.cidr_pr_hub, local.cidr_pr_uat])
  }

  pe_rules_planemap = {
    for k, role in local._pe_role_by_key :
    k => {
      nsg_name = local.nsg_name_by_key[k]
      prefixes = lookup(local._lane_prefixes, role, [])
    }
  }

  pe_rules_allow_nonempty = {
    for k, v in local.pe_rules_planemap :
    k => v
    if length(v.prefixes) > 0 && v.nsg_name != null
  }

  lane_all_cidrs = compact(local.is_nonprod
    ? [local.cidr_np_hub, local.cidr_np_dev, local.cidr_np_qa]
    : [local.cidr_pr_hub, local.cidr_pr_prod, local.cidr_pr_uat]
  )

  pe_rules_deny_nonempty = {
    for k, v in local.pe_rules_allow_nonempty :
    k => {
      nsg_name      = v.nsg_name
      deny_prefixes = [for c in local.lane_all_cidrs : c if !contains(v.prefixes, c)]
    }
    if length([for c in local.lane_all_cidrs : c if !contains(v.prefixes, c)]) > 0
  }
}

resource "azurerm_network_security_rule" "pe_allow_lane_producers" {
  for_each                    = local.pe_rules_allow_nonempty
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value.nsg_name
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "pe_deny_other_vnets" {
  for_each                    = local.pe_rules_deny_nonempty
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value.nsg_name
  depends_on                  = [module.nsg]
}

# ── aks egress ────────────────────────────────────────────────────────────────
locals {
  aks_nsg_targets = {
    for k in local.nsg_keys :
    k => local.nsg_name_by_key[k]
    if can(regex("-(aks${var.product})$", k))
  }
}

resource "azurerm_network_security_rule" "aks_allow_https_internet" {
  for_each                    = local.aks_nsg_targets
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet" {
  for_each                    = local.aks_nsg_targets
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

resource "azurerm_network_security_rule" "aks_allow_acr" {
  for_each                    = local.aks_nsg_targets
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

# ── pe (cosmosdb for postgresql) – outbound baseline ──────────────────────────
locals {
  pe_cdbpg_keys    = [for k in local.nsg_keys : k if can(regex("privatelink-cdbpg$", k))]
  pe_cdbpg_targets = { for k in local.pe_cdbpg_keys : k => local.nsg_name_by_key[k] }
}

resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_egress" {
  for_each                    = local.pe_cdbpg_targets
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  network_security_group_name = each.value
  depends_on                  = [module.nsg]
}

# ── dns: private resolver ─────────────────────────────────────────────────────
locals {
  dnsr_name         = "pdnsr-${var.product}-${local.plane_code}-${var.region}-01"
  dnsr_hub_rg       = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  dnsr_hub_vnet_id  = module.vnet_hub.id
  dnsr_inbound_sid  = try(module.vnet_hub.subnet_ids["dns-inbound"], null)
  dnsr_outbound_sid = try(module.vnet_hub.subnet_ids["dns-outbound"], null)

  dnsr_ruleset_links = local.is_nonprod ? {
    dev = module.vnet_dev[0].id
    qa  = module.vnet_qa[0].id
  } : {
    prod = module.vnet_prod[0].id
    uat  = module.vnet_uat[0].id
  }

  dnsr_tags = merge(local.tag_base, { purpose = "dns-private-resolver", lane = local.lane })
}

module "dns_resolver" {
  count               = var.create_dns_resolver ? 1 : 0
  source              = "../../modules/dns-resolver"
  name                = local.dnsr_name
  location            = var.location
  resource_group_name = local.dnsr_hub_rg
  hub_vnet_id         = local.dnsr_hub_vnet_id
  inbound_subnet_id   = local.dnsr_inbound_sid
  outbound_subnet_id  = local.dnsr_outbound_sid
  inbound_static_ip   = var.dnsr_inbound_static_ip
  forwarding_rules    = var.dns_forwarding_rules
  vnet_links          = local.dnsr_ruleset_links
  tags                = local.dnsr_tags
  # implicit deps via VNet/Subnet IDs are sufficient
  depends_on = [module.vnet_hub]
}

# ── dns: public zones ─────────────────────────────────────────────────────────
locals {
  public_dns_zones_active = toset(var.public_dns_zones)
  public_dns_env          = local.is_nonprod ? "nonprod" : "prod"
}

resource "azurerm_dns_zone" "public" {
  for_each            = local.public_dns_zones_active
  name                = each.value
  resource_group_name = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  tags = merge(local.tag_base, {
    purpose     = "public-dns-zone"
    environment = local.public_dns_env
    lane        = local.public_dns_env
  })
  depends_on = [module.rg_hub]
}

############################################
# front door (shared-network rg)
############################################
locals {
  fd_is_nonprod    = local.lane == "nonprod"
  fd_profile_name  = "afd-${var.product}-${local.plane_code}-${var.region}-01"
  fd_endpoint_name = "fde-${var.product}-${local.plane_code}-${var.region}-01"

  fd_plane_overlay_tags = local.fd_is_nonprod ? {
    lane         = "nonprod"
    purpose      = "edge-frontdoor"
    criticality  = "medium"
    layer        = "shared-network"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  } : {
    lane         = "prod"
    purpose      = "edge-frontdoor"
    criticality  = "high"
    layer        = "shared-network"
    managed_by   = "terraform"
    deployed_via = "github-actions"
  }

  fd_tags = merge(
    var.tags,
    local.org_base_tags,
    local.fd_plane_overlay_tags,
    { service = "frontdoor", product = var.product }
  )
}

module "fd" {
  count               = var.fd_create_frontdoor ? 1 : 0
  source              = "../../modules/frontdoor-profile"
  resource_group_name = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  profile_name        = local.fd_profile_name
  endpoint_name       = local.fd_endpoint_name
  sku_name            = var.fd_sku_name
  tags                = local.fd_tags

  depends_on = [module.rg_hub]
}
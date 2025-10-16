# ── terraform & provider ───────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# ── globals ────────────────────────────────────────────────────────────────────
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
    # Storage (Commercial)
    "privatelink.blob.core.windows.net"       = "plb"
    "privatelink.file.core.windows.net"       = "plf"
    "privatelink.queue.core.windows.net"      = "plq"
    "privatelink.table.core.windows.net"      = "plt"
    "privatelink.vaultcore.azure.net"         = "kv"
    "privatelink.redis.cache.windows.net"     = "redis"
    "privatelink.documents.azure.com"         = "cosmos"
    "privatelink.postgres.database.azure.com" = "pg"
    "privatelink.postgres.cosmos.azure.com"   = "cpg"
    "privatelink.azurewebsites.net"           = "app"
    "privatelink.scm.azurewebsites.net"       = "scm"
    "privatelink.centralus.azmk8s.io"         = "azmk8scus"

    # Storage (Gov)
    "privatelink.blob.core.usgovcloudapi.net"   = "plb"
    "privatelink.file.core.usgovcloudapi.net"   = "plf"
    "privatelink.queue.core.usgovcloudapi.net"  = "plq"
    "privatelink.table.core.usgovcloudapi.net"  = "plt"
    "privatelink.dfs.core.usgovcloudapi.net"    = "pldfs"
    "privatelink.web.core.usgovcloudapi.net"    = "plweb"
    "privatelink.vaultcore.usgovcloudapi.net"   = "kv"
    "privatelink.redis.cache.usgovcloudapi.net" = "redis"
    "privatelink.documents.azure.us"            = "cosmos"
    "privatelink.postgres.database.usgovcloudapi.net" = "pg"
    "privatelink.postgres.cosmos.azure.us"            = "cpg"
    "privatelink.azurewebsites.us"              = "app"
    "scm.privatelink.azurewebsites.us"          = "scm"
    # AKS Gov private DNS zones vary by region; keep your actual region entries
    "privatelink.usgovvirginia.azmk8s.us"       = "azmk8svag"
    "privatelink.usgovarizona.azmk8s.us"        = "azmk8sazg"
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

  rg_specs = local.is_nonprod ? {
    nphub = {
      name = var.nonprod_hub.rg
      tags = merge(local.tag_base, local.plane_tags, { layer = local.rg_layer_by_key["nphub"] })
    }
    dev = {
      name = var.dev_spoke.rg
      tags = merge(local.tag_base, local.dev_only_tags, { layer = local.rg_layer_by_key["dev"] })
    }
    qa = {
      name = var.qa_spoke.rg
      tags = merge(local.tag_base, local.qa_only_tags, { layer = local.rg_layer_by_key["qa"] })
    }
  } : {
    prhub = {
      name = var.prod_hub.rg
      tags = merge(local.tag_base, local.plane_tags, { layer = local.rg_layer_by_key["prhub"] })
    }
    prod = {
      name = var.prod_spoke.rg
      tags = merge(local.tag_base, local.prod_only_tags, { layer = local.rg_layer_by_key["prod"] })
    }
    uat = {
      name = var.uat_spoke.rg
      tags = merge(local.tag_base, local.uat_only_tags, { layer = local.rg_layer_by_key["uat"] })
    }
  }

  hub_key     = local.is_nonprod ? "nphub" : "prhub"
  rg_dev_key  = "dev"
  rg_qa_key   = "qa"
  rg_prod_key = "prod"
  rg_uat_key  = "uat"
}

# ── resource groups ────────────────────────────────────────────────────────────
module "rg" {
  for_each = local.rg_specs
  source   = "../../modules/resource-group"
  name     = each.value.name
  location = var.location
  tags     = each.value.tags
}

# ── vnets (hub + spokes) ──────────────────────────────────────────────────────
locals {
  vnet_specs = local.is_nonprod ? {
    nphub = {
      name    = var.nonprod_hub.vnet
      rg      = var.nonprod_hub.rg
      cidrs   = var.nonprod_hub.cidrs
      subnets = var.nonprod_hub.subnets
      purpose = "shared-hub-connectivity"
      rg_key  = "nphub"
    }
    dev = {
      name    = var.dev_spoke.vnet
      rg      = var.dev_spoke.rg
      cidrs   = var.dev_spoke.cidrs
      subnets = var.dev_spoke.subnets
      purpose = "workload-spoke-dev"
      rg_key  = "dev"
    }
    qa = {
      name    = var.qa_spoke.vnet
      rg      = var.qa_spoke.rg
      cidrs   = var.qa_spoke.cidrs
      subnets = var.qa_spoke.subnets
      purpose = "workload-spoke-qa"
      rg_key  = "qa"
    }
  } : {
    prhub = {
      name    = var.prod_hub.vnet
      rg      = var.prod_hub.rg
      cidrs   = var.prod_hub.cidrs
      subnets = var.prod_hub.subnets
      purpose = "shared-hub-connectivity"
      rg_key  = "prhub"
    }
    prod = {
      name    = var.prod_spoke.vnet
      rg      = var.prod_spoke.rg
      cidrs   = var.prod_spoke.cidrs
      subnets = var.prod_spoke.subnets
      purpose = "workload-spoke-prod"
      rg_key  = "prod"
    }
    uat = {
      name    = var.uat_spoke.vnet
      rg      = var.uat_spoke.rg
      cidrs   = var.uat_spoke.cidrs
      subnets = var.uat_spoke.subnets
      purpose = "workload-spoke-uat"
      rg_key  = "uat"
    }
  }
}

module "vnet" {
  for_each            = local.vnet_specs
  source              = "../../modules/vnet"
  name                = each.value.name
  location            = var.location
  resource_group_name = each.value.rg
  address_space       = each.value.cidrs
  subnets             = each.value.subnets
  tags = merge(
    local.tag_base,
    { purpose = each.value.purpose },
    { layer = lookup(local.vnet_layer_by_key, each.key, "shared-network") }
  )
  depends_on = [module.rg]
}

# ── vnet peerings ──────────────────────────────────────────────────────────────
locals {
  peer_spokes = local.is_nonprod ? { dev = var.dev_spoke, qa = var.qa_spoke } : { prod = var.prod_spoke, uat = var.uat_spoke }
  peer_hub    = local.is_nonprod ? var.nonprod_hub : var.prod_hub

  peer_specs = {
    for sk, sv in local.peer_spokes :
    sk => {
      left_name                  = local.peer_hub.vnet
      left_rg                    = local.peer_hub.rg
      left_vnet_name             = local.peer_hub.vnet
      left_vnet_id               = module.vnet[local.hub_key].id
      right_name                 = sv.vnet
      right_rg                   = sv.rg
      right_vnet_name            = sv.vnet
      right_vnet_id              = module.vnet[sk].id
      left_allow_gateway_transit = true
      right_use_remote_gateways  = true
      left_to_right_name         = "peer-hub-to-${sk}"
      right_to_left_name         = "peer-${sk}-to-hub"
    }
  }
}

module "peering" {
  for_each = local.peer_specs
  source   = "../../modules/network/peering"

  left_rg        = each.value.left_rg
  left_vnet_name = each.value.left_vnet_name
  left_vnet_id   = each.value.left_vnet_id

  right_rg        = each.value.right_rg
  right_vnet_name = each.value.right_vnet_name
  right_vnet_id   = each.value.right_vnet_id

  left_allow_gateway_transit = try(each.value.left_allow_gateway_transit, false)
  right_use_remote_gateways  = try(each.value.right_use_remote_gateways, false)
  left_to_right_name         = try(each.value.left_to_right_name, null)
  right_to_left_name         = try(each.value.right_to_left_name, null)

  depends_on = [module.vnet, module.vpng]
}

# ── private dns (zones + links) ────────────────────────────────────────────────
# locals {
#   vnet_links_nonprod = local.is_nonprod ? flatten([
#     for z in var.private_zones : [
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-hub-${local.plane_code}", zone = z, vnet_id = module.vnet["nphub"].id },
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-spk-dev",              zone = z, vnet_id = module.vnet["dev"].id },
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-spk-qa",               zone = z, vnet_id = module.vnet["qa"].id }
#     ]
#   ]) : []

#   vnet_links_prod = local.is_prod ? flatten([
#     for z in var.private_zones : [
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-hub-${local.plane_code}", zone = z, vnet_id = module.vnet["prhub"].id },
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-spk-prod",               zone = z, vnet_id = module.vnet["prod"].id },
#       { name = "lnk-${lookup(local.short_zone_map, z, substr(replace(z, ".", "-"), 0, 16))}-spk-uat",                zone = z, vnet_id = module.vnet["uat"].id }
#     ]
#   ]) : []
# }

# nonprod
locals {
  vnet_links_nonprod = local.is_nonprod ? flatten([
    for z in var.private_zones : [
      { name = "lnk-${local.zone_token[z]}-hub-${local.plane_code}", zone = z, vnet_id = module.vnet["nphub"].id },
      { name = "lnk-${local.zone_token[z]}-spk-dev",                  zone = z, vnet_id = module.vnet["dev"].id },
      { name = "lnk-${local.zone_token[z]}-spk-qa",                   zone = z, vnet_id = module.vnet["qa"].id }
    ]
  ]) : []

  # prod
  vnet_links_prod = local.is_prod ? flatten([
    for z in var.private_zones : [
      { name = "lnk-${local.zone_token[z]}-hub-${local.plane_code}", zone = z, vnet_id = module.vnet["prhub"].id },
      { name = "lnk-${local.zone_token[z]}-spk-prod",                zone = z, vnet_id = module.vnet["prod"].id },
      { name = "lnk-${local.zone_token[z]}-spk-uat",                 zone = z, vnet_id = module.vnet["uat"].id }
    ]
  ]) : []
}

module "pdns" {
  source              = "../../modules/private-dns"
  resource_group_name = var.shared_network_rg
  zones               = var.private_zones
  vnet_links          = concat(local.vnet_links_nonprod, local.vnet_links_prod)
  tags                = merge(local.tag_base, { purpose = "private-dns" })
  depends_on          = [module.vnet]
}

# ── connectivity: vpn gateway ──────────────────────────────────────────────────
locals {
  create_vpng_effective  = var.create_vpn_gateway
  vpng_hub_rg            = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  vpng_gateway_subnet_id = try(module.vnet[local.hub_key].subnet_ids["GatewaySubnet"], null)

  # create a standalone PIP only when the module is NOT creating it
  create_external_vpng_pip = local.create_vpng_effective && !var.create_vpng_public_ip
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
  depends_on = [module.rg, module.vnet]
}

module "vpng" {
  count               = local.create_vpng_effective ? 1 : 0
  source              = "../../modules/vpn-gateway"
  name                = local.name_vpng
  location            = var.location
  resource_group_name = local.vpng_hub_rg
  sku                 = var.vpn_sku

  # if module is creating PIP, do not pass an external ip id
  create_public_ip    = var.create_vpng_public_ip
  public_ip_id        = local.create_external_vpng_pip ? azurerm_public_ip.vpngw[0].id : null

  gateway_subnet_id   = local.vpng_gateway_subnet_id
  tenant_id           = var.tenant_id
  tags = merge(local.tag_base, {
    purpose = "p2s-vpn-gateway"
    service = "connectivity"
    lane    = local.lane
  })
  depends_on = [module.vnet]
}

# ── ingress: waf & appgw ──────────────────────────────────────────────────────
locals {
  appgw_hub_rg     = local.is_nonprod ? var.nonprod_hub.rg : var.prod_hub.rg
  has_appgw_subnet = local.is_nonprod ? contains(keys(var.nonprod_hub.subnets), "appgw") : contains(keys(var.prod_hub.subnets), "appgw")

  # require the actual subnet ID to exist to avoid partial creation
  appgw_subnet_id  = try(module.vnet[local.hub_key].subnet_ids["appgw"], null)
  appgw_enabled    = var.create_app_gateway && local.has_appgw_subnet && local.appgw_subnet_id != null
}

module "waf" {
  count               = local.appgw_enabled ? 1 : 0
  source              = "../../modules/waf-policy"
  name                = local.name_wafp
  location            = var.location
  resource_group_name = local.appgw_hub_rg
  mode                = var.waf_mode
  tags = merge(local.tag_base, {
    purpose = "app-gateway-waf-policy"
    service = "ingress"
    lane    = local.lane
  })
  depends_on = [module.rg]
}

resource "azurerm_network_security_group" "appgw_nsg" {
  count               = local.appgw_enabled ? 1 : 0
  name                = local.name_appgw_nsg
  location            = var.location
  resource_group_name = local.appgw_hub_rg
  tags = merge(local.tag_base, {
    purpose = "app-gateway-subnet-nsg"
    lane    = local.lane
  })
  depends_on = [module.rg, module.vnet]
}

resource "azurerm_network_security_rule" "appgw_allow_alb" {
  count                       = length(azurerm_network_security_group.appgw_nsg)
  name                        = "allow-azurelb-probes"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_inbound_snat" {
  count                       = length(azurerm_network_security_group.appgw_nsg)
  name                        = "allow-appgw-inbound-snat"
  priority                    = 3900
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
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
    azurerm_network_security_rule.appgw_allow_inbound_snat,
    module.vnet
  ]
}

resource "azurerm_network_security_rule" "appgw_deny_other_internet" {
  count                       = length(azurerm_network_security_group.appgw_nsg)
  name                        = "deny-other-internet"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
  depends_on                  = [azurerm_subnet_network_security_group_association.appgw_assoc]
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
  tags = merge(local.tag_base, {
    purpose = "app-gateway-waf"
    service = "ingress"
    lane    = local.lane
  })
  depends_on = [azurerm_subnet_network_security_group_association.appgw_assoc]
}

# ── generic nsgs (except excluded) ─────────────────────────────────────────────
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

  # fixed to match new prefixes: hub-/dev-/qa-/prod-/uat-
  subnet_id_by_key = {
    for k in local.nsg_keys :
    k => (
      can(regex("^hub-",  k)) ? try(module.vnet[local.hub_key].subnet_ids[replace(k, "hub-",  "")], null) :
      can(regex("^dev-",  k)) ? try(module.vnet["dev"].subnet_ids[replace(k, "dev-",  "")], null) :
      can(regex("^qa-",   k)) ? try(module.vnet["qa"].subnet_ids[replace(k, "qa-",   "")], null) :
      can(regex("^prod-", k)) ? try(module.vnet["prod"].subnet_ids[replace(k, "prod-", "")], null) :
      can(regex("^uat-",  k)) ? try(module.vnet["uat"].subnet_ids[replace(k, "uat-",  "")], null) :
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
  tags = merge(local.tag_base, { lane = local.lane })
  depends_on = [module.vnet, module.rg]
}

# ── nsg rules: isolation & baseline ────────────────────────────────────────────
locals {
  all_plane_nsg_targets = {
    for k in local.nsg_keys :
    k => local.nsg_name_by_key[k]
    if !can(regex("privatelink", k)) && !can(regex("-appgw$", k))
  }

  # fixed to use new prefixes
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

# ── baseline egress on workload nsgs ───────────────────────────────────────────
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

# ── pep rules (pe allow/deny) ─────────────────────────────────────────────────
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
  dnsr_hub_vnet_id  = module.vnet[local.hub_key].id
  dnsr_inbound_sid  = try(module.vnet[local.hub_key].subnet_ids["dns-inbound"], null)
  dnsr_outbound_sid = try(module.vnet[local.hub_key].subnet_ids["dns-outbound"], null)

  dnsr_ruleset_links = local.is_nonprod ? {
    dev = module.vnet["dev"].id
    qa  = module.vnet["qa"].id
  } : {
    prod = module.vnet["prod"].id
    uat  = module.vnet["uat"].id
  }

  dnsr_tags = merge(local.tag_base, {
    purpose = "dns-private-resolver"
    lane    = local.lane
  })
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
  depends_on = [
    module.vnet,
    module.rg,
    module.vpng,
    module.appgw,
    module.nsg
  ]
}

# ── dns: public zones ─────────────────────────────────────────────────────────
locals {
  public_dns_zones_active = toset(var.public_dns_zones)
  public_dns_env          = local.is_nonprod ? "nonprod" : "prod"
}

resource "azurerm_dns_zone" "public" {
  for_each            = local.public_dns_zones_active
  name                = each.value
  resource_group_name = var.shared_network_rg
  tags = merge(local.tag_base, {
    purpose     = "public-dns-zone"
    environment = local.public_dns_env
    lane        = local.public_dns_env
  })
  depends_on = [module.dns_resolver]
}
# terraform & providers
terraform {
  required_version = ">= 1.6.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
  }
}

# Per-env subscription/tenant fallbacks (prefer explicit IDs, else hub)
locals {
  dev_sub  = (var.dev_subscription_id  != null && trimspace(var.dev_subscription_id)  != "") ? var.dev_subscription_id  : var.hub_subscription_id
  dev_ten  = (var.dev_tenant_id        != null && trimspace(var.dev_tenant_id)        != "") ? var.dev_tenant_id        : var.hub_tenant_id

  qa_sub   = (var.qa_subscription_id   != null && trimspace(var.qa_subscription_id)   != "") ? var.qa_subscription_id   : var.hub_subscription_id
  qa_ten   = (var.qa_tenant_id         != null && trimspace(var.qa_tenant_id)         != "") ? var.qa_tenant_id         : var.hub_tenant_id

  uat_sub  = (var.uat_subscription_id  != null && trimspace(var.uat_subscription_id)  != "") ? var.uat_subscription_id  : var.hub_subscription_id
  uat_ten  = (var.uat_tenant_id        != null && trimspace(var.uat_tenant_id)        != "") ? var.uat_tenant_id        : var.hub_tenant_id

  prod_sub = (var.prod_subscription_id != null && trimspace(var.prod_subscription_id) != "") ? var.prod_subscription_id : var.hub_subscription_id
  prod_ten = (var.prod_tenant_id       != null && trimspace(var.prod_tenant_id)       != "") ? var.prod_tenant_id       : var.hub_tenant_id
}

# Default = HUB subscription
provider "azurerm" {
  features {}
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# Per-env aliases (each can be pointed to distinct subs/tenants)
provider "azurerm" {
  alias    = "dev"
  features {}
  subscription_id = local.dev_sub
  tenant_id       = local.dev_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias    = "qa"
  features {}
  subscription_id = local.qa_sub
  tenant_id       = local.qa_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias    = "uat"
  features {}
  subscription_id = local.uat_sub
  tenant_id       = local.uat_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}
provider "azurerm" {
  alias    = "prod"
  features {}
  subscription_id = local.prod_sub
  tenant_id       = local.prod_ten
  environment     = var.product == "hrz" ? "usgovernment" : "public"
}

# globals
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

  # Org / global base tags (4)
  org_base_tags = {
    product      = var.product
    owner        = "itops-team"
    businessunit = "public-safety"
    compliance   = "cjis"
  }

  # Plane-level tags (2) – note: no criticality here to keep total tag count low
  plane_tags = local.is_nonprod ? {
    lane    = "nonprod"
    purpose = "shared-nonprod"
  } : {
    lane    = "prod"
    purpose = "shared-prod"
  }

  # Shared/network base tags (2)
  base_layer_tags = {
    layer      = "shared-network"
    managed_by = "terraform"
  }

  # FedRAMP common tags (2) – kept minimal but still provide boundary + impact level
  fedramp_common_tags = {
    fedramp_boundary     = "network"
    fedramp_impact_level = "moderate"
  }

  # consolidated base for most tags (var.tags + org + layer)
  tag_base = merge(var.tags, local.org_base_tags, local.base_layer_tags)

  # Env-only tags (4 each). Combined with tag_base (6), plane_tags (2) and
  # fedramp_common_tags (2) gives 14 total keys from our side.
  dev_only_tags = {
    environment         = "dev"
    patchgroup          = "Test"
    environment_stage   = "non-production"
    data_classification = "internal"
  }

  qa_only_tags = {
    environment         = "qa"
    patchgroup          = "Test"
    environment_stage   = "non-production"
    data_classification = "internal"
  }

  uat_only_tags = {
    environment         = "uat"
    patchgroup          = "Monthly"
    environment_stage   = "pre-production"
    data_classification = "internal"
  }

  prod_only_tags = {
    environment         = "prod"
    patchgroup          = "Monthly"
    environment_stage   = "production"
    data_classification = "restricted"
  }

  short_zone_map = {
    # Commercial
    "privatelink.blob.core.windows.net"       = "plb"
    "privatelink.file.core.windows.net"       = "plf"
    "privatelink.queue.core.windows.net"      = "plq"
    "privatelink.table.core.windows.net"      = "plt"
    "privatelink.dfs.core.windows.net"        = "pldfs"
    "privatelink.web.core.windows.net"        = "plweb"
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

locals {
  # canonical RG names (overrideable via vars if set)
  hub_rg_name = local.is_nonprod ? coalesce(try(var.nonprod_hub.rg, null), "rg-${var.product}-${local.plane_code}-${var.region}-net-01") : coalesce(try(var.prod_hub.rg,    null), "rg-${var.product}-${local.plane_code}-${var.region}-net-01")
  dev_rg_name  = local.is_nonprod ? coalesce(try(var.dev_spoke.rg,  null), "rg-${var.product}-dev-${var.region}-net-01")  : null
  qa_rg_name   = local.is_nonprod ? coalesce(try(var.qa_spoke.rg,   null), "rg-${var.product}-qa-${var.region}-net-01")   : null
  prod_rg_name = local.is_prod    ? coalesce(try(var.prod_spoke.rg, null), "rg-${var.product}-prod-${var.region}-net-01") : null
  uat_rg_name  = local.is_prod    ? coalesce(try(var.uat_spoke.rg,  null), "rg-${var.product}-uat-${var.region}-net-01")  : null

  dev_rg_name_core  = local.is_nonprod ? coalesce(try(var.dev_spoke.rg,  null), "rg-${var.product}-dev-${var.region}-core-01")  : null
  qa_rg_name_core   = local.is_nonprod ? coalesce(try(var.qa_spoke.rg,   null), "rg-${var.product}-qa-${var.region}-core-01")   : null
  prod_rg_name_core = local.is_prod    ? coalesce(try(var.prod_spoke.rg, null), "rg-${var.product}-prod-${var.region}-core-01") : null
  uat_rg_name_core  = local.is_prod    ? coalesce(try(var.uat_spoke.rg,  null), "rg-${var.product}-uat-${var.region}-core-01")  : null

  # canonical VNet names (overrideable via vars if set)
  hub_vnet_name  = local.is_nonprod ? coalesce(try(var.nonprod_hub.vnet, null), "vnet-${var.product}-${local.plane_code}-hub-${var.region}-${var.seq}") : coalesce(try(var.prod_hub.vnet,    null), "vnet-${var.product}-${local.plane_code}-hub-${var.region}-${var.seq}")
  dev_vnet_name  = local.is_nonprod ? coalesce(try(var.dev_spoke.vnet,  null), "vnet-${var.product}-dev-${var.region}-${var.seq}")  : null
  qa_vnet_name   = local.is_nonprod ? coalesce(try(var.qa_spoke.vnet,   null), "vnet-${var.product}-qa-${var.region}-${var.seq}")   : null
  prod_vnet_name = local.is_prod    ? coalesce(try(var.prod_spoke.vnet, null), "vnet-${var.product}-prod-${var.region}-${var.seq}") : null
  uat_vnet_name  = local.is_prod    ? coalesce(try(var.uat_spoke.vnet,  null), "vnet-${var.product}-uat-${var.region}-${var.seq}")  : null

  # helper maps by environment key
  rg_by_env = {
    hub  = local.hub_rg_name
    dev  = local.dev_rg_name
    qa   = local.qa_rg_name
    prod = local.prod_rg_name
    uat  = local.uat_rg_name
  }

  vnet_by_env = {
    hub  = local.hub_vnet_name
    dev  = local.dev_vnet_name
    qa   = local.qa_vnet_name
    prod = local.prod_vnet_name
    uat  = local.uat_vnet_name
  }
}

# resource groups (per-env with proper provider)
module "rg_hub" {
  source   = "../../modules/resource-group"
  name     = local.hub_rg_name
  location = var.location

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane
    local.fedramp_common_tags, # shared FedRAMP metadata
    {
      layer = local.is_nonprod ? local.rg_layer_by_key["nphub"] : local.rg_layer_by_key["prhub"]
    }
  )
}

module "rg_dev" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.dev }
  source    = "../../modules/resource-group"
  name      = local.dev_rg_name
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.dev_only_tags,
    { layer = local.rg_layer_by_key["dev"] }
  )
}

module "rg_dev_core" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.dev }
  source    = "../../modules/resource-group"
  name      = local.dev_rg_name_core
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.dev_only_tags,
    { layer = local.rg_layer_by_key["dev"] }
  )
}

module "rg_qa" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.qa }
  source    = "../../modules/resource-group"
  name      = local.qa_rg_name
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.qa_only_tags,
    { layer = local.rg_layer_by_key["qa"] }
  )
}

module "rg_qa_core" {
  count     = local.is_nonprod ? 1 : 0
  providers = { azurerm = azurerm.qa }
  source    = "../../modules/resource-group"
  name      = local.qa_rg_name_core
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.qa_only_tags,
    { layer = local.rg_layer_by_key["qa"] }
  )
}

module "rg_prod" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.prod }
  source    = "../../modules/resource-group"
  name      = local.prod_rg_name
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.prod_only_tags,
    { layer = local.rg_layer_by_key["prod"] }
  )
}

module "rg_prod_core" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.prod }
  source    = "../../modules/resource-group"
  name      = local.prod_rg_name_core
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.prod_only_tags,
    { layer = local.rg_layer_by_key["prod"] }
  )
}

module "rg_uat" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.uat }
  source    = "../../modules/resource-group"
  name      = local.uat_rg_name
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.uat_only_tags,
    { layer = local.rg_layer_by_key["uat"] }
  )
}

module "rg_uat_core" {
  count     = local.is_prod ? 1 : 0
  providers = { azurerm = azurerm.uat }
  source    = "../../modules/resource-group"
  name      = local.uat_rg_name_core
  location  = var.location

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.uat_only_tags,
    { layer = local.rg_layer_by_key["uat"] }
  )
}

# vnets (per-env with proper provider)
module "vnet_hub" {
  source              = "../../modules/vnet"
  name                = local.hub_vnet_name
  resource_group_name = local.hub_rg_name
  location            = var.location
  address_space       = (local.is_nonprod ? var.nonprod_hub : var.prod_hub).cidrs
  subnets             = (local.is_nonprod ? var.nonprod_hub : var.prod_hub).subnets

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    {
      purpose = "shared-hub-connectivity"
      layer   = local.is_nonprod ? local.vnet_layer_by_key["nphub"] : local.vnet_layer_by_key["prhub"]
    }
  )

  depends_on          = [module.rg_hub]
}

module "vnet_dev" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.dev }
  source              = "../../modules/vnet"
  name                = local.dev_vnet_name
  resource_group_name = local.dev_rg_name
  location            = var.location
  address_space       = var.dev_spoke.cidrs
  subnets             = var.dev_spoke.subnets

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.dev_only_tags,
    { layer = local.vnet_layer_by_key["dev"] }
  )

  depends_on          = [module.rg_dev]
}

module "vnet_qa" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.qa }
  source              = "../../modules/vnet"
  name                = local.qa_vnet_name
  resource_group_name = local.qa_rg_name
  location            = var.location
  address_space       = var.qa_spoke.cidrs
  subnets             = var.qa_spoke.subnets

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.qa_only_tags,
    { layer = local.vnet_layer_by_key["qa"] }
  )

  depends_on          = [module.rg_qa]
}

module "vnet_prod" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.prod }
  source              = "../../modules/vnet"
  name                = local.prod_vnet_name
  resource_group_name = local.prod_rg_name
  location            = var.location
  address_space       = var.prod_spoke.cidrs
  subnets             = var.prod_spoke.subnets

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.prod_only_tags,
    { layer = local.vnet_layer_by_key["prod"] }
  )

  depends_on          = [module.rg_prod]
}

module "vnet_uat" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.uat }
  source              = "../../modules/vnet"
  # name                = var.uat_spoke.vnet
  # resource_group_name = local.uat_rg_name
  name                = local.uat_vnet_name
  resource_group_name = local.uat_rg_name
  location            = var.location
  address_space       = var.uat_spoke.cidrs
  subnets             = var.uat_spoke.subnets

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.uat_only_tags,
    { layer = local.vnet_layer_by_key["uat"] }
  )

  depends_on          = [module.rg_uat]
}

# vnet peerings (ensure VPN GW first for transit)
resource "azurerm_virtual_network_peering" "hub_to_dev" {
  count                         = local.is_nonprod ? 1 : 0
  name                          = "peer-hub-to-dev"
  resource_group_name           = local.hub_rg_name
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_dev[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng]
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  count                         = local.is_nonprod ? 1 : 0
  provider                      = azurerm.dev
  name                          = "peer-dev-to-hub"
  resource_group_name           = local.dev_rg_name
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
  resource_group_name           = local.hub_rg_name
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_qa[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng]
}

resource "azurerm_virtual_network_peering" "qa_to_hub" {
  count                         = local.is_nonprod ? 1 : 0
  provider                      = azurerm.qa
  name                          = "peer-qa-to-hub"
  resource_group_name           = local.qa_rg_name
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
  resource_group_name           = local.hub_rg_name
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_prod[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng]
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  count                         = local.is_prod ? 1 : 0
  provider                      = azurerm.prod
  name                          = "peer-prod-to-hub"
  resource_group_name           = local.prod_rg_name
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
  resource_group_name           = local.hub_rg_name
  virtual_network_name          = module.vnet_hub.name
  remote_virtual_network_id     = module.vnet_uat[0].id
  allow_gateway_transit         = true
  allow_forwarded_traffic       = true
  use_remote_gateways           = false
  depends_on                    = [module.vpng]
}

resource "azurerm_virtual_network_peering" "uat_to_hub" {
  count                         = local.is_prod ? 1 : 0
  provider                      = azurerm.uat
  name                          = "peer-uat-to-hub"
  resource_group_name           = local.uat_rg_name
  virtual_network_name          = module.vnet_uat[0].name
  remote_virtual_network_id     = module.vnet_hub.id
  allow_gateway_transit         = false
  allow_forwarded_traffic       = true
  use_remote_gateways           = true
  depends_on                    = [azurerm_virtual_network_peering.hub_to_uat]
}

# private dns (zones + links)
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
  resource_group_name = local.hub_rg_name
  zones               = var.private_zones
  vnet_links          = local.vnet_links

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane for the hub
    local.fedramp_common_tags, # shared FedRAMP / boundary metadata
    {
      purpose = "private-dns"
    }
  )

  depends_on = [
    module.rg_hub,
    module.vnet_hub,
    module.vnet_dev,
    module.vnet_qa,
    module.vnet_prod,
    module.vnet_uat,
    module.vpng
  ]
}

# connectivity: vpn gateway
locals {
  create_vpng_effective     = var.create_vpn_gateway
  vpng_hub_rg               = local.hub_rg_name
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
  depends_on = [module.rg_hub]
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
  azure_environment   = var.product == "hrz" ? "usgovernment" : "public"

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod hub plane
    local.fedramp_common_tags, # shared FedRAMP/boundary metadata
    {
      purpose = "p2s-vpn-gateway"
      service = "connectivity"
      lane    = local.lane      # keep existing lane behavior
    }
  )

  depends_on = [
    module.vnet_hub,
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# ingress: waf & appgw
locals {
  appgw_hub_rg     = local.hub_rg_name
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

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane for this hub
    local.fedramp_common_tags, # shared FedRAMP/boundary metadata
    {
      purpose = "app-gateway-waf-policy"
      service = "ingress"
      lane    = local.lane
    }
  )

  depends_on = [
    module.rg_hub,
    module.vnet_hub
  ]
}

resource "azurerm_network_security_group" "appgw_nsg" {
  count               = local.appgw_enabled ? 1 : 0
  name                = local.name_appgw_nsg
  location            = var.location
  resource_group_name = local.appgw_hub_rg

  tags = merge(
    local.tag_base,
    local.plane_tags,
    local.fedramp_common_tags,
    {
      purpose = "app-gateway-subnet-nsg"
      lane    = local.lane
    }
  )

  depends_on = [
    module.rg_hub,
    module.vnet_hub
  ]
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

resource "azurerm_network_security_rule" "appgw_allow_https_public" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
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
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
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
    azurerm_network_security_rule.appgw_allow_gwmgr,
    azurerm_network_security_rule.appgw_allow_http_public,
    azurerm_network_security_rule.appgw_allow_https_public
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

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane
    local.fedramp_common_tags, # shared FedRAMP/boundary metadata
    {
      purpose = "app-gateway-waf"
      service = "ingress"
      lane    = local.lane
    }
  )

  depends_on = [
    azurerm_subnet_network_security_group_association.appgw_assoc
  ]
}

# generic nsgs (except excluded)
locals {
  _np_hub_subnet_names  = local.is_nonprod ? keys(var.nonprod_hub.subnets) : []
  _np_dev_subnet_names  = local.is_nonprod ? keys(var.dev_spoke.subnets)   : []
  _np_qa_subnet_names   = local.is_nonprod ? keys(var.qa_spoke.subnets)    : []

  _pr_hub_subnet_names  = local.is_prod ? keys(var.prod_hub.subnets)  : []
  _pr_prod_subnet_names = local.is_prod ? keys(var.prod_spoke.subnets) : []
  _pr_uat_subnet_names  = local.is_prod ? keys(var.uat_spoke.subnets)  : []

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

  # Which RG each NSG lives in (same sub/RG as the target subnet/vnet)
  nsg_rg_by_key = {
    for k in local.nsg_keys :
    k => (
      can(regex("^hub-",  k)) ? local.hub_rg_name  :
      can(regex("^dev-",  k)) ? local.dev_rg_name  :
      can(regex("^qa-",   k)) ? local.qa_rg_name   :
      can(regex("^prod-", k)) ? local.prod_rg_name :
      can(regex("^uat-",  k)) ? local.uat_rg_name  :
      local.hub_rg_name
    )
  }

  # NSG inputs for module(s)
  subnet_nsgs_all = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], subnet_id = local.subnet_id_by_key[k] }
  }

  nsgs_hub  = { for k, v in local.subnet_nsgs_all : k => v if can(regex("^hub-",  k)) }
  nsgs_dev  = { for k, v in local.subnet_nsgs_all : k => v if can(regex("^dev-",  k)) }
  nsgs_qa   = { for k, v in local.subnet_nsgs_all : k => v if can(regex("^qa-",   k)) }
  nsgs_prod = { for k, v in local.subnet_nsgs_all : k => v if can(regex("^prod-", k)) }
  nsgs_uat  = { for k, v in local.subnet_nsgs_all : k => v if can(regex("^uat-",  k)) }
}

# Create NSGs per subscription (so associations are sub-local)
module "nsg_hub" {
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.hub_rg_name
  subnet_nsgs         = local.nsgs_hub

  tags = merge(
    local.tag_base,
    local.plane_tags,          # e.g. nonprod / prod plane
    local.fedramp_common_tags  # shared FedRAMP metadata (boundary, impact, etc.)
  )

  depends_on          = [module.vnet_hub]
}

module "nsg_dev" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.dev }
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.dev_rg_name
  subnet_nsgs         = local.nsgs_dev

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.dev_only_tags        # includes env = dev, purpose, criticality, lane, + FedRAMP fields
  )

  depends_on          = [module.vnet_dev]
}

module "nsg_qa" {
  count               = local.is_nonprod ? 1 : 0
  providers           = { azurerm = azurerm.qa }
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.qa_rg_name
  subnet_nsgs         = local.nsgs_qa

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.qa_only_tags
  )

  depends_on          = [module.vnet_qa]
}

module "nsg_prod" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.prod }
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.prod_rg_name
  subnet_nsgs         = local.nsgs_prod

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.prod_only_tags
  )

  depends_on          = [module.vnet_prod]
}

module "nsg_uat" {
  count               = local.is_prod ? 1 : 0
  providers           = { azurerm = azurerm.uat }
  source              = "../../modules/network/nsg"
  location            = var.location
  resource_group_name = local.uat_rg_name
  subnet_nsgs         = local.nsgs_uat

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.uat_only_tags
  )

  depends_on          = [module.vnet_uat]
}

# nsg rules: isolation & baseline (provider-correct per subscription) ───────
locals {
  # Existing struct maps from earlier locals (unchanged)
  all_plane_nsg_targets_struct = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] }
    if !can(regex("privatelink", k)) && !can(regex("-appgw$", k))
  }

  dev_nsg_targets_np_struct  = local.is_nonprod ? {
    for k in local.nsg_keys : k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] } if can(regex("^dev-",  k))
  } : {}

  qa_nsg_targets_np_struct   = local.is_nonprod ? {
    for k in local.nsg_keys : k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] } if can(regex("^qa-",   k))
  } : {}

  prod_nsg_targets_pr_struct = local.is_prod ? {
    for k in local.nsg_keys : k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] } if can(regex("^prod-", k))
  } : {}

  uat_nsg_targets_pr_struct  = local.is_prod ? {
    for k in local.nsg_keys : k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] } if can(regex("^uat-",  k))
  } : {}

  dev_vnet_cidr  = local.is_nonprod ? lookup(var.dev_spoke,  "cidrs", ["0.0.0.0/32"])[0] : null
  qa_vnet_cidr   = local.is_nonprod ? lookup(var.qa_spoke,   "cidrs", ["0.0.0.0/32"])[0] : null
  prod_vnet_cidr = local.is_prod    ? lookup(var.prod_spoke, "cidrs", ["0.0.0.0/32"])[0] : null
  uat_vnet_cidr  = local.is_prod    ? lookup(var.uat_spoke,  "cidrs", ["0.0.0.0/32"])[0] : null

  # Split generic targets by subscription (so each resource can use a fixed provider)
  all_targets_hub  = { for k, v in local.all_plane_nsg_targets_struct : k => v if can(regex("^hub-",  k)) }
  all_targets_dev  = { for k, v in local.all_plane_nsg_targets_struct : k => v if can(regex("^dev-",  k)) }
  all_targets_qa   = { for k, v in local.all_plane_nsg_targets_struct : k => v if can(regex("^qa-",   k)) }
  all_targets_prod = { for k, v in local.all_plane_nsg_targets_struct : k => v if can(regex("^prod-", k)) }
  all_targets_uat  = { for k, v in local.all_plane_nsg_targets_struct : k => v if can(regex("^uat-",  k)) }

  # workload (non-PE) NSGs for baseline egress rules
  _workload_pairs = {
    for k in local.nsg_keys :
    k => {
      nsg_name    = local.nsg_name_by_key[k]
      nsg_rg      = local.nsg_rg_by_key[k]
      subnet_key  = k
      subnet_name = element(split("-", k), length(split("-", k)) - 1)
    }
  }

  workload_targets_all = {
    for k, v in local._workload_pairs :
    k => { name = v.nsg_name, rg = v.nsg_rg }
    if !contains(var.nsg_exclude_subnets, v.subnet_name) && !can(regex("privatelink", k))
  }

  workload_targets_hub  = { for k, v in local.workload_targets_all : k => v if can(regex("^hub-",  k)) }
  workload_targets_dev  = { for k, v in local.workload_targets_all : k => v if can(regex("^dev-",  k)) }
  workload_targets_qa   = { for k, v in local.workload_targets_all : k => v if can(regex("^qa-",   k)) }
  workload_targets_prod = { for k, v in local.workload_targets_all : k => v if can(regex("^prod-", k)) }
  workload_targets_uat  = { for k, v in local.workload_targets_all : k => v if can(regex("^uat-",  k)) }

  # PE subnet NSGs
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
      nsg_rg   = local.nsg_rg_by_key[k]
      prefixes = lookup(local._lane_prefixes, role, [])
    }
  }

  pe_rules_allow_nonempty = {
    for k, v in local.pe_rules_planemap :
    k => v if length(v.prefixes) > 0 && v.nsg_name != null
  }

  lane_all_cidrs = compact(local.is_nonprod
    ? [local.cidr_np_hub, local.cidr_np_dev, local.cidr_np_qa]
    : [local.cidr_pr_hub, local.cidr_pr_prod, local.cidr_pr_uat]
  )

  pe_rules_deny_nonempty = {
    for k, v in local.pe_rules_allow_nonempty :
    k => {
      nsg_name      = v.nsg_name
      nsg_rg        = v.nsg_rg
      deny_prefixes = [for c in local.lane_all_cidrs : c if !contains(v.prefixes, c)]
    }
    if length([for c in local.lane_all_cidrs : c if !contains(v.prefixes, c)]) > 0
  }

  pe_allow_hub  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^hub-",  k)) }
  pe_allow_dev  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^dev-",  k)) }
  pe_allow_qa   = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^qa-",   k)) }
  pe_allow_prod = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^prod-", k)) }
  pe_allow_uat  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^uat-",  k)) }

  pe_deny_hub  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^hub-",  k)) }
  pe_deny_dev  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^dev-",  k)) }
  pe_deny_qa   = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^qa-",   k)) }
  pe_deny_prod = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^prod-", k)) }
  pe_deny_uat  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^uat-",  k)) }

  # AKS egress targets (pods/aks subnets)
  aks_nsg_targets_struct = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] }
    if can(regex("-(aks${var.product})$", k))
  }
  aks_targets_hub  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^hub-",  k)) }
  aks_targets_dev  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^dev-",  k)) }
  aks_targets_qa   = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^qa-",   k)) }
  aks_targets_prod = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^prod-", k)) }
  aks_targets_uat  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^uat-",  k)) }

  # CosmosDB for PostgreSQL private endpoints (privatelink-cdbpg)
  pe_cdbpg_targets_struct = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] }
    if can(regex("privatelink-cdbpg$", k))
  }
  pe_cdbpg_hub  = { for k, v in local.pe_cdbpg_targets_struct : k => v if can(regex("^hub-",  k)) }
  pe_cdbpg_dev  = { for k, v in local.pe_cdbpg_targets_struct : k => v if can(regex("^dev-",  k)) }
  pe_cdbpg_qa   = { for k, v in local.pe_cdbpg_targets_struct : k => v if can(regex("^qa-",   k)) }
  pe_cdbpg_prod = { for k, v in local.pe_cdbpg_targets_struct : k => v if can(regex("^prod-", k)) }
  pe_cdbpg_uat  = { for k, v in local.pe_cdbpg_targets_struct : k => v if can(regex("^uat-",  k)) }


    # GitHub Actions runners: only NSGs for subnets named exactly "internal"
  ghrunner_targets_all = {
    for k, v in local._workload_pairs :
    k => { name = v.nsg_name, rg = v.nsg_rg }
    if v.subnet_name == "internal"
  }

  ghrunner_targets_hub  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^hub-",  k)) }
  # ghrunner_targets_dev  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^dev-",  k)) }
  # ghrunner_targets_qa   = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^qa-",   k)) }
  # ghrunner_targets_prod = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^prod-", k)) }
  # ghrunner_targets_uat  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^uat-",  k)) }
}

# GitHub Actions runner egress

locals {
  # HRZ keeps the real runner egress; PUB uses fixed 1.1.1.1
  ghrunner_egress_ip = lower(var.product) == "pub" ? "172.10.13.10" : "10.10.13.10"
}

resource "azurerm_network_security_rule" "allow_ghrunner_https_internet_hub" {
  for_each                    = local.ghrunner_targets_hub
  name                        = "allow-ghrunner-https-internet"
  priority                    = 360
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = local.ghrunner_egress_ip
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ghrunner_http_internet_hub" {
  for_each                    = local.ghrunner_targets_hub
  name                        = "allow-ghrunner-http-internet"
  priority                    = 365
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = local.ghrunner_egress_ip
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
# ---------- DENY All Inbound ----------
# resource "azurerm_network_security_rule" "baseline_deny_inbound_hub" {
#   for_each = {
#     for k, v in local.all_targets_hub :
#     k => v
#     if !can(regex("dns-inbound", lower(v.name)))
#   }

#   name                        = "deny-all-inbound"
#   priority                    = 4096
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
# }

# resource "azurerm_network_security_rule" "baseline_deny_inbound_dev" {
#   provider = azurerm.dev
#   for_each = {
#     for k, v in local.all_targets_dev :
#     k => v
#     if !can(regex("dns-inbound", lower(v.name)))
#   }

#   name                        = "deny-all-inbound"
#   priority                    = 4096
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
# }

# resource "azurerm_network_security_rule" "baseline_deny_inbound_qa" {
#   provider = azurerm.qa
#   for_each = {
#     for k, v in local.all_targets_qa :
#     k => v
#     if !can(regex("dns-inbound", lower(v.name)))
#   }

#   name                        = "deny-all-inbound"
#   priority                    = 4096
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
# }

# resource "azurerm_network_security_rule" "baseline_deny_inbound_prod" {
#   provider = azurerm.prod
#   for_each = {
#     for k, v in local.all_targets_prod :
#     k => v
#     if !can(regex("dns-inbound", lower(v.name)))
#   }

#   name                        = "deny-all-inbound"
#   priority                    = 4096
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
# }

# resource "azurerm_network_security_rule" "baseline_deny_inbound_uat" {
#   provider = azurerm.uat
#   for_each = {
#     for k, v in local.all_targets_uat :
#     k => v
#     if !can(regex("dns-inbound", lower(v.name)))
#   }

#   name                        = "deny-all-inbound"
#   priority                    = 4096
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
# }

# ---------- DENY TO INTERNET (all non-PE, non-appgw NSGs) ----------
resource "azurerm_network_security_rule" "deny_all_to_internet_hub" {
  for_each                    = local.all_targets_hub
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}
resource "azurerm_network_security_rule" "deny_all_to_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.all_targets_dev
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_dev,
    module.nsg_dev
  ]
}
resource "azurerm_network_security_rule" "deny_all_to_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.all_targets_qa
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_qa,
    module.nsg_qa
  ]
}
resource "azurerm_network_security_rule" "deny_all_to_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.all_targets_prod
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_prod,
    module.nsg_prod
  ]
}
resource "azurerm_network_security_rule" "deny_all_to_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.all_targets_uat
  name                        = "deny-to-internet"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_uat,
    module.nsg_uat
  ]
}

# ---------- PLANE ISOLATION (nonprod: dev↔qa) ----------
resource "azurerm_network_security_rule" "deny_dev_to_qa_np" {
  provider                    = azurerm.dev
  for_each                    = local.dev_nsg_targets_np_struct
  name                        = "deny-to-qa"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.qa_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "deny_qa_to_dev_np" {
  provider                    = azurerm.qa
  for_each                    = local.qa_nsg_targets_np_struct
  name                        = "deny-to-dev"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.dev_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# ---------- PLANE ISOLATION (prod: prod↔uat) ----------
resource "azurerm_network_security_rule" "deny_prod_to_uat_pr" {
  provider                    = azurerm.prod
  for_each                    = local.prod_nsg_targets_pr_struct
  name                        = "deny-to-uat"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.uat_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "deny_uat_to_prod_pr" {
  provider                    = azurerm.uat
  for_each                    = local.uat_nsg_targets_pr_struct
  name                        = "deny-to-prod"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.prod_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PostgreSQL Flexible Server HA (pgflex subnet) - allow TCP 5432 within VNet
# This ensures HA replication between primary and standby in the delegated subnet.

# Inbound allow (hub)
resource "azurerm_network_security_rule" "pgflex_allow_ha_inbound_hub" {
  for_each                    = { for k, v in local.workload_targets_hub : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-inbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Inbound allow (dev)
resource "azurerm_network_security_rule" "pgflex_allow_ha_inbound_dev" {
  provider                    = azurerm.dev
  for_each                    = { for k, v in local.workload_targets_dev : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-inbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Inbound allow (qa)
resource "azurerm_network_security_rule" "pgflex_allow_ha_inbound_qa" {
  provider                    = azurerm.qa
  for_each                    = { for k, v in local.workload_targets_qa : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-inbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Inbound allow (prod)
resource "azurerm_network_security_rule" "pgflex_allow_ha_inbound_prod" {
  provider                    = azurerm.prod
  for_each                    = { for k, v in local.workload_targets_prod : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-inbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Inbound allow (uat)
resource "azurerm_network_security_rule" "pgflex_allow_ha_inbound_uat" {
  provider                    = azurerm.uat
  for_each                    = { for k, v in local.workload_targets_uat : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-inbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Outbound allow (hub)
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_hub" {
  for_each                    = { for k, v in local.workload_targets_hub : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-outbound"
  priority                    = 320
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Outbound allow (dev)
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_dev" {
  provider                    = azurerm.dev
  for_each                    = { for k, v in local.workload_targets_dev : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-outbound"
  priority                    = 320
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Outbound allow (qa)
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_qa" {
  provider                    = azurerm.qa
  for_each                    = { for k, v in local.workload_targets_qa : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-outbound"
  priority                    = 320
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Outbound allow (prod)
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_prod" {
  provider                    = azurerm.prod
  for_each                    = { for k, v in local.workload_targets_prod : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-outbound"
  priority                    = 320
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# Outbound allow (uat)
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_uat" {
  provider                    = azurerm.uat
  for_each                    = { for k, v in local.workload_targets_uat : k => v if can(regex("pgflex$", k)) }
  name                        = "allow-pg-ha-outbound"
  priority                    = 320
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# baseline egress on workload nsgs (per subscription) ───────────────────────
resource "azurerm_network_security_rule" "allow_dns_to_azure_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "allow_dns_to_azure_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "allow_dns_to_azure_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "allow_dns_to_azure_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
resource "azurerm_network_security_rule" "allow_dns_to_azure_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "allow-dns-azure"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_ntp_to_azure_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "allow-ntp-azure"
  priority                    = 305
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# ---- Storage egress (TCP/443 to Service Tag: Storage) ----
resource "azurerm_network_security_rule" "allow_storage_egress_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_storage_egress_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_storage_egress_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_storage_egress_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_storage_egress_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "allow-storage-egress"
  priority                    = 330
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# ---- Azure Monitor egress (TCP/443 to Service Tag: AzureMonitor) ----
resource "azurerm_network_security_rule" "allow_azuremonitor_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_azuremonitor_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_azuremonitor_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_azuremonitor_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "allow_azuremonitor_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "allow-azuremonitor-egress"
  priority                    = 335
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# private endpoint rules (lane allow/deny) per subscription ────────────────
resource "azurerm_network_security_rule" "pe_allow_lane_hub" {
  for_each                    = local.pe_allow_hub
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}
resource "azurerm_network_security_rule" "pe_allow_lane_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pe_allow_dev
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_dev,
    module.nsg_dev
  ]
}
resource "azurerm_network_security_rule" "pe_allow_lane_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pe_allow_qa
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_qa,
    module.nsg_qa
  ]
}
resource "azurerm_network_security_rule" "pe_allow_lane_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pe_allow_prod
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_prod,
    module.nsg_prod
  ]
}
resource "azurerm_network_security_rule" "pe_allow_lane_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pe_allow_uat
  name                        = "allow-from-hub-and-spoke"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_uat,
    module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_deny_other_vnets_hub" {
  for_each                    = local.pe_deny_hub
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_hub,
    module.nsg_hub
  ]
}
resource "azurerm_network_security_rule" "pe_deny_other_vnets_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pe_deny_dev
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_dev,
    module.nsg_dev
  ]
}
resource "azurerm_network_security_rule" "pe_deny_other_vnets_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pe_deny_qa
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_qa,
    module.nsg_qa
  ]
}
resource "azurerm_network_security_rule" "pe_deny_other_vnets_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pe_deny_prod
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_prod,
    module.nsg_prod
  ]
}
resource "azurerm_network_security_rule" "pe_deny_other_vnets_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pe_deny_uat
  name                        = "deny-other-vnets"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = each.value.deny_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
  depends_on = [
    module.rg_uat,
    module.nsg_uat
  ]
}

# AKS egress (per subscription)

# HTTPS to Internet
resource "azurerm_network_security_rule" "aks_allow_https_internet_hub" {
  for_each                    = local.aks_targets_hub
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat
  name                        = "allow-aks-https-internet"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# HTTP to Internet
resource "azurerm_network_security_rule" "aks_allow_http_internet_hub" {
  for_each                    = local.aks_targets_hub
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat
  name                        = "allow-aks-http-internet"
  priority                    = 345
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# ACR (Service Tag: AzureContainerRegistry)
resource "azurerm_network_security_rule" "aks_allow_acr_hub" {
  for_each                    = local.aks_targets_hub
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat
  name                        = "allow-aks-acr"
  priority                    = 350
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# ServiceBus (Service Tag: ServiceBus)
resource "azurerm_network_security_rule" "aks_allow_servicebus_hub" {
  for_each                    = local.aks_targets_hub
  name                        = "allow-aks-servicebus"
  priority                    = 355
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev
  name                        = "allow-aks-servicebus"
  priority                    = 355
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa
  name                        = "allow-aks-servicebus"
  priority                    = 355
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod
  name                        = "allow-aks-servicebus"
  priority                    = 355
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat
  name                        = "allow-aks-servicebus"
  priority                    = 355
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# AKS ingress (per subscription)
locals {
  aks_ingress_allowed_cidrs = local.is_nonprod ? var.aks_ingress_allowed_cidrs["nonprod"] : var.aks_ingress_allowed_cidrs["prod"]
}

# HTTPS from Internet
resource "azurerm_network_security_rule" "aks_allow_https_from_internet_hub" {
  for_each                    = local.aks_targets_hub
  name                        = "allow-aks-https-from-internet"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev
  name                        = "allow-aks-https-from-internet"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa
  name                        = "allow-aks-https-from-internet"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod
  name                        = "allow-aks-https-from-internet"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat
  name                        = "allow-aks-https-from-internet"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# HTTP from Internet
# resource "azurerm_network_security_rule" "aks_allow_http_from_internet_hub" {
#   for_each                    = local.aks_targets_hub
#   name                        = "allow-aks-http-from-internet"
#   priority                    = 225
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefixes     = local.aks_ingress_allowed_cidrs
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
#   depends_on                  = [
#     module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
#     module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "aks_allow_http_from_internet_dev" {
#   provider                    = azurerm.dev
#   for_each                    = local.aks_targets_dev
#   name                        = "allow-aks-http-from-internet"
#   priority                    = 225
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefixes     = local.aks_ingress_allowed_cidrs
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
#   depends_on                  = [
#     module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
#     module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "aks_allow_http_from_internet_qa" {
#   provider                    = azurerm.qa
#   for_each                    = local.aks_targets_qa
#   name                        = "allow-aks-http-from-internet"
#   priority                    = 225
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefixes     = local.aks_ingress_allowed_cidrs
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
#   depends_on                  = [
#     module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
#     module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "aks_allow_http_from_internet_prod" {
#   provider                    = azurerm.prod
#   for_each                    = local.aks_targets_prod
#   name                        = "allow-aks-http-from-internet"
#   priority                    = 225
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefixes     = local.aks_ingress_allowed_cidrs
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
#   depends_on                  = [
#     module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
#     module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "aks_allow_http_from_internet_uat" {
#   provider                    = azurerm.uat
#   for_each                    = local.aks_targets_uat
#   name                        = "allow-aks-http-from-internet"
#   priority                    = 225
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefixes     = local.aks_ingress_allowed_cidrs
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.rg
#   network_security_group_name = each.value.name
#   depends_on                  = [
#     module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
#     module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
#   ]
# }

# PE (Cosmos DB for PostgreSQL) - outbound baseline (per subscription) ─────
resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_hub" {
  for_each                    = local.pe_cdbpg_hub
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pe_cdbpg_dev
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pe_cdbpg_qa
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pe_cdbpg_prod
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_cdbpg_deny_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pe_cdbpg_uat
  name                        = "deny-internet-egress"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [
    module.rg_hub,  module.rg_dev,  module.rg_qa,  module.rg_prod,  module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# dns: private resolver
locals {
  dnsr_name         = "pdnsr-${var.product}-${local.plane_code}-${var.region}-01"
  dnsr_hub_rg       = local.hub_rg_name
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
  enable_outbound     = var.dnsresolver_enable_outbound   # disable outbound when you want inbound-only

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod hub plane
    local.fedramp_common_tags, # shared FedRAMP/boundary metadata
    local.dnsr_tags            # your existing DNS resolver–specific tags
  )

  depends_on = [
    module.vnet_hub,
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat,
    module.vpng
  ]
}

# dns: public zones 
locals {
  public_dns_zones_active = toset(var.public_dns_zones)
  public_dns_env          = local.is_nonprod ? "nonprod" : "prod"
}

resource "azurerm_dns_zone" "public" {
  for_each            = local.public_dns_zones_active
  name                = each.value
  resource_group_name = local.hub_rg_name

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane
    local.fedramp_common_tags, # shared FedRAMP/boundary metadata
    {
      purpose     = "public-dns-zone"
      environment = local.public_dns_env
      lane        = local.public_dns_env
    }
  )

  depends_on = [
    module.rg_hub
  ]
}

# front door (shared-network rg)
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
  resource_group_name = local.hub_rg_name
  profile_name        = local.fd_profile_name
  endpoint_name       = local.fd_endpoint_name
  sku_name            = var.fd_sku_name

  tags = merge(
    local.tag_base,
    local.plane_tags,          # nonprod/prod plane
    local.fedramp_common_tags, # FedRAMP/boundary metadata
    local.fd_tags              # existing FD-specific tags
  )

  depends_on = [
    module.rg_hub
  ]
}

# network watcher (regional, managed by this stack) 
resource "azurerm_network_watcher" "hub" {
  count = local.is_nonprod || local.is_prod ? 1 : 0
  name                = "nw-${var.product}-${local.plane_code}-${var.region}-01"
  location            = var.location
  resource_group_name = local.hub_rg_name

  tags = merge(
    local.tag_base,
    local.plane_tags,
    local.fedramp_common_tags,
    {
      purpose = "network-watcher"
      service = "netops"
      lane    = local.lane
    }
  )

  depends_on = [
    module.rg_hub
  ]
}

# network watcher (spokes, subscription-local)

# DEV (nonprod plane only)
resource "azurerm_network_watcher" "dev" {
  count               = local.is_nonprod ? 1 : 0
  provider            = azurerm.dev
  name                = "nw-${var.product}-dev-${var.region}-01"
  location            = var.location
  resource_group_name = local.dev_rg_name

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.dev_only_tags,  # includes env, purpose/env-dev, criticality, lane, etc.
    {
      purpose = "network-watcher"
      service = "netops"
    }
  )

  depends_on = [
    module.rg_dev
  ]
}

# QA (nonprod plane only)
resource "azurerm_network_watcher" "qa" {
  count               = local.is_nonprod ? 1 : 0
  provider            = azurerm.qa
  name                = "nw-${var.product}-qa-${var.region}-01"
  location            = var.location
  resource_group_name = local.qa_rg_name

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.qa_only_tags,
    {
      purpose = "network-watcher"
      service = "netops"
    }
  )

  depends_on = [
    module.rg_qa
  ]
}

# PROD (prod plane only)
resource "azurerm_network_watcher" "prod" {
  count               = local.is_prod ? 1 : 0
  provider            = azurerm.prod
  name                = "nw-${var.product}-prod-${var.region}-01"
  location            = var.location
  resource_group_name = local.prod_rg_name

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.prod_only_tags,
    {
      purpose = "network-watcher"
      service = "netops"
    }
  )

  depends_on = [
    module.rg_prod
  ]
}

# UAT (prod plane only)
resource "azurerm_network_watcher" "uat" {
  count               = local.is_prod ? 1 : 0
  provider            = azurerm.uat
  name                = "nw-${var.product}-uat-${var.region}-01"
  location            = var.location
  resource_group_name = local.uat_rg_name

  tags = merge(
    local.tag_base,
    local.fedramp_common_tags,
    local.uat_only_tags,
    {
      purpose = "network-watcher"
      service = "netops"
    }
  )

  depends_on = [
    module.rg_uat
  ]
}
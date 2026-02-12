locals {
  _hub_key = local.is_nonprod ? "nphub" : "prhub"

  _vnet_map_nonprod = local.is_nonprod ? {
    (local._hub_key) = { id = module.vnet_hub.id, name = module.vnet_hub.name, subnets = module.vnet_hub.subnet_ids }
    dev              = { id = module.vnet_dev[0].id, name = module.vnet_dev[0].name, subnets = module.vnet_dev[0].subnet_ids }
    qa               = { id = module.vnet_qa[0].id, name = module.vnet_qa[0].name, subnets = module.vnet_qa[0].subnet_ids }
  } : {}

  _vnet_map_prod = local.is_prod ? {
    (local._hub_key) = { id = module.vnet_hub.id, name = module.vnet_hub.name, subnets = module.vnet_hub.subnet_ids }
    prod             = { id = module.vnet_prod[0].id, name = module.vnet_prod[0].name, subnets = module.vnet_prod[0].subnet_ids }
    uat              = { id = module.vnet_uat[0].id, name = module.vnet_uat[0].name, subnets = module.vnet_uat[0].subnet_ids }
  } : {}

  vnet_map_consolidated = merge(local._vnet_map_nonprod, local._vnet_map_prod)

  vnets_env_keyed = {
    for k, m in local.vnet_map_consolidated :
    (k == "nphub" ? "nonprod_hub" :
      k == "prhub" ? "prod_hub" :
      k == "dev" ? "dev_spoke" :
      k == "qa" ? "qa_spoke" :
      k == "prod" ? "prod_spoke" :
    k == "uat" ? "uat_spoke" : k) => m
  }
}
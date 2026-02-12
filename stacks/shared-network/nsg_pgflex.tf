locals {
  prio_pgflex_base = 300

  # Filter only pgflex NSGs once and reuse across planes
  pgflex_targets_hub  = { for k, v in local.workload_targets_hub : k => v if can(regex("pgflex$", k)) }
  pgflex_targets_dev  = { for k, v in local.workload_targets_dev : k => v if can(regex("pgflex$", k)) }
  pgflex_targets_qa   = { for k, v in local.workload_targets_qa : k => v if can(regex("pgflex$", k)) }
  pgflex_targets_prod = { for k, v in local.workload_targets_prod : k => v if can(regex("pgflex$", k)) }
  pgflex_targets_uat  = { for k, v in local.workload_targets_uat : k => v if can(regex("pgflex$", k)) }

  pgflex_rule_priority = {
    in_5432 = local.prio_pgflex_base + 10 # 310
    # ha_in_5432   = local.prio_pgflex_base + 10 # 310
    ha_out_5432  = local.prio_pgflex_base + 20 # 320
    s2s_in_5432  = local.prio_pgflex_base + 30 # 330
    s2s_out_5432 = local.prio_pgflex_base + 40 # 340
    # s2s_deny_in  = local.prio_pgflex_base + 70 # 370
    s2s_deny_out = local.prio_pgflex_base + 71 # 371
  }

  aks_client_subnet_name = lower(var.product) == "hrz" ? "akshrz" : "akspub"

  pgflex_client_subnet_names = distinct(compact([
    local.aks_client_subnet_name,
    "appsvc-int-linux-01",
    "privatelink",
    "internal"
  ]))

  # aks_cidrs_np = local.is_nonprod ? (
  #   local.is_pub
  #   ? {
  #       hub = { node = "172.10.2.0/24", pod = "172.210.0.0/16", svc = "172.110.0.0/16", dns = "172.110.0.10" }
  #       dev = { node = "172.11.2.0/24", pod = "172.211.0.0/16", svc = "172.111.0.0/16", dns = "172.111.0.10" }
  #       qa  = { node = "172.12.2.0/24", pod = "172.212.0.0/16", svc = "172.112.0.0/16", dns = "172.112.0.10" }
  #     }
  #   : {
  #       hub = { node = "10.10.2.0/24", pod = "10.210.0.0/16", svc = "10.110.0.0/16", dns = "10.110.0.10" }
  #       dev = { node = "10.11.2.0/24", pod = "10.211.0.0/16", svc = "10.111.0.0/16", dns = "10.111.0.10" }
  #       qa  = { node = "10.12.2.0/24", pod = "10.212.0.0/16", svc = "10.112.0.0/16", dns = "10.112.0.10" }
  #     }
  # ) : {}

  # aks_cidrs_pr = local.is_prod ? (
  #   local.is_pub
  #   ? {
  #       hub  = { node = "172.13.2.0/24", pod = "172.213.0.0/16", svc = "172.113.0.0/16", dns = "172.113.0.10" }
  #       prod = { node = "172.14.2.0/24", pod = "172.214.0.0/16", svc = "172.114.0.0/16", dns = "172.114.0.10" }
  #       uat  = { node = "172.15.2.0/24", pod = "172.215.0.0/16", svc = "172.115.0.0/16", dns = "172.115.0.10" }
  #     }
  #   : {
  #       hub  = { node = "10.13.2.0/24", pod = "10.213.0.0/16", svc = "10.113.0.0/16", dns = "10.113.0.10" }
  #       prod = { node = "10.14.2.0/24", pod = "10.214.0.0/16", svc = "10.114.0.0/16", dns = "10.114.0.10" }
  #       uat  = { node = "10.15.2.0/24", pod = "10.215.0.0/16", svc = "10.115.0.0/16", dns = "10.115.0.10" }
  #     }
  # ) : {}

  np_lane_keys = ["hub", "dev", "qa"]
  pr_lane_keys = ["hub", "prod", "uat"]

  # return [node, pod, svc] CIDRs for a given aks map + lane key
  aks_lane_triplet = {
    # nonprod
    for k in local.np_lane_keys :
    "np_${k}" => [
      try(local.aks_cidrs_np[k].node, null),
      try(local.aks_cidrs_np[k].pod, null),
      try(local.aks_cidrs_np[k].svc, null),
    ]
  }

  aks_lane_triplet_pr = {
    # prod
    for k in local.pr_lane_keys :
    "pr_${k}" => [
      try(local.aks_cidrs_pr[k].node, null),
      try(local.aks_cidrs_pr[k].pod, null),
      try(local.aks_cidrs_pr[k].svc, null),
    ]
  }

  # Per-lane AKS allow lists (ONLY hub + that lane)
  aks_known_client_cidrs_hub = distinct(compact(flatten(
    local.is_nonprod
    ? local.aks_lane_triplet["np_hub"]
    : local.aks_lane_triplet_pr["pr_hub"]
  )))

  aks_known_client_cidrs_dev = distinct(compact(flatten(
    local.is_nonprod ? concat(
      local.aks_lane_triplet["np_hub"],
      local.aks_lane_triplet["np_dev"]
    ) : []
  )))

  aks_known_client_cidrs_qa = distinct(compact(flatten(
    local.is_nonprod ? concat(
      local.aks_lane_triplet["np_hub"],
      local.aks_lane_triplet["np_qa"]
    ) : []
  )))

  aks_known_client_cidrs_prod = distinct(compact(flatten(
    local.is_prod ? concat(
      local.aks_lane_triplet_pr["pr_hub"],
      local.aks_lane_triplet_pr["pr_prod"]
    ) : []
  )))

  aks_known_client_cidrs_uat = distinct(compact(flatten(
    local.is_prod ? concat(
      local.aks_lane_triplet_pr["pr_hub"],
      local.aks_lane_triplet_pr["pr_uat"]
    ) : []
  )))

  nonprod_hub_subnets = try(var.nonprod_hub.subnets, {})
  dev_spoke_subnets   = try(var.dev_spoke.subnets, {})
  qa_spoke_subnets    = try(var.qa_spoke.subnets, {})
  prod_hub_subnets    = try(var.prod_hub.subnets, {})
  prod_spoke_subnets  = try(var.prod_spoke.subnets, {})
  uat_spoke_subnets   = try(var.uat_spoke.subnets, {})

  nonprod_hub_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.nonprod_hub_subnets[sn].address_prefixes, []),
      try([local.nonprod_hub_subnets[sn].cidr], [])
    )
  ])))

  dev_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.dev_spoke_subnets[sn].address_prefixes, []),
      try([local.dev_spoke_subnets[sn].cidr], [])
    )
  ])))

  qa_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.qa_spoke_subnets[sn].address_prefixes, []),
      try([local.qa_spoke_subnets[sn].cidr], [])
    )
  ])))

  prod_hub_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.prod_hub_subnets[sn].address_prefixes, []),
      try([local.prod_hub_subnets[sn].cidr], [])
    )
  ])))

  prod_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.prod_spoke_subnets[sn].address_prefixes, []),
      try([local.prod_spoke_subnets[sn].cidr], [])
    )
  ])))

  uat_client_cidrs = distinct(compact(flatten([
    for sn in local.pgflex_client_subnet_names : concat(
      try(local.uat_spoke_subnets[sn].address_prefixes, []),
      try([local.uat_spoke_subnets[sn].cidr], [])
    )
  ])))

  pgflex_allowed_sources_dev = distinct(compact(concat(
    local.dev_client_cidrs,
    local.aks_known_client_cidrs_dev
  )))

  pgflex_allowed_sources_qa = distinct(compact(concat(
    local.qa_client_cidrs,
    local.aks_known_client_cidrs_qa
  )))

  pgflex_allowed_sources_prod = distinct(compact(concat(
    local.prod_client_cidrs,
    local.aks_known_client_cidrs_prod
  )))

  pgflex_allowed_sources_uat = distinct(compact(concat(
    local.uat_client_cidrs,
    local.aks_known_client_cidrs_uat
  )))

  # Hub rule (if you have one)
  pgflex_allowed_sources_hub = distinct(compact(concat(
    local.is_nonprod ? local.nonprod_hub_client_cidrs : local.prod_hub_client_cidrs,
    local.aks_known_client_cidrs_hub
  )))
}

# PGFLEX — inbound 5432 allowed ONLY from selected AKS/AppSvc/PL/Internal subnets
# HUB
resource "azurerm_network_security_rule" "pgflex_allow_client_inbound_hub" {
  for_each                    = local.pgflex_targets_hub
  name                        = "allow-pgflex-client-inbound-5432"
  priority                    = local.pgflex_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_allowed_sources_hub
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
}

# DEV
resource "azurerm_network_security_rule" "pgflex_allow_client_inbound_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pgflex_targets_dev
  name                        = "allow-pgflex-client-inbound-5432"
  priority                    = local.pgflex_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_allowed_sources_dev
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
}

# QA
resource "azurerm_network_security_rule" "pgflex_allow_client_inbound_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pgflex_targets_qa
  name                        = "allow-pgflex-client-inbound-5432"
  priority                    = local.pgflex_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_allowed_sources_qa
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
}

# PROD
resource "azurerm_network_security_rule" "pgflex_allow_client_inbound_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pgflex_targets_prod
  name                        = "allow-pgflex-client-inbound-5432"
  priority                    = local.pgflex_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_allowed_sources_prod
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
}

# UAT
resource "azurerm_network_security_rule" "pgflex_allow_client_inbound_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pgflex_targets_uat
  name                        = "allow-pgflex-client-inbound-5432"
  priority                    = local.pgflex_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_allowed_sources_uat
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
}

# PGFLEX — HA replication within VNet (TCP/5432)
# Outbound HA (TCP/5432)

# HUB
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_hub" {
  for_each                    = local.pgflex_targets_hub
  name                        = "allow-pgflex-ha-outbound-5432"
  priority                    = local.pgflex_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# DEV
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pgflex_targets_dev
  name                        = "allow-pgflex-ha-outbound-5432"
  priority                    = local.pgflex_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# QA
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pgflex_targets_qa
  name                        = "allow-pgflex-ha-outbound-5432"
  priority                    = local.pgflex_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PROD
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pgflex_targets_prod
  name                        = "allow-pgflex-ha-outbound-5432"
  priority                    = local.pgflex_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# UAT
resource "azurerm_network_security_rule" "pgflex_allow_ha_outbound_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pgflex_targets_uat
  name                        = "allow-pgflex-ha-outbound-5432"
  priority                    = local.pgflex_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PGFLEX — S2S VPN (pgflex-only, one-way)
# - PUB:  inbound allow 5432 from HRZ pgflex subnet(s) + deny other outbound to HRZ
# - HRZ:  outbound allow 5432 to PUB pgflex subnet(s) + deny other inbound from PUB

locals {
  pgflex_s2s_in_targets_hub  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_hub : {}
  pgflex_s2s_in_targets_dev  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_dev : {}
  pgflex_s2s_in_targets_qa   = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_qa : {}
  pgflex_s2s_in_targets_prod = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_prod : {}
  pgflex_s2s_in_targets_uat  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_uat : {}

  pgflex_s2s_out_targets_hub  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_hub : {}
  pgflex_s2s_out_targets_dev  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_dev : {}
  pgflex_s2s_out_targets_qa   = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_qa : {}
  pgflex_s2s_out_targets_prod = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_prod : {}
  pgflex_s2s_out_targets_uat  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_uat : {}

  pgflex_deny_in_from_peer_hub  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_hub : {}
  pgflex_deny_in_from_peer_dev  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_dev : {}
  pgflex_deny_in_from_peer_qa   = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_qa : {}
  pgflex_deny_in_from_peer_prod = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_prod : {}
  pgflex_deny_in_from_peer_uat  = (local.enable_s2s_effective && var.product == "hrz") ? local.pgflex_targets_uat : {}

  pgflex_deny_out_to_peer_hub  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_hub : {}
  pgflex_deny_out_to_peer_dev  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_dev : {}
  pgflex_deny_out_to_peer_qa   = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_qa : {}
  pgflex_deny_out_to_peer_prod = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_prod : {}
  pgflex_deny_out_to_peer_uat  = (local.enable_s2s_effective && var.product == "pub") ? local.pgflex_targets_uat : {}
}

# DEV S2S rules
resource "azurerm_network_security_rule" "pgflex_allow_s2s_inbound_dev" {
  provider                     = azurerm.dev
  for_each                     = local.pgflex_s2s_in_targets_dev
  name                         = "allow-pgflex-s2s-inbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_in_5432
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.peer_pgflex_subnet_cidrs.dev
  destination_address_prefixes = var.local_pgflex_subnet_cidrs.dev
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_allow_s2s_outbound_dev" {
  provider                     = azurerm.dev
  for_each                     = local.pgflex_s2s_out_targets_dev
  name                         = "allow-pgflex-s2s-outbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_out_5432
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.local_pgflex_subnet_cidrs.dev
  destination_address_prefixes = var.peer_pgflex_subnet_cidrs.dev
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_deny_other_to_peer_dev_pub" {
  provider                     = azurerm.dev
  for_each                     = local.pgflex_deny_out_to_peer_dev
  name                         = "deny-non-pgflex-outbound-to-peer"
  priority                     = local.pgflex_rule_priority.s2s_deny_out
  direction                    = "Outbound"
  access                       = "Deny"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefixes = var.s2s_peer_address_spaces
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# QA S2S rules
resource "azurerm_network_security_rule" "pgflex_allow_s2s_inbound_qa" {
  provider                     = azurerm.qa
  for_each                     = local.pgflex_s2s_in_targets_qa
  name                         = "allow-pgflex-s2s-inbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_in_5432
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.peer_pgflex_subnet_cidrs.qa
  destination_address_prefixes = var.local_pgflex_subnet_cidrs.qa
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_allow_s2s_outbound_qa" {
  provider                     = azurerm.qa
  for_each                     = local.pgflex_s2s_out_targets_qa
  name                         = "allow-pgflex-s2s-outbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_out_5432
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.local_pgflex_subnet_cidrs.qa
  destination_address_prefixes = var.peer_pgflex_subnet_cidrs.qa
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_deny_other_to_peer_qa_pub" {
  provider                     = azurerm.qa
  for_each                     = local.pgflex_deny_out_to_peer_qa
  name                         = "deny-non-pgflex-outbound-to-peer"
  priority                     = local.pgflex_rule_priority.s2s_deny_out
  direction                    = "Outbound"
  access                       = "Deny"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefixes = var.s2s_peer_address_spaces
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PROD S2S rules
resource "azurerm_network_security_rule" "pgflex_allow_s2s_inbound_prod" {
  provider                     = azurerm.prod
  for_each                     = local.pgflex_s2s_in_targets_prod
  name                         = "allow-pgflex-s2s-inbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_in_5432
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.peer_pgflex_subnet_cidrs.prod
  destination_address_prefixes = var.local_pgflex_subnet_cidrs.prod
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_allow_s2s_outbound_prod" {
  provider                     = azurerm.prod
  for_each                     = local.pgflex_s2s_out_targets_prod
  name                         = "allow-pgflex-s2s-outbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_out_5432
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.local_pgflex_subnet_cidrs.prod
  destination_address_prefixes = var.peer_pgflex_subnet_cidrs.prod
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_deny_other_to_peer_prod_pub" {
  provider                     = azurerm.prod
  for_each                     = local.pgflex_deny_out_to_peer_prod
  name                         = "deny-non-pgflex-outbound-to-peer"
  priority                     = local.pgflex_rule_priority.s2s_deny_out
  direction                    = "Outbound"
  access                       = "Deny"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefixes = var.s2s_peer_address_spaces
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# UAT S2S rules
resource "azurerm_network_security_rule" "pgflex_allow_s2s_inbound_uat" {
  provider                     = azurerm.uat
  for_each                     = local.pgflex_s2s_in_targets_uat
  name                         = "allow-pgflex-s2s-inbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_in_5432
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.peer_pgflex_subnet_cidrs.uat
  destination_address_prefixes = var.local_pgflex_subnet_cidrs.uat
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_allow_s2s_outbound_uat" {
  provider                     = azurerm.uat
  for_each                     = local.pgflex_s2s_out_targets_uat
  name                         = "allow-pgflex-s2s-outbound-5432"
  priority                     = local.pgflex_rule_priority.s2s_out_5432
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5432"
  source_address_prefixes      = var.local_pgflex_subnet_cidrs.uat
  destination_address_prefixes = var.peer_pgflex_subnet_cidrs.uat
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pgflex_deny_other_to_peer_uat_pub" {
  provider                     = azurerm.uat
  for_each                     = local.pgflex_deny_out_to_peer_uat
  name                         = "deny-non-pgflex-outbound-to-peer"
  priority                     = local.pgflex_rule_priority.s2s_deny_out
  direction                    = "Outbound"
  access                       = "Deny"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefixes = var.s2s_peer_address_spaces
  resource_group_name          = each.value.rg
  network_security_group_name  = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PGFLEX-AUTH (SUBNET-SPECIFIC) NSG RULES — delegated pgflex-auth subnet
locals {
  prio_pgflex_auth_base = 300

  pgflex_auth_targets_hub  = { for k, v in local.workload_targets_hub : k => v if can(regex("pgflex-auth$", k)) }
  pgflex_auth_targets_dev  = { for k, v in local.workload_targets_dev : k => v if can(regex("pgflex-auth$", k)) }
  pgflex_auth_targets_qa   = { for k, v in local.workload_targets_qa : k => v if can(regex("pgflex-auth$", k)) }
  pgflex_auth_targets_prod = { for k, v in local.workload_targets_prod : k => v if can(regex("pgflex-auth$", k)) }
  pgflex_auth_targets_uat  = { for k, v in local.workload_targets_uat : k => v if can(regex("pgflex-auth$", k)) }

  pgflex_auth_rule_priority = {
    in_5432      = local.prio_pgflex_auth_base + 10 # 310
    ha_out_5432  = local.prio_pgflex_auth_base + 20 # 320
    s2s_in_5432  = local.prio_pgflex_auth_base + 30 # 330
    s2s_out_5432 = local.prio_pgflex_auth_base + 40 # 340
    s2s_deny_out = local.prio_pgflex_auth_base + 71 # 371
  }

  pgflex_auth_allowed_sources_hub  = local.pgflex_allowed_sources_hub
  pgflex_auth_allowed_sources_dev  = local.pgflex_allowed_sources_dev
  pgflex_auth_allowed_sources_qa   = local.pgflex_allowed_sources_qa
  pgflex_auth_allowed_sources_prod = local.pgflex_allowed_sources_prod
  pgflex_auth_allowed_sources_uat  = local.pgflex_allowed_sources_uat
}

# HUB
resource "azurerm_network_security_rule" "pgflex_auth_allow_client_inbound_hub" {
  for_each                    = local.pgflex_auth_targets_hub
  name                        = "allow-pgflex-auth-client-inbound-5432"
  priority                    = local.pgflex_auth_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_auth_allowed_sources_hub
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_hub]
}

# DEV
resource "azurerm_network_security_rule" "pgflex_auth_allow_client_inbound_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pgflex_auth_targets_dev
  name                        = "allow-pgflex-auth-client-inbound-5432"
  priority                    = local.pgflex_auth_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_auth_allowed_sources_dev
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev]
}

# QA
resource "azurerm_network_security_rule" "pgflex_auth_allow_client_inbound_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pgflex_auth_targets_qa
  name                        = "allow-pgflex-auth-client-inbound-5432"
  priority                    = local.pgflex_auth_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_auth_allowed_sources_qa
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_qa]
}

# PROD
resource "azurerm_network_security_rule" "pgflex_auth_allow_client_inbound_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pgflex_auth_targets_prod
  name                        = "allow-pgflex-auth-client-inbound-5432"
  priority                    = local.pgflex_auth_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_auth_allowed_sources_prod
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod]
}

# UAT
resource "azurerm_network_security_rule" "pgflex_auth_allow_client_inbound_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pgflex_auth_targets_uat
  name                        = "allow-pgflex-auth-client-inbound-5432"
  priority                    = local.pgflex_auth_rule_priority.in_5432
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = local.pgflex_auth_allowed_sources_uat
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_uat]
}

# HUB
resource "azurerm_network_security_rule" "pgflex_auth_allow_ha_outbound_hub" {
  for_each                    = local.pgflex_auth_targets_hub
  name                        = "allow-pgflex-auth-ha-outbound-5432"
  priority                    = local.pgflex_auth_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_hub]
}

# DEV
resource "azurerm_network_security_rule" "pgflex_auth_allow_ha_outbound_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pgflex_auth_targets_dev
  name                        = "allow-pgflex-auth-ha-outbound-5432"
  priority                    = local.pgflex_auth_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev]
}

# QA
resource "azurerm_network_security_rule" "pgflex_auth_allow_ha_outbound_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pgflex_auth_targets_qa
  name                        = "allow-pgflex-auth-ha-outbound-5432"
  priority                    = local.pgflex_auth_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_qa]
}

# PROD
resource "azurerm_network_security_rule" "pgflex_auth_allow_ha_outbound_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pgflex_auth_targets_prod
  name                        = "allow-pgflex-auth-ha-outbound-5432"
  priority                    = local.pgflex_auth_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod]
}

# UAT
resource "azurerm_network_security_rule" "pgflex_auth_allow_ha_outbound_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pgflex_auth_targets_uat
  name                        = "allow-pgflex-auth-ha-outbound-5432"
  priority                    = local.pgflex_auth_rule_priority.ha_out_5432
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_uat]
}
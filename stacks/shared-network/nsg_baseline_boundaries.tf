locals {
  baseline_boundary_prio_base = 800
  baseline_plane_deny_prio    = 4000

  # Nonprod: dev plane targets excluding privatelink
  dev_nsg_targets_np_struct_plane = {
    for k, v in local.dev_nsg_targets_np_struct :
    k => v
    if !can(regex("privatelink", k))
  }

  # Nonprod: qa plane targets excluding privatelink
  qa_nsg_targets_np_struct_plane = {
    for k, v in local.qa_nsg_targets_np_struct :
    k => v
    if !can(regex("privatelink", k))
  }

  # Prod: prod plane targets excluding privatelink
  prod_nsg_targets_pr_struct_plane = {
    for k, v in local.prod_nsg_targets_pr_struct :
    k => v
    if !can(regex("privatelink", k))
  }

  # Prod: uat plane targets excluding privatelink
  uat_nsg_targets_pr_struct_plane = {
    for k, v in local.uat_nsg_targets_pr_struct :
    k => v
    if !can(regex("privatelink", k))
  }

  _pe_keys_plane = [for k in local.nsg_keys : k if can(regex("privatelink", k))]

  _pe_role_by_key = {
    for k in local._pe_keys_plane :
    k => (
      startswith(k, "hub-") ? "hub" :
      startswith(k, "dev-") ? "dev" :
      startswith(k, "qa-") ? "qa" :
      startswith(k, "prod-") ? "prod" :
      startswith(k, "uat-") ? "uat" : "other"
    )
  }

  cidr_np_hub = local.is_nonprod ? lookup(var.nonprod_hub, "cidrs", ["0.0.0.0/32"])[0] : null
  cidr_np_dev = local.is_nonprod ? lookup(var.dev_spoke, "cidrs", ["0.0.0.0/32"])[0] : null
  cidr_np_qa  = local.is_nonprod ? lookup(var.qa_spoke, "cidrs", ["0.0.0.0/32"])[0] : null

  cidr_pr_hub  = local.is_prod ? lookup(var.prod_hub, "cidrs", ["0.0.0.0/32"])[0] : null
  cidr_pr_prod = local.is_prod ? lookup(var.prod_spoke, "cidrs", ["0.0.0.0/32"])[0] : null
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

  pe_allow_hub  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^hub-", k)) }
  pe_allow_dev  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^dev-", k)) }
  pe_allow_qa   = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^qa-", k)) }
  pe_allow_prod = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^prod-", k)) }
  pe_allow_uat  = { for k, v in local.pe_rules_allow_nonempty : k => v if can(regex("^uat-", k)) }

  pe_deny_hub  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^hub-", k)) }
  pe_deny_dev  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^dev-", k)) }
  pe_deny_qa   = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^qa-", k)) }
  pe_deny_prod = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^prod-", k)) }
  pe_deny_uat  = { for k, v in local.pe_rules_deny_nonempty : k => v if can(regex("^uat-", k)) }
}

resource "azurerm_network_security_rule" "pe_allow_lane_hub" {
  for_each                    = local.pe_allow_hub
  name                        = "pe-allow-lane-peers"
  priority                    = local.baseline_boundary_prio_base + 0
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
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_allow_lane_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pe_allow_dev
  name                        = "pe-allow-lane-peers"
  priority                    = local.baseline_boundary_prio_base + 0
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
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_allow_lane_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pe_allow_qa
  name                        = "pe-allow-lane-peers"
  priority                    = local.baseline_boundary_prio_base + 0
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
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_allow_lane_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pe_allow_prod
  name                        = "pe-allow-lane-peers"
  priority                    = local.baseline_boundary_prio_base + 0
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
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "pe_allow_lane_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pe_allow_uat
  name                        = "pe-allow-lane-peers"
  priority                    = local.baseline_boundary_prio_base + 0
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
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# resource "azurerm_network_security_rule" "pe_deny_other_vnets_hub" {
#   for_each                    = local.pe_deny_hub
#   name                        = "pe-deny-nonlane-vnets"
#   priority                    = local.baseline_boundary_prio_base + 10
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefixes     = each.value.deny_prefixes
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.nsg_rg
#   network_security_group_name = each.value.nsg_name
#   depends_on = [
#     module.nsg_hub,
#     module.nsg_dev,
#     module.nsg_qa,
#     module.nsg_prod,
#     module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "pe_deny_other_vnets_dev" {
#   provider                    = azurerm.dev
#   for_each                    = local.pe_deny_dev
#   name                        = "pe-deny-nonlane-vnets"
#   priority                    = local.baseline_boundary_prio_base + 10
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefixes     = each.value.deny_prefixes
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.nsg_rg
#   network_security_group_name = each.value.nsg_name
#   depends_on = [
#     module.nsg_hub,
#     module.nsg_dev,
#     module.nsg_qa,
#     module.nsg_prod,
#     module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "pe_deny_other_vnets_qa" {
#   provider                    = azurerm.qa
#   for_each                    = local.pe_deny_qa
#   name                        = "pe-deny-nonlane-vnets"
#   priority                    = local.baseline_boundary_prio_base + 10
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefixes     = each.value.deny_prefixes
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.nsg_rg
#   network_security_group_name = each.value.nsg_name
#   depends_on = [
#     module.nsg_hub,
#     module.nsg_dev,
#     module.nsg_qa,
#     module.nsg_prod,
#     module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "pe_deny_other_vnets_prod" {
#   provider                    = azurerm.prod
#   for_each                    = local.pe_deny_prod
#   name                        = "pe-deny-nonlane-vnets"
#   priority                    = local.baseline_boundary_prio_base + 10
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefixes     = each.value.deny_prefixes
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.nsg_rg
#   network_security_group_name = each.value.nsg_name
#   depends_on = [
#     module.nsg_hub,
#     module.nsg_dev,
#     module.nsg_qa,
#     module.nsg_prod,
#     module.nsg_uat
#   ]
# }

# resource "azurerm_network_security_rule" "pe_deny_other_vnets_uat" {
#   provider                    = azurerm.uat
#   for_each                    = local.pe_deny_uat
#   name                        = "pe-deny-nonlane-vnets"
#   priority                    = local.baseline_boundary_prio_base + 10
#   direction                   = "Inbound"
#   access                      = "Deny"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefixes     = each.value.deny_prefixes
#   destination_address_prefix  = "*"
#   resource_group_name         = each.value.nsg_rg
#   network_security_group_name = each.value.nsg_name
#   depends_on = [
#     module.nsg_hub,
#     module.nsg_dev,
#     module.nsg_qa,
#     module.nsg_prod,
#     module.nsg_uat
#   ]
# }

# PRIVATE ENDPOINT SUBNET ISOLATION — Additional enforcement (Outbound)
# Reserved priority range: 800–899
# Adds:
# - deny outbound to non-lane VNets (mirror of inbound deny)
# - deny outbound to Internet (PE subnets should not initiate Internet)

# Outbound: deny non-lane VNets

# resource "azurerm_network_security_rule" "pe_deny_nonlane_vnets_out_hub" {
#   for_each                     = local.pe_deny_hub
#   name                         = "pe-deny-out-nonlane-vnets"
#   priority                     = local.baseline_boundary_prio_base + 20
#   direction                    = "Outbound"
#   access                       = "Deny"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "*"
#   source_address_prefix        = "*"
#   destination_address_prefixes = each.value.deny_prefixes
#   resource_group_name          = each.value.nsg_rg
#   network_security_group_name  = each.value.nsg_name
# }

# resource "azurerm_network_security_rule" "pe_deny_nonlane_vnets_out_dev" {
#   provider                     = azurerm.dev
#   for_each                     = local.pe_deny_dev
#   name                         = "pe-deny-out-nonlane-vnets"
#   priority                     = local.baseline_boundary_prio_base + 20
#   direction                    = "Outbound"
#   access                       = "Deny"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "*"
#   source_address_prefix        = "*"
#   destination_address_prefixes = each.value.deny_prefixes
#   resource_group_name          = each.value.nsg_rg
#   network_security_group_name  = each.value.nsg_name
# }

# resource "azurerm_network_security_rule" "pe_deny_nonlane_vnets_out_qa" {
#   provider                     = azurerm.qa
#   for_each                     = local.pe_deny_qa
#   name                         = "pe-deny-out-nonlane-vnets"
#   priority                     = local.baseline_boundary_prio_base + 20
#   direction                    = "Outbound"
#   access                       = "Deny"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "*"
#   source_address_prefix        = "*"
#   destination_address_prefixes = each.value.deny_prefixes
#   resource_group_name          = each.value.nsg_rg
#   network_security_group_name  = each.value.nsg_name
# }

# resource "azurerm_network_security_rule" "pe_deny_nonlane_vnets_out_prod" {
#   provider                     = azurerm.prod
#   for_each                     = local.pe_deny_prod
#   name                         = "pe-deny-out-nonlane-vnets"
#   priority                     = local.baseline_boundary_prio_base + 20
#   direction                    = "Outbound"
#   access                       = "Deny"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "*"
#   source_address_prefix        = "*"
#   destination_address_prefixes = each.value.deny_prefixes
#   resource_group_name          = each.value.nsg_rg
#   network_security_group_name  = each.value.nsg_name
# }

# resource "azurerm_network_security_rule" "pe_deny_nonlane_vnets_out_uat" {
#   provider                     = azurerm.uat
#   for_each                     = local.pe_deny_uat
#   name                         = "pe-deny-out-nonlane-vnets"
#   priority                     = local.baseline_boundary_prio_base + 20
#   direction                    = "Outbound"
#   access                       = "Deny"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "*"
#   source_address_prefix        = "*"
#   destination_address_prefixes = each.value.deny_prefixes
#   resource_group_name          = each.value.nsg_rg
#   network_security_group_name  = each.value.nsg_name
# }

# Outbound: deny Internet
resource "azurerm_network_security_rule" "pe_deny_internet_out_hub" {
  for_each                    = local.pe_allow_hub
  name                        = "pe-deny-out-internet"
  priority                    = local.baseline_boundary_prio_base + 30
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
}

resource "azurerm_network_security_rule" "pe_deny_internet_out_dev" {
  provider                    = azurerm.dev
  for_each                    = local.pe_allow_dev
  name                        = "pe-deny-out-internet"
  priority                    = local.baseline_boundary_prio_base + 30
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
}

resource "azurerm_network_security_rule" "pe_deny_internet_out_qa" {
  provider                    = azurerm.qa
  for_each                    = local.pe_allow_qa
  name                        = "pe-deny-out-internet"
  priority                    = local.baseline_boundary_prio_base + 30
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
}

resource "azurerm_network_security_rule" "pe_deny_internet_out_prod" {
  provider                    = azurerm.prod
  for_each                    = local.pe_allow_prod
  name                        = "pe-deny-out-internet"
  priority                    = local.baseline_boundary_prio_base + 30
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
}

resource "azurerm_network_security_rule" "pe_deny_internet_out_uat" {
  provider                    = azurerm.uat
  for_each                    = local.pe_allow_uat
  name                        = "pe-deny-out-internet"
  priority                    = local.baseline_boundary_prio_base + 30
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.nsg_rg
  network_security_group_name = each.value.nsg_name
}

# PLANE ISOLATION — enforce nonprod dev↔qa and prod↔uat separation
#
# Reserved priority range: 4000–4099 (hard plane isolation denies)
# - Outbound denies: baseline_plane_deny_prio + 0
# - Inbound  denies: baseline_plane_deny_prio + 10

locals {
  # Keep your existing base
  baseline_plane_deny_prio_outbound = local.baseline_plane_deny_prio + 0
  baseline_plane_deny_prio_inbound  = local.baseline_plane_deny_prio + 10

  # PE-only plane targets (privatelink NSGs only)
  # These are derived from pe_allow_* which already selects privatelink subnets.
  dev_pe_nsg_targets_np_struct_plane = local.is_nonprod ? {
    for k, v in local.pe_allow_dev : k => { name = v.nsg_name, rg = v.nsg_rg }
  } : {}

  qa_pe_nsg_targets_np_struct_plane = local.is_nonprod ? {
    for k, v in local.pe_allow_qa : k => { name = v.nsg_name, rg = v.nsg_rg }
  } : {}

  prod_pe_nsg_targets_pr_struct_plane = local.is_prod ? {
    for k, v in local.pe_allow_prod : k => { name = v.nsg_name, rg = v.nsg_rg }
  } : {}

  uat_pe_nsg_targets_pr_struct_plane = local.is_prod ? {
    for k, v in local.pe_allow_uat : k => { name = v.nsg_name, rg = v.nsg_rg }
  } : {}
}

# NONPROD: DEV <-> QA
# DEV: deny outbound to QA
resource "azurerm_network_security_rule" "plane_deny_dev_to_qa_out_np" {
  provider                    = azurerm.dev
  for_each                    = local.dev_nsg_targets_np_struct_plane
  name                        = "plane-deny-out-to-qa"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.qa_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# QA: deny inbound from DEV (mirror)
resource "azurerm_network_security_rule" "plane_deny_dev_to_qa_in_np" {
  provider                    = azurerm.qa
  for_each                    = local.qa_nsg_targets_np_struct_plane
  name                        = "plane-deny-in-from-dev"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.dev_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# QA: deny outbound to DEV
resource "azurerm_network_security_rule" "plane_deny_qa_to_dev_out_np" {
  provider                    = azurerm.qa
  for_each                    = local.qa_nsg_targets_np_struct_plane
  name                        = "plane-deny-out-to-dev"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.dev_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# DEV: deny inbound from QA (mirror)
resource "azurerm_network_security_rule" "plane_deny_qa_to_dev_in_np" {
  provider                    = azurerm.dev
  for_each                    = local.dev_nsg_targets_np_struct_plane
  name                        = "plane-deny-in-from-qa"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.qa_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# PROD: PROD <-> UAT
# PROD: deny outbound to UAT
resource "azurerm_network_security_rule" "plane_deny_prod_to_uat_out_pr" {
  provider                    = azurerm.prod
  for_each                    = local.prod_nsg_targets_pr_struct_plane
  name                        = "plane-deny-out-to-uat"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.uat_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# UAT: deny inbound from PROD (mirror)
resource "azurerm_network_security_rule" "plane_deny_prod_to_uat_in_pr" {
  provider                    = azurerm.uat
  for_each                    = local.uat_nsg_targets_pr_struct_plane
  name                        = "plane-deny-in-from-prod"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.prod_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# UAT: deny outbound to PROD
resource "azurerm_network_security_rule" "plane_deny_uat_to_prod_out_pr" {
  provider                    = azurerm.uat
  for_each                    = local.uat_nsg_targets_pr_struct_plane
  name                        = "plane-deny-out-to-prod"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.prod_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# PROD: deny inbound from UAT (mirror)
resource "azurerm_network_security_rule" "plane_deny_uat_to_prod_in_pr" {
  provider                    = azurerm.prod
  for_each                    = local.prod_nsg_targets_pr_struct_plane
  name                        = "plane-deny-in-from-uat"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.uat_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.nsg_hub,
    module.nsg_dev,
    module.nsg_qa,
    module.nsg_prod,
    module.nsg_uat
  ]
}

# PLANE ISOLATION — PrivateLink subnets only (privatelink NSGs)
# Uses same plane deny priorities (4000/4010) but applies to PE NSGs only.

# NONPROD: DEV <-> QA (PE subnets)
resource "azurerm_network_security_rule" "pe_plane_deny_dev_to_qa_out_np" {
  provider                    = azurerm.dev
  for_each                    = local.dev_pe_nsg_targets_np_struct_plane
  name                        = "pe-plane-deny-out-to-qa"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.qa_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev, module.nsg_qa]
}

resource "azurerm_network_security_rule" "pe_plane_deny_dev_to_qa_in_np" {
  provider                    = azurerm.qa
  for_each                    = local.qa_pe_nsg_targets_np_struct_plane
  name                        = "pe-plane-deny-in-from-dev"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.dev_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev, module.nsg_qa]
}

resource "azurerm_network_security_rule" "pe_plane_deny_qa_to_dev_out_np" {
  provider                    = azurerm.qa
  for_each                    = local.qa_pe_nsg_targets_np_struct_plane
  name                        = "pe-plane-deny-out-to-dev"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.dev_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev, module.nsg_qa]
}

resource "azurerm_network_security_rule" "pe_plane_deny_qa_to_dev_in_np" {
  provider                    = azurerm.dev
  for_each                    = local.dev_pe_nsg_targets_np_struct_plane
  name                        = "pe-plane-deny-in-from-qa"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.qa_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_dev, module.nsg_qa]
}

# PROD: PROD <-> UAT (PE subnets)
resource "azurerm_network_security_rule" "pe_plane_deny_prod_to_uat_out_pr" {
  provider                    = azurerm.prod
  for_each                    = local.prod_pe_nsg_targets_pr_struct_plane
  name                        = "pe-plane-deny-out-to-uat"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.uat_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod, module.nsg_uat]
}

resource "azurerm_network_security_rule" "pe_plane_deny_prod_to_uat_in_pr" {
  provider                    = azurerm.uat
  for_each                    = local.uat_pe_nsg_targets_pr_struct_plane
  name                        = "pe-plane-deny-in-from-prod"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.prod_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod, module.nsg_uat]
}

resource "azurerm_network_security_rule" "pe_plane_deny_uat_to_prod_out_pr" {
  provider                    = azurerm.uat
  for_each                    = local.uat_pe_nsg_targets_pr_struct_plane
  name                        = "pe-plane-deny-out-to-prod"
  priority                    = local.baseline_plane_deny_prio_outbound
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = local.prod_vnet_cidr
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod, module.nsg_uat]
}

resource "azurerm_network_security_rule" "pe_plane_deny_uat_to_prod_in_pr" {
  provider                    = azurerm.prod
  for_each                    = local.prod_pe_nsg_targets_pr_struct_plane
  name                        = "pe-plane-deny-in-from-uat"
  priority                    = local.baseline_plane_deny_prio_inbound
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.uat_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on                  = [module.nsg_prod, module.nsg_uat]
}

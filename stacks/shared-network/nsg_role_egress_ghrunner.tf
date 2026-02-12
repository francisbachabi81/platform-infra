locals {
  ghrunner_enabled    = true
  ghrunner_allow_http = false

  ghrunner_targets_all = {
    for k, v in local._workload_pairs :
    k => { name = v.nsg_name, rg = v.nsg_rg }
    if v.subnet_name == "internal"
  }

  ghrunner_targets_hub  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^hub-", k)) }
  ghrunner_targets_dev  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^dev-", k)) }
  ghrunner_targets_qa   = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^qa-", k)) }
  ghrunner_targets_prod = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^prod-", k)) }
  ghrunner_targets_uat  = { for k, v in local.ghrunner_targets_all : k => v if can(regex("^uat-", k)) }

  ghrunner_prio_base = 700

  # HRZ + PUB use standard hub egress IPs; PUB uses its own
  ghrunner_egress_ip = lower(var.product) == "pub" ? (local.is_nonprod ? "172.10.13.10" : "172.13.13.10") : (local.is_nonprod ? "10.10.13.10" : "10.13.13.10")
}

# HUB — GitHub runner egress
resource "azurerm_network_security_rule" "allow_ghrunner_https_internet_hub" {
  for_each                    = local.ghrunner_enabled ? local.ghrunner_targets_hub : {}
  name                        = "allow-ghrunner-https-internet"
  priority                    = local.ghrunner_prio_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = local.ghrunner_egress_ip
  destination_address_prefix  = "Internet"
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

resource "azurerm_network_security_rule" "allow_ghrunner_http_internet_hub" {
  for_each                    = (local.ghrunner_enabled && local.ghrunner_allow_http) ? local.ghrunner_targets_hub : {}
  name                        = "allow-ghrunner-http-internet"
  priority                    = local.ghrunner_prio_base + 5
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = local.ghrunner_egress_ip
  destination_address_prefix  = "Internet"
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

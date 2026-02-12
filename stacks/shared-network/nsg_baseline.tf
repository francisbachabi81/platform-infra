locals {
  baseline_prio_interconnect_base = 600
  baseline_prio_egress_base       = 620
  baseline_deny_prio_base         = 3900
}

# INTERCONNECT
locals {
  pub_pgflex_peer_cidrs_nonprod = [
    "172.11.3.0/24", # dev
    "172.12.3.0/24", # qa
  ]

  pub_pgflex_peer_cidrs_prod = [
    "172.14.3.0/24", # prod
    "172.15.3.0/24", # uat
  ]

  pub_pgflex_peer_cidrs_effective = var.plane == "prod" ? local.pub_pgflex_peer_cidrs_prod : local.pub_pgflex_peer_cidrs_nonprod

  pub_supernet_hub_nonprod = ["172.10.0.0/16"]
  pub_supernet_dev         = ["172.11.0.0/16"]
  pub_supernet_qa          = ["172.12.0.0/16"]

  pub_supernet_hub_prod = ["172.13.0.0/16"]
  pub_supernet_prod     = ["172.14.0.0/16"]
  pub_supernet_uat      = ["172.15.0.0/16"]

  pub_supernet_hub_effective = var.plane == "prod" ? local.pub_supernet_hub_prod : local.pub_supernet_hub_nonprod

  pub_supernet_sources_effective = var.plane == "prod" ? concat(
    local.pub_supernet_hub_prod,
    local.pub_supernet_prod,
    local.pub_supernet_uat
    ) : concat(
    local.pub_supernet_hub_nonprod,
    local.pub_supernet_dev,
    local.pub_supernet_qa
  )
}

resource "azurerm_network_security_rule" "baseline_deny_inbound_from_pub_supernet_hub" {
  for_each                    = (local.enable_s2s_effective && local.is_hrz && var.s2s_oneway_enable) ? local.workload_targets_hub : {}
  name                        = "baseline-deny-inbound-from-pub-supernet"
  priority                    = local.baseline_prio_interconnect_base + 10
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = local.pub_supernet_sources_effective
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_inbound_from_pub_supernet_dev" {
  provider                    = azurerm.dev
  for_each                    = (local.enable_s2s_effective && local.is_hrz && var.s2s_oneway_enable) ? local.workload_targets_dev : {}
  name                        = "baseline-deny-inbound-from-pub-supernet"
  priority                    = local.baseline_prio_interconnect_base + 10
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = local.pub_supernet_sources_effective
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_inbound_from_pub_supernet_qa" {
  provider                    = azurerm.qa
  for_each                    = (local.enable_s2s_effective && local.is_hrz && var.s2s_oneway_enable) ? local.workload_targets_qa : {}
  name                        = "baseline-deny-inbound-from-pub-supernet"
  priority                    = local.baseline_prio_interconnect_base + 10
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = local.pub_supernet_sources_effective
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_inbound_from_pub_supernet_prod" {
  provider                    = azurerm.prod
  for_each                    = (local.enable_s2s_effective && local.is_hrz && var.s2s_oneway_enable) ? local.workload_targets_prod : {}
  name                        = "baseline-deny-inbound-from-pub-supernet"
  priority                    = local.baseline_prio_interconnect_base + 10
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = local.pub_supernet_sources_effective
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_inbound_from_pub_supernet_uat" {
  provider                    = azurerm.uat
  for_each                    = (local.enable_s2s_effective && local.is_hrz && var.s2s_oneway_enable) ? local.workload_targets_uat : {}
  name                        = "baseline-deny-inbound-from-pub-supernet"
  priority                    = local.baseline_prio_interconnect_base + 10
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = local.pub_supernet_sources_effective
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# BASELINE EGRESS
# --- DNS to Azure (168.63.129.16) UDP + TCP fallback ---
resource "azurerm_network_security_rule" "baseline_allow_dns_udp_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "baseline-allow-dns-azure-udp"
  priority                    = local.baseline_prio_egress_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_tcp_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "baseline-allow-dns-azure-tcp"
  priority                    = local.baseline_prio_egress_base + 1
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_udp_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "baseline-allow-dns-azure-udp"
  priority                    = local.baseline_prio_egress_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_tcp_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "baseline-allow-dns-azure-tcp"
  priority                    = local.baseline_prio_egress_base + 1
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_udp_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "baseline-allow-dns-azure-udp"
  priority                    = local.baseline_prio_egress_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_tcp_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "baseline-allow-dns-azure-tcp"
  priority                    = local.baseline_prio_egress_base + 1
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_udp_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "baseline-allow-dns-azure-udp"
  priority                    = local.baseline_prio_egress_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_tcp_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "baseline-allow-dns-azure-tcp"
  priority                    = local.baseline_prio_egress_base + 1
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_udp_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "baseline-allow-dns-azure-udp"
  priority                    = local.baseline_prio_egress_base + 0
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_dns_tcp_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "baseline-allow-dns-azure-tcp"
  priority                    = local.baseline_prio_egress_base + 1
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# --- NTP to Azure (168.63.129.16) UDP/123 ---
resource "azurerm_network_security_rule" "baseline_allow_ntp_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "baseline-allow-ntp-azure"
  priority                    = local.baseline_prio_egress_base + 10
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_ntp_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "baseline-allow-ntp-azure"
  priority                    = local.baseline_prio_egress_base + 10
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_ntp_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "baseline-allow-ntp-azure"
  priority                    = local.baseline_prio_egress_base + 10
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_ntp_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "baseline-allow-ntp-azure"
  priority                    = local.baseline_prio_egress_base + 10
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_ntp_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "baseline-allow-ntp-azure"
  priority                    = local.baseline_prio_egress_base + 10
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# --- Storage egress (Service Tag: Storage) TCP/443 ---
resource "azurerm_network_security_rule" "baseline_allow_storage_egress_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "baseline-allow-storage-egress"
  priority                    = local.baseline_prio_egress_base + 30
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_storage_egress_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "baseline-allow-storage-egress"
  priority                    = local.baseline_prio_egress_base + 30
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_storage_egress_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "baseline-allow-storage-egress"
  priority                    = local.baseline_prio_egress_base + 30
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_storage_egress_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "baseline-allow-storage-egress"
  priority                    = local.baseline_prio_egress_base + 30
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_storage_egress_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "baseline-allow-storage-egress"
  priority                    = local.baseline_prio_egress_base + 30
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# --- Azure Monitor egress (Service Tag: AzureMonitor) TCP/443 ---
resource "azurerm_network_security_rule" "baseline_allow_azuremonitor_hub" {
  for_each                    = local.workload_targets_hub
  name                        = "baseline-allow-azuremonitor-egress"
  priority                    = local.baseline_prio_egress_base + 35
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_azuremonitor_dev" {
  provider                    = azurerm.dev
  for_each                    = local.workload_targets_dev
  name                        = "baseline-allow-azuremonitor-egress"
  priority                    = local.baseline_prio_egress_base + 35
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_azuremonitor_qa" {
  provider                    = azurerm.qa
  for_each                    = local.workload_targets_qa
  name                        = "baseline-allow-azuremonitor-egress"
  priority                    = local.baseline_prio_egress_base + 35
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_azuremonitor_prod" {
  provider                    = azurerm.prod
  for_each                    = local.workload_targets_prod
  name                        = "baseline-allow-azuremonitor-egress"
  priority                    = local.baseline_prio_egress_base + 35
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_allow_azuremonitor_uat" {
  provider                    = azurerm.uat
  for_each                    = local.workload_targets_uat
  name                        = "baseline-allow-azuremonitor-egress"
  priority                    = local.baseline_prio_egress_base + 35
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# BASELINE OUTBOUND DENY — DEFAULT INTERNET BLOCK
resource "azurerm_network_security_rule" "baseline_deny_all_to_internet_hub" {
  for_each                    = local.all_targets_hub
  name                        = "baseline-deny-to-internet"
  priority                    = local.baseline_deny_prio_base + 0
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
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_all_to_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.all_targets_dev
  name                        = "baseline-deny-to-internet"
  priority                    = local.baseline_deny_prio_base + 0
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
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_all_to_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.all_targets_qa
  name                        = "baseline-deny-to-internet"
  priority                    = local.baseline_deny_prio_base + 0
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
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_all_to_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.all_targets_prod
  name                        = "baseline-deny-to-internet"
  priority                    = local.baseline_deny_prio_base + 0
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
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "baseline_deny_all_to_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.all_targets_uat
  name                        = "baseline-deny-to-internet"
  priority                    = local.baseline_deny_prio_base + 0
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
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
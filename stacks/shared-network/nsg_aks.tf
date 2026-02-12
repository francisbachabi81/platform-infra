locals {
  aks_priority_band_base = 900

  aks_rule_name = {
    # Internet Egress
    egress_https_internet = "allow-aks-egress-https-internet"
    egress_http_internet  = "allow-aks-egress-http-internet"
    egress_acr            = "allow-aks-egress-acr"
    egress_servicebus     = "allow-aks-egress-servicebus"
    # Internet Ingress
    ingress_https_internet = "allow-aks-ingress-https-internet"
    # Intra-cluster Traffic
    intra_node_node_in  = "allow-aks-intra-node-to-node-in"
    intra_node_node_out = "allow-aks-intra-node-to-node-out"

    intra_pod_pod_in  = "allow-aks-intra-pod-to-pod-in"
    intra_pod_pod_out = "allow-aks-intra-pod-to-pod-out"

    intra_node_pod_in  = "allow-aks-intra-node-to-pod-in"
    intra_node_pod_out = "allow-aks-intra-node-to-pod-out"

    intra_node_svc_in  = "allow-aks-intra-node-to-service-in"
    intra_node_svc_out = "allow-aks-intra-node-to-service-out"

    intra_pod_svc_in  = "allow-aks-intra-pod-to-service-in"
    intra_pod_svc_out = "allow-aks-intra-pod-to-service-out"
  }

  # AKS egress targets (pods/aks subnets)
  aks_nsg_targets_struct = {
    for k in local.nsg_keys :
    k => { name = local.nsg_name_by_key[k], rg = local.nsg_rg_by_key[k] }
    if can(regex("-(aks${var.product})$", k))
  }
  aks_targets_hub  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^hub-", k)) }
  aks_targets_dev  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^dev-", k)) }
  aks_targets_qa   = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^qa-", k)) }
  aks_targets_prod = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^prod-", k)) }
  aks_targets_uat  = { for k, v in local.aks_nsg_targets_struct : k => v if can(regex("^uat-", k)) }

  aks_ingress_allowed_cidrs = local.is_nonprod ? var.aks_ingress_allowed_cidrs["nonprod"] : var.aks_ingress_allowed_cidrs["prod"]

  aks_targets_hub_edge_effective  = (local.is_nonprod || local.is_prod) ? local.aks_targets_hub : {}
  aks_targets_dev_edge_effective  = local.is_nonprod ? local.aks_targets_dev : {}
  aks_targets_qa_edge_effective   = local.is_nonprod ? local.aks_targets_qa : {}
  aks_targets_prod_edge_effective = local.is_prod ? local.aks_targets_prod : {}
  aks_targets_uat_edge_effective  = local.is_prod ? local.aks_targets_uat : {}

  aks_enabled_hub  = (local.is_nonprod || local.is_prod)
  aks_enabled_dev  = local.is_nonprod
  aks_enabled_qa   = local.is_nonprod
  aks_enabled_prod = local.is_prod
  aks_enabled_uat  = local.is_prod

  aks_cidrs_np = local.is_nonprod ? (
    lower(var.product) == "pub"
    ? {
      hub = { node = "172.10.2.0/24", pod = "172.210.0.0/16", svc = "172.110.0.0/16", dns = "172.110.0.10" }
      dev = { node = "172.11.2.0/24", pod = "172.211.0.0/16", svc = "172.111.0.0/16", dns = "172.111.0.10" }
      qa  = { node = "172.12.2.0/24", pod = "172.212.0.0/16", svc = "172.112.0.0/16", dns = "172.112.0.10" }
    }
    : {
      hub = { node = "10.10.2.0/24", pod = "10.210.0.0/16", svc = "10.110.0.0/16", dns = "10.110.0.10" }
      dev = { node = "10.11.2.0/24", pod = "10.211.0.0/16", svc = "10.111.0.0/16", dns = "10.111.0.10" }
      qa  = { node = "10.12.2.0/24", pod = "10.212.0.0/16", svc = "10.112.0.0/16", dns = "10.112.0.10" }
    }
  ) : null

  aks_cidrs_pr = local.is_prod ? (
    lower(var.product) == "pub"
    ? {
      hub  = { node = "172.13.2.0/24", pod = "172.213.0.0/16", svc = "172.113.0.0/16", dns = "172.113.0.10" }
      prod = { node = "172.14.2.0/24", pod = "172.214.0.0/16", svc = "172.114.0.0/16", dns = "172.114.0.10" }
      uat  = { node = "172.15.2.0/24", pod = "172.215.0.0/16", svc = "172.115.0.0/16", dns = "172.115.0.10" }
    }
    : {
      hub  = { node = "10.13.2.0/24", pod = "10.213.0.0/16", svc = "10.113.0.0/16", dns = "10.113.0.10" }
      prod = { node = "10.14.2.0/24", pod = "10.214.0.0/16", svc = "10.114.0.0/16", dns = "10.114.0.10" }
      uat  = { node = "10.15.2.0/24", pod = "10.215.0.0/16", svc = "10.115.0.0/16", dns = "10.115.0.10" }
    }
  ) : null

  aks_targets_hub_intra_effective  = local.aks_enabled_hub ? local.aks_targets_hub : {}
  aks_targets_dev_intra_effective  = local.aks_enabled_dev ? local.aks_targets_dev : {}
  aks_targets_qa_intra_effective   = local.aks_enabled_qa ? local.aks_targets_qa : {}
  aks_targets_prod_intra_effective = local.aks_enabled_prod ? local.aks_targets_prod : {}
  aks_targets_uat_intra_effective  = local.aks_enabled_uat ? local.aks_targets_uat : {}

  aks_cidrs_hub  = local.is_nonprod ? local.aks_cidrs_np.hub : (local.is_prod ? local.aks_cidrs_pr.hub : null)
  aks_cidrs_dev  = local.is_nonprod ? local.aks_cidrs_np.dev : null
  aks_cidrs_qa   = local.is_nonprod ? local.aks_cidrs_np.qa : null
  aks_cidrs_prod = local.is_prod ? local.aks_cidrs_pr.prod : null
  aks_cidrs_uat  = local.is_prod ? local.aks_cidrs_pr.uat : null

  privatelink_subnet_cidrs_np = local.is_nonprod ? (
    lower(var.product) == "pub"
    ? { dev = "172.11.30.0/24", qa = "172.12.30.0/24" }
    : { dev = "10.11.30.0/24", qa = "10.12.30.0/24" }
  ) : null

  privatelink_subnet_cidrs_pr = local.is_prod ? (
    lower(var.product) == "pub"
    ? { prod = "172.14.30.0/24", uat = "172.15.30.0/24" }
    : { prod = "10.14.30.0/24", uat = "10.15.30.0/24" }
  ) : null

  pgflex_subnet_cidrs_np = local.is_nonprod ? (
    lower(var.product) == "pub"
    ? { dev = "172.11.3.0/24", qa = "172.12.3.0/24" }
    : { dev = "10.11.3.0/24", qa = "10.12.3.0/24" }
  ) : null

  pgflex_subnet_cidrs_pr = local.is_prod ? (
    lower(var.product) == "pub"
    ? { prod = "172.14.3.0/24", uat = "172.15.3.0/24" }
    : { prod = "10.14.3.0/24", uat = "10.15.3.0/24" }
  ) : null

  aks_hub_node_cidr = local.is_nonprod ? local.aks_cidrs_np.hub.node : (local.is_prod ? local.aks_cidrs_pr.hub.node : null)

  aks_hub_to_privatelink_cidrs = local.is_nonprod ? local.privatelink_subnet_cidrs_np : (local.is_prod ? local.privatelink_subnet_cidrs_pr : {})
  aks_hub_to_pgflex_cidrs      = local.is_nonprod ? local.pgflex_subnet_cidrs_np : (local.is_prod ? local.pgflex_subnet_cidrs_pr : {})

  aks_rule_priority = {
    # ingress
    ingress_https_internet = local.aks_priority_band_base + 0 # 900

    # intra (same order as before)
    intra_node_node = local.aks_priority_band_base + 10 # 910
    intra_pod_pod   = local.aks_priority_band_base + 11 # 911
    intra_node_pod  = local.aks_priority_band_base + 12 # 912
    intra_node_svc  = local.aks_priority_band_base + 13 # 913
    intra_pod_svc   = local.aks_priority_band_base + 14 # 914
    intra_dns_udp   = local.aks_priority_band_base + 15 # 915

    # edge egress (same order as before)
    egress_https_internet = local.aks_priority_band_base + 40 # 940
    egress_http_internet  = local.aks_priority_band_base + 41 # 941
    egress_acr            = local.aks_priority_band_base + 42 # 942
    egress_servicebus     = local.aks_priority_band_base + 43 # 943
    egress_smtp_465       = local.aks_priority_band_base + 44 # 944
  }

  # Hub AKS -> PrivateLink subnet egress priorities (per env)
  # (kept in the same relative ordering as your previous 350/351)
  aks_hub_to_privatelink_priority = local.is_nonprod ? {
    dev = local.aks_priority_band_base + 50 # 950
    qa  = local.aks_priority_band_base + 51 # 951
    } : {
    prod = local.aks_priority_band_base + 50 # 950
    uat  = local.aks_priority_band_base + 51 # 951
  }

  # Per-plane “same-env” AKS -> PrivateLink priorities (dev/qa/prod/uat)
  # (kept in the same relative ordering as your previous 352/353)
  aks_plane_to_privatelink_priority = {
    dev  = local.aks_priority_band_base + 52 # 952
    qa   = local.aks_priority_band_base + 53 # 953
    prod = local.aks_priority_band_base + 52 # 952
    uat  = local.aks_priority_band_base + 53 # 953
  }

  # Hub AKS -> PGFlex priorities (per env)
  # (kept in the same relative ordering as your previous 360/361)
  aks_hub_to_pgflex_priority = local.is_nonprod ? {
    dev = local.aks_priority_band_base + 60 # 960
    qa  = local.aks_priority_band_base + 61 # 961
    } : {
    prod = local.aks_priority_band_base + 60 # 960
    uat  = local.aks_priority_band_base + 61 # 961
  }

  # Per-plane “same-env” AKS -> PGFlex priorities (dev/qa/prod/uat)
  # (kept in the same relative ordering as your previous 362/363)
  aks_plane_to_pgflex_priority = {
    dev  = local.aks_priority_band_base + 62 # 962
    qa   = local.aks_priority_band_base + 63 # 963
    prod = local.aks_priority_band_base + 62 # 962
    uat  = local.aks_priority_band_base + 63 # 963
  }
}

# AKS egress (plane-aware per subscription) ────────────────────────────
resource "azurerm_network_security_rule" "aks_allow_https_internet_hub" {
  #  provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = local.aks_rule_name.egress_https_internet
  priority                    = local.aks_rule_priority.egress_https_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = local.aks_rule_name.egress_https_internet
  priority                    = local.aks_rule_priority.egress_https_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = local.aks_rule_name.egress_https_internet
  priority                    = local.aks_rule_priority.egress_https_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = local.aks_rule_name.egress_https_internet
  priority                    = local.aks_rule_priority.egress_https_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = local.aks_rule_name.egress_https_internet
  priority                    = local.aks_rule_priority.egress_https_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_hub" {
  #  provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = local.aks_rule_name.egress_http_internet
  priority                    = local.aks_rule_priority.egress_http_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = local.aks_rule_name.egress_http_internet
  priority                    = local.aks_rule_priority.egress_http_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = local.aks_rule_name.egress_http_internet
  priority                    = local.aks_rule_priority.egress_http_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = local.aks_rule_name.egress_http_internet
  priority                    = local.aks_rule_priority.egress_http_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_http_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = local.aks_rule_name.egress_http_internet
  priority                    = local.aks_rule_priority.egress_http_internet
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_hub" {
  #  provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = local.aks_rule_name.egress_acr
  priority                    = local.aks_rule_priority.egress_acr
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = local.aks_rule_name.egress_acr
  priority                    = local.aks_rule_priority.egress_acr
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = local.aks_rule_name.egress_acr
  priority                    = local.aks_rule_priority.egress_acr
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = local.aks_rule_name.egress_acr
  priority                    = local.aks_rule_priority.egress_acr
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_acr_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = local.aks_rule_name.egress_acr
  priority                    = local.aks_rule_priority.egress_acr
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_hub" {
  #  provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = local.aks_rule_name.egress_servicebus
  priority                    = local.aks_rule_priority.egress_servicebus
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = local.aks_rule_name.egress_servicebus
  priority                    = local.aks_rule_priority.egress_servicebus
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = local.aks_rule_name.egress_servicebus
  priority                    = local.aks_rule_priority.egress_servicebus
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = local.aks_rule_name.egress_servicebus
  priority                    = local.aks_rule_priority.egress_servicebus
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_servicebus_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = local.aks_rule_name.egress_servicebus
  priority                    = local.aks_rule_priority.egress_servicebus
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5671"
  source_address_prefix       = "*"
  destination_address_prefix  = "ServiceBus"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# AKS -> PrivateLink subnet egress (hub AKS NSGs only) ─────────────────────────
locals {
  aks_privatelink_rule_items = [
    for pair in setproduct(
      keys(local.aks_targets_hub_edge_effective),
      keys(local.aks_hub_to_privatelink_cidrs)
      ) : {
      key        = "${pair[0]}-${pair[1]}"
      target_key = pair[0]
      env        = pair[1]
      target     = local.aks_targets_hub_edge_effective[pair[0]]
      dest_cidr  = local.aks_hub_to_privatelink_cidrs[pair[1]]
    }
  ]

  aks_privatelink_rule_map = {
    for i in local.aks_privatelink_rule_items : i.key => i
  }

  aks_pgflex_rule_items = [
    for pair in setproduct(
      keys(local.aks_targets_hub_edge_effective),
      keys(local.aks_hub_to_pgflex_cidrs)
      ) : {
      key        = "${pair[0]}-${pair[1]}"
      target_key = pair[0]
      env        = pair[1]
      target     = local.aks_targets_hub_edge_effective[pair[0]]
      dest_cidr  = local.aks_hub_to_pgflex_cidrs[pair[1]]
    }
  ]

  aks_pgflex_rule_map = {
    for i in local.aks_pgflex_rule_items : i.key => i
  }
}

resource "azurerm_network_security_rule" "aks_allow_hub_to_privatelink_any_out" {
  for_each = local.aks_privatelink_rule_map

  name                        = "allow-aks-to-${each.value.env}-privatelink-any-out"
  priority                    = local.aks_hub_to_privatelink_priority[each.value.env]
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_hub_node_cidr
  destination_address_prefix  = each.value.dest_cidr
  resource_group_name         = each.value.target.rg
  network_security_group_name = each.value.target.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_hub_to_pgflex_5432_out" {
  for_each = local.aks_pgflex_rule_map

  name                        = "allow-aks-to-${each.value.env}-pgflex-5432-out"
  priority                    = local.aks_hub_to_pgflex_priority[each.value.env]
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = local.aks_hub_node_cidr
  destination_address_prefix  = each.value.dest_cidr
  resource_group_name         = each.value.target.rg
  network_security_group_name = each.value.target.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_dev_to_dev_privatelink_any_out" {
  provider = azurerm.dev
  for_each = local.aks_targets_dev_edge_effective

  name                        = "allow-aks-to-dev-privatelink-any-out"
  priority                    = local.aks_plane_to_privatelink_priority.dev
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.privatelink_subnet_cidrs_np.dev
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_dev_to_dev_pgflex_5432_out" {
  provider = azurerm.dev
  for_each = local.aks_targets_dev_edge_effective

  name                        = "allow-aks-to-dev-pgflex-5432-out"
  priority                    = local.aks_plane_to_pgflex_priority.dev
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.pgflex_subnet_cidrs_np.dev
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_qa_to_qa_privatelink_any_out" {
  provider = azurerm.qa
  for_each = local.aks_targets_qa_edge_effective

  name                        = "allow-aks-to-qa-privatelink-any-out"
  priority                    = local.aks_plane_to_privatelink_priority.qa
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.privatelink_subnet_cidrs_np.qa
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_qa_to_qa_pgflex_5432_out" {
  provider = azurerm.qa
  for_each = local.aks_targets_qa_edge_effective

  name                        = "allow-aks-to-qa-pgflex-5432-out"
  priority                    = local.aks_plane_to_pgflex_priority.qa
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.pgflex_subnet_cidrs_np.qa
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_prod_to_prod_privatelink_any_out" {
  provider = azurerm.prod
  for_each = local.aks_targets_prod_edge_effective

  name                        = "allow-aks-to-prod-privatelink-any-out"
  priority                    = local.aks_plane_to_privatelink_priority.prod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.privatelink_subnet_cidrs_pr.prod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_prod_to_prod_pgflex_5432_out" {
  provider = azurerm.prod
  for_each = local.aks_targets_prod_edge_effective

  name                        = "allow-aks-to-prod-pgflex-5432-out"
  priority                    = local.aks_plane_to_pgflex_priority.prod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.pgflex_subnet_cidrs_pr.prod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_uat_to_uat_privatelink_any_out" {
  provider = azurerm.uat
  for_each = local.aks_targets_uat_edge_effective

  name                        = "allow-aks-to-uat-privatelink-any-out"
  priority                    = local.aks_plane_to_privatelink_priority.uat
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.privatelink_subnet_cidrs_pr.uat
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_uat_to_uat_pgflex_5432_out" {
  provider = azurerm.uat
  for_each = local.aks_targets_uat_edge_effective

  name                        = "allow-aks-to-uat-pgflex-5432-out"
  priority                    = local.aks_plane_to_pgflex_priority.uat
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.pgflex_subnet_cidrs_pr.uat
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# AKS ingress (plane-aware per subscription)
resource "azurerm_network_security_rule" "aks_allow_https_from_internet_hub" {
  #  provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = local.aks_rule_name.ingress_https_internet
  priority                    = local.aks_rule_priority.ingress_https_internet
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = local.aks_rule_name.ingress_https_internet
  priority                    = local.aks_rule_priority.ingress_https_internet
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = local.aks_rule_name.ingress_https_internet
  priority                    = local.aks_rule_priority.ingress_https_internet
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = local.aks_rule_name.ingress_https_internet
  priority                    = local.aks_rule_priority.ingress_https_internet
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_https_from_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = local.aks_rule_name.ingress_https_internet
  priority                    = local.aks_rule_priority.ingress_https_internet
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.aks_ingress_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# AKS intra-cluster allow rules (hub + dev + qa + prod + uat)
# HUB
resource "azurerm_network_security_rule" "aks_hub_allow_node_to_node_in" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_node_in
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_node_to_node_out" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_node_out
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_pod_to_pod_in" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_in
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.pod
  destination_address_prefix  = local.aks_cidrs_hub.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_pod_to_pod_out" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_out
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.pod
  destination_address_prefix  = local.aks_cidrs_hub.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_node_to_pod_in" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_in
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_node_to_pod_out" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_out
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_node_to_svc_in" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_in
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_node_to_svc_out" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_out
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = local.aks_cidrs_hub.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_pod_to_svc_in" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_in
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.pod
  destination_address_prefix  = local.aks_cidrs_hub.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_hub_allow_pod_to_svc_out" {
  for_each                    = local.aks_targets_hub_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_out
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_hub.pod
  destination_address_prefix  = local.aks_cidrs_hub.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# DEV
resource "azurerm_network_security_rule" "aks_dev_allow_node_to_node_in" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_node_in
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_node_to_node_out" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_node_out
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_pod_to_pod_in" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_in
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.pod
  destination_address_prefix  = local.aks_cidrs_dev.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_pod_to_pod_out" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_out
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.pod
  destination_address_prefix  = local.aks_cidrs_dev.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_node_to_pod_in" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_in
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_node_to_pod_out" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_out
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_node_to_svc_in" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_in
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_node_to_svc_out" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_out
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = local.aks_cidrs_dev.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_pod_to_svc_in" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_in
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.pod
  destination_address_prefix  = local.aks_cidrs_dev.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_dev_allow_pod_to_svc_out" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_out
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_dev.pod
  destination_address_prefix  = local.aks_cidrs_dev.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# QA
resource "azurerm_network_security_rule" "aks_qa_allow_node_to_node_in" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_node_in
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_node_to_node_out" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_node_out
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_pod_to_pod_in" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_in
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.pod
  destination_address_prefix  = local.aks_cidrs_qa.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_pod_to_pod_out" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_out
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.pod
  destination_address_prefix  = local.aks_cidrs_qa.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_node_to_pod_in" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_in
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_node_to_pod_out" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_out
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_node_to_svc_in" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_in
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_node_to_svc_out" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_out
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = local.aks_cidrs_qa.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_pod_to_svc_in" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_in
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.pod
  destination_address_prefix  = local.aks_cidrs_qa.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_qa_allow_pod_to_svc_out" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_out
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_qa.pod
  destination_address_prefix  = local.aks_cidrs_qa.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# PROD
resource "azurerm_network_security_rule" "aks_prod_allow_node_to_node_in" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_node_in
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_node_to_node_out" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_node_out
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_pod_to_pod_in" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_in
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.pod
  destination_address_prefix  = local.aks_cidrs_prod.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_pod_to_pod_out" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_out
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.pod
  destination_address_prefix  = local.aks_cidrs_prod.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_node_to_pod_in" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_in
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_node_to_pod_out" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_out
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_node_to_svc_in" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_in
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_node_to_svc_out" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_out
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = local.aks_cidrs_prod.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_pod_to_svc_in" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_in
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.pod
  destination_address_prefix  = local.aks_cidrs_prod.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_prod_allow_pod_to_svc_out" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_out
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_prod.pod
  destination_address_prefix  = local.aks_cidrs_prod.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# UAT
resource "azurerm_network_security_rule" "aks_uat_allow_node_to_node_in" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_node_in
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_node_to_node_out" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_node_out
  priority                    = local.aks_rule_priority.intra_node_node
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.node
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_pod_to_pod_in" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_in
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.pod
  destination_address_prefix  = local.aks_cidrs_uat.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_pod_to_pod_out" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_pod_pod_out
  priority                    = local.aks_rule_priority.intra_pod_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.pod
  destination_address_prefix  = local.aks_cidrs_uat.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_node_to_pod_in" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_in
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_node_to_pod_out" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_pod_out
  priority                    = local.aks_rule_priority.intra_node_pod
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.pod
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_node_to_svc_in" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_in
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_node_to_svc_out" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_node_svc_out
  priority                    = local.aks_rule_priority.intra_node_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = local.aks_cidrs_uat.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_pod_to_svc_in" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_in
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.pod
  destination_address_prefix  = local.aks_cidrs_uat.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_uat_allow_pod_to_svc_out" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_intra_effective
  name                        = local.aks_rule_name.intra_pod_svc_out
  priority                    = local.aks_rule_priority.intra_pod_svc
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.aks_cidrs_uat.pod
  destination_address_prefix  = local.aks_cidrs_uat.svc
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name
  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

# AKS -> Internet (SMTP over TLS) egress (plane-aware per subscription) ─────────
resource "azurerm_network_security_rule" "aks_allow_smtp_465_internet_hub" {
  # provider                    = azurerm.hub
  for_each                    = local.aks_targets_hub_edge_effective
  name                        = "allow-aks-smtp-465-internet"
  priority                    = local.aks_rule_priority.egress_smtp_465
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "465"
  source_address_prefix       = local.aks_cidrs_hub.node
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_smtp_465_internet_dev" {
  provider                    = azurerm.dev
  for_each                    = local.aks_targets_dev_edge_effective
  name                        = "allow-aks-smtp-465-internet"
  priority                    = local.aks_rule_priority.egress_smtp_465
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "465"
  source_address_prefix       = local.aks_cidrs_dev.node
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_smtp_465_internet_qa" {
  provider                    = azurerm.qa
  for_each                    = local.aks_targets_qa_edge_effective
  name                        = "allow-aks-smtp-465-internet"
  priority                    = local.aks_rule_priority.egress_smtp_465
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "465"
  source_address_prefix       = local.aks_cidrs_qa.node
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_smtp_465_internet_prod" {
  provider                    = azurerm.prod
  for_each                    = local.aks_targets_prod_edge_effective
  name                        = "allow-aks-smtp-465-internet"
  priority                    = local.aks_rule_priority.egress_smtp_465
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "465"
  source_address_prefix       = local.aks_cidrs_prod.node
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}

resource "azurerm_network_security_rule" "aks_allow_smtp_465_internet_uat" {
  provider                    = azurerm.uat
  for_each                    = local.aks_targets_uat_edge_effective
  name                        = "allow-aks-smtp-465-internet"
  priority                    = local.aks_rule_priority.egress_smtp_465
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "465"
  source_address_prefix       = local.aks_cidrs_uat.node
  destination_address_prefix  = "Internet"
  resource_group_name         = each.value.rg
  network_security_group_name = each.value.name

  depends_on = [
    module.rg_hub, module.rg_dev, module.rg_qa, module.rg_prod, module.rg_uat,
    module.nsg_hub, module.nsg_dev, module.nsg_qa, module.nsg_prod, module.nsg_uat
  ]
}
locals {

  prio_appgw_base = 200

  nonprod_hub_cidrs = try(var.nonprod_hub.cidrs, [])
  dev_spoke_cidrs   = try(var.dev_spoke.cidrs, [])
  qa_spoke_cidrs    = try(var.qa_spoke.cidrs, [])

  prod_hub_cidrs   = try(var.prod_hub.cidrs, [])
  prod_spoke_cidrs = try(var.prod_spoke.cidrs, [])
  uat_spoke_cidrs  = try(var.uat_spoke.cidrs, [])

  appgw_allowed_vnet_ingress_cidrs = distinct(
    compact(
      flatten(
        local.lane == "nonprod"
        ? [local.nonprod_hub_cidrs, local.dev_spoke_cidrs, local.qa_spoke_cidrs]
        : [local.prod_hub_cidrs, local.prod_spoke_cidrs, local.uat_spoke_cidrs]
      )
    )
  )

  appgw_ingress_allowlist_vnet_cidrs = (
    local.is_hrz && local.lane == "nonprod" ? [
      "10.10.14.0/24",
    ] :
    local.is_hrz && local.lane == "prod" ? [
      "10.13.14.0/24",
    ] :
    var.product == "pub" && local.lane == "nonprod" ? [
      "172.10.14.0/24",
    ] :
    var.product == "pub" && local.lane == "prod" ? [
      "172.13.14.0/24",
    ] :
    []
  )

  appgw_allow_scoped_vnet_ingress = local.appgw_enabled && length(local.appgw_allowed_vnet_ingress_cidrs) > 0

  appgw_pl_subnet_cidr = (
  var.product == "pub" ? (local.lane == "nonprod" ? "172.10.40.32/27" : "172.13.40.32/27") : (local.lane == "nonprod" ? "10.10.40.32/27" : "10.13.40.32/27"))
}

resource "azurerm_network_security_rule" "appgw_allow_gwmgr" {
  count                       = length(azurerm_network_security_group.appgw_nsg)
  name                        = "allow-gwmgr-65200-65535"
  priority                    = local.prio_appgw_base + 0
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

# Allow Azure platform load balancer probes / infrastructure traffic
resource "azurerm_network_security_rule" "appgw_allow_azure_load_balancer_to_vnet" {
  count                       = local.appgw_enabled ? 1 : 0
  name                        = "allow-azureloadbalancer-to-vnet"
  priority                    = local.prio_appgw_base + 10
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_https_public_test" {
  count                  = local.appgw_enabled ? 1 : 0
  name                   = "allow-https-public-transitional"
  priority               = local.prio_appgw_base + 12
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = "443"
  # source_address_prefixes     = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http_public_test" {
  count                  = local.appgw_enabled ? 1 : 0
  name                   = "allow-http-public-transitional"
  priority               = local.prio_appgw_base + 13
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = "80"
  # source_address_prefixes     = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

# Allow direct access from VPN CIDR (admin/test) — higher priority than service ingress
resource "azurerm_network_security_rule" "appgw_allow_https_from_vpn" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-https-from-vpn"
  priority                    = local.prio_appgw_base + 20
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "192.168.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http_from_vpn" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-http-from-vpn"
  priority                    = local.prio_appgw_base + 25
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "192.168.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

# Allow AFD Private Endpoint / internal ingress subnet
resource "azurerm_network_security_rule" "appgw_allow_https_from_appgw_pl_subnet" {
  count                       = local.appgw_enabled ? 1 : 0
  name                        = "allow-https-from-appgw-pl-subnet"
  priority                    = local.prio_appgw_base + 30
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = local.appgw_pl_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http_from_appgw_pl_subnet" {
  count                       = local.appgw_enabled ? 1 : 0
  name                        = "allow-http-from-appgw-pl-subnet"
  priority                    = local.prio_appgw_base + 35
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = local.appgw_pl_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

# Allow Azure Front Door to reach the public AppGW frontend (service-tag based)
resource "azurerm_network_security_rule" "appgw_allow_https_public" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-https-from-afd-backend"
  priority                    = local.prio_appgw_base + 40
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http_public" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "allow-http-from-afd-backend"
  priority                    = local.prio_appgw_base + 45
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_https_from_allowed_vnets" {
  count                       = local.appgw_allow_scoped_vnet_ingress ? 1 : 0
  name                        = "allow-https-from-allowed-vnets"
  priority                    = local.prio_appgw_base + 60
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = local.appgw_ingress_allowlist_vnet_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

# Deny VNet callers to AppGW listeners unless explicitly allowed above
resource "azurerm_network_security_rule" "appgw_deny_https_from_vnet_other" {
  count                       = local.appgw_enabled ? 1 : 0
  name                        = "deny-https-from-vnet-other"
  priority                    = local.prio_appgw_base + 90
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_deny_http_from_vnet_other" {
  count                       = local.appgw_enabled ? 1 : 0
  name                        = "deny-http-from-vnet-other"
  priority                    = local.prio_appgw_base + 91
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_deny_https_other" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "deny-https-other"
  priority                    = local.prio_appgw_base + 95
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_network_security_rule" "appgw_deny_http_other" {
  count                       = local.appgw_enabled && var.appgw_public_ip_enabled ? 1 : 0
  name                        = "deny-http-other"
  priority                    = local.prio_appgw_base + 96
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.appgw_nsg[0].resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg[0].name
}

resource "azurerm_subnet_network_security_group_association" "appgw_assoc" {
  count                     = local.appgw_enabled ? 1 : 0
  subnet_id                 = local.appgw_subnet_id
  network_security_group_id = azurerm_network_security_group.appgw_nsg[0].id

  depends_on = [
    azurerm_network_security_group.appgw_nsg[0]
  ]
}
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# locals
locals {
  _p2s_tenant_id       = coalesce(var.p2s_aad_tenant_id_override, var.tenant_id)

  _audience_by_env = {
    public       = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
    usgovernment = "51bb15d4-3a4f-4ebf-9dca-40096fe32426"
  }

  _login_host_by_env = {
    public       = "login.microsoftonline.com"
    usgovernment = "login.microsoftonline.us"
  }

  _issuer_host_default = "sts.windows.net"

  p2s_aad_tenant_uri = (
    var.p2s_aad_tenant_uri_override != null && trimspace(var.p2s_aad_tenant_uri_override) != ""
  ) ? var.p2s_aad_tenant_uri_override : "https://${lookup(local._login_host_by_env, var.azure_environment)}/${local._p2s_tenant_id}"

  p2s_aad_issuer_uri = (
    var.p2s_aad_issuer_uri_override != null && trimspace(var.p2s_aad_issuer_uri_override) != ""
  ) ? "${trimsuffix(trimspace(var.p2s_aad_issuer_uri_override), "/")}/" : "https://sts.windows.net/${local._p2s_tenant_id}/"

  p2s_aad_audience = coalesce(
    var.p2s_aad_audience_override,
    lookup(local._audience_by_env, var.azure_environment)
  )

  use_managed_pip      = var.create_public_ip
  effective_public_ip_id = var.create_public_ip ? azurerm_public_ip.pip["main"].id : var.public_ip_id
}

# managed public ip (optional)
resource "azurerm_public_ip" "pip" {
  for_each            = local.use_managed_pip ? toset(["main"]) : []
  name                = coalesce(var.public_ip_name, "${var.name}-pip")
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# vpn gateway
resource "azurerm_virtual_network_gateway" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.sku
  active_active       = false
  enable_bgp          = false

  ip_configuration {
    name                          = "vpngipc"
    public_ip_address_id          = local.effective_public_ip_id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  dynamic "vpn_client_configuration" {
    for_each = var.p2s_enable ? [1] : []
    content {
      address_space        = var.p2s_address_space
      vpn_client_protocols = var.p2s_vpn_client_protocols
      vpn_auth_types       = var.p2s_vpn_auth_types
      aad_tenant           = contains(var.p2s_vpn_auth_types, "AAD") ? local.p2s_aad_tenant_uri : null
      aad_issuer           = contains(var.p2s_vpn_auth_types, "AAD") ? local.p2s_aad_issuer_uri : null
      aad_audience         = contains(var.p2s_vpn_auth_types, "AAD") ? local.p2s_aad_audience   : null
    }
  }

  lifecycle {
    precondition {
      condition     = var.create_public_ip || var.public_ip_id != null
      error_message = "either set create_public_ip = true or provide public_ip_id."
    }
    precondition {
      condition     = !(var.create_public_ip && var.public_ip_id != null)
      error_message = "do not set create_public_ip = true and public_ip_id simultaneously."
    }
  }

  tags = var.tags
}
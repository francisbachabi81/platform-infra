terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_public_ip" "pip" {
  count               = (var.public_ip_enabled && var.public_ip_id == null) ? 1 : 0
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

locals {
  resolved_public_ip_id = var.public_ip_enabled ? (var.public_ip_id != null ? var.public_ip_id : azurerm_public_ip.pip[0].id) : null
}

resource "azurerm_application_gateway" "agw" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  gateway_ip_configuration {
    name      = "agwipc"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name = "feip"

    public_ip_address_id        = var.public_ip_enabled ? local.resolved_public_ip_id : null
    private_ip_address_allocation = var.public_ip_enabled ? null : var.private_ip_allocation
    private_ip_address            = var.public_ip_enabled ? null : var.private_ip_address
    subnet_id                     = var.public_ip_enabled ? null : var.subnet_id
  }

  frontend_port {
    name = "feport-80"
    port = 80
  }

  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "feip"
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    firewall_policy_id             = var.waf_policy_id
  }

  backend_address_pool {
    name = "default-bepool"
  }

  backend_http_settings {
    name                  = "bhs-http"
    protocol              = "Http"
    port                  = 80
    request_timeout       = 20
    cookie_based_affinity = var.cookie_based_affinity
  }

  request_routing_rule {
    name                       = "rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "default-bepool"
    backend_http_settings_name = "bhs-http"
    priority                   = var.rule_priority
  }

  lifecycle {
    precondition {
      condition = !(
        var.public_ip_enabled == false &&
        var.private_ip_allocation == "Static" &&
        (var.private_ip_address == null || var.private_ip_address == "")
      )
      error_message = "when using a private static fe ip, you must set private_ip_address."
    }
  }

  tags = var.tags
}
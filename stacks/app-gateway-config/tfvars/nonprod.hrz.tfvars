product = "hrz"
plane   = "nonprod"

location = "USGov Arizona"
region   = "usaz"

tags = {
  purpose = "appgw-config"
  plane   = "nonprod"
}

shared_network_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  # keep if you want, but main.tf uses the computed key; this field is unused in your snippet
  key                  = "shared-network/hrz/usaz/np.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/hrz/usaz/np.tfstate"
}

# SSL cert in Key Vault (must be a SECRET that contains PFX)
ssl_secret_name      = "appgw-gateway-cert-horizon-nonprod"
ssl_secret_version   = null
ssl_certificate_name = "appgw-gateway-cert-horizon-nonprod"

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-dev = { ip_addresses = ["62.10.212.49"] }
  bepool-qa  = { ip_addresses = ["62.10.212.50"] }
}

probes = {
  probe-dev = {
    protocol            = "Https"
    host                = "dev.horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-qa = {
    protocol            = "Https"
    host                = "qa.horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }
}

backend_http_settings = {
  bhs-dev-https = {
    port                = 443
    protocol            = "Https"
    request_timeout     = 20
    cookie_based_affinity = "Disabled"
    probe_name          = "probe-dev"
    host_name           = "dev.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-qa-https = {
    port                = 443
    protocol            = "Https"
    request_timeout     = 20
    cookie_based_affinity = "Disabled"
    probe_name          = "probe-qa"
    host_name           = "qa.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }
}

listeners = {
  listener-dev-http = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.horizon.intterra.io"
    frontend_ip_configuration_name = "feip"
  }
  listener-dev-https = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-nonprod"
    require_sni                    = true
    frontend_ip_configuration_name = "feip"
  }

  listener-qa-http = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "qa.horizon.intterra.io"
    frontend_ip_configuration_name = "feip"
  }
  listener-qa-https = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "qa.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-nonprod"
    require_sni                    = true
    frontend_ip_configuration_name = "feip"
  }
}

redirect_configurations = {
  redir-dev-http-to-https = {
    target_listener_name = "listener-dev-https"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-qa-http-to-https = {
    target_listener_name = "listener-qa-https"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }
}

routing_rules = [
  # dev
  {
    name                        = "rule-dev-http-redirect"
    priority                    = 90
    http_listener_name          = "listener-dev-http"
    redirect_configuration_name = "redir-dev-http-to-https"
  },
  {
    name                       = "rule-dev-https"
    priority                   = 100
    http_listener_name         = "listener-dev-https"
    backend_address_pool_name  = "bepool-dev"
    backend_http_settings_name = "bhs-dev-https"
  },

  # qa
  {
    name                        = "rule-qa-http-redirect"
    priority                    = 190
    http_listener_name          = "listener-qa-http"
    redirect_configuration_name = "redir-qa-http-to-https"
  },
  {
    name                       = "rule-qa-https"
    priority                   = 200
    http_listener_name         = "listener-qa-https"
    backend_address_pool_name  = "bepool-qa"
    backend_http_settings_name = "bhs-qa-https"
  }
]
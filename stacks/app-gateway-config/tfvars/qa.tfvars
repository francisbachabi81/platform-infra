product = "hrz"
env     = "qa"

tags = {
  purpose = "appgw-config"
  env     = "qa"
}

shared_network_state = {
  resource_group_name  = "rg-STATE"
  storage_account_name = "stterraformstate"
  container_name       = "tfstate"
  key                  = "shared-network/qa.hrz.tfstate"
}

# Optional: only needed if shared-network is not already outputting appgw_ssl_key_vault
# core_state = {
#   resource_group_name  = "rg-STATE"
#   storage_account_name = "stterraformstate"
#   container_name       = "tfstate"
#   key                  = "platform-app/qa.hrz.tfstate"
# }

# SSL cert in Key Vault
ssl_secret_name        = "agw-qa-cert"        # secret name containing the PFX
ssl_secret_version     = null                  # latest
ssl_certificate_name   = "kv-ssl"              # name inside AGW

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-api = {
    fqdns = ["api-qa.internal.contoso.local"]
  }
}

probes = {
  probe-api = {
    protocol            = "Http"
    host                = "api-qa.internal.contoso.local"
    path                = "/healthz"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }
}

backend_http_settings = {
  bhs-api = {
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-api"
    pick_host_name_from_backend_address = false
  }
}

listeners = {
  listener-http = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "qa.example.com"
    frontend_ip_configuration_name = "feip"
  }
  listener-https = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "qa.example.com"
    ssl_certificate_name           = "kv-ssl"
    require_sni                    = true
    frontend_ip_configuration_name = "feip"
  }
}

routing_rules = [
  {
    name                       = "rule-https"
    priority                   = 100
    http_listener_name         = "listener-https"
    backend_address_pool_name  = "bepool-api"
    backend_http_settings_name = "bhs-api"
  }
]

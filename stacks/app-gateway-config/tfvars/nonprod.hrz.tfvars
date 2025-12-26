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
  key                  = "shared-network/hrz/usaz/np.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/hrz/usaz/np.tfstate"
}

waf_policies = {
  dev = {
    mode             = "Prevention"
    vpn_cidrs        = ["192.168.1.0/24"]
    restricted_paths = ["/admin"]
    blocked_countries = ["CN", "RU", "IR"] #https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md
  }
  # qa = {
  #   mode             = "Prevention"
  #   vpn_cidrs        = ["192.168.1.0/24"]
  #   restricted_paths = ["/admin", "/ops"]
  # }
}

# only one sslCertificates[] element, but multiple HTTPS listeners can reference it
# ssl_certificates = {
#   appgw-gateway-cert-horizon-dev = {
#     secret_name    = "appgw-gateway-cert-horizon-dev" # or whatever your wildcard secret is - wildcard-horizon-intterra-io
#     # secret_version = null
#   }
# }

# (Distinct cert per listener): Use different Key Vault secrets
ssl_certificates = {
  appgw-gateway-cert-horizon-dev = {
    secret_name    = "appgw-gateway-cert-horizon-dev"
    secret_version = null
  }

  # appgw-gateway-cert-horizon-qa = {
  #   secret_name    = "appgw-gateway-cert-horizon-dev"
  #   secret_version = null
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-dev = { ip_addresses = ["62.10.212.49"] }
  # bepool-qa  = { ip_addresses = ["62.10.212.50"] }
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

  # probe-qa = {
  #   protocol            = "Https"
  #   host                = "qa.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
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

  # bhs-qa-https = {
  #   port                = 443
  #   protocol            = "Https"
  #   request_timeout     = 20
  #   cookie_based_affinity = "Disabled"
  #   probe_name          = "probe-qa"
  #   host_name           = "qa.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  # PUBLIC
  listener-dev-http-public = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.horizon.intterra.io"
    frontend                       = "public"
    waf_policy_key                 = "dev"
  }

  listener-dev-https-public = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-dev"
    require_sni                    = true
    frontend                       = "public"
    waf_policy_key                 = "dev"
  }

  # PRIVATE
  listener-dev-http-private = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.horizon.intterra.io"
    frontend                       = "private"
    waf_policy_key                 = "dev"
  }

  listener-dev-https-private = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-dev"
    require_sni                    = true
    frontend                       = "private"
    waf_policy_key                 = "dev"
  }

  # listener-qa-http = {
  #   frontend_port_name             = "feport-80"
  #   protocol                       = "Http"
  #   host_name                      = "qa.horizon.intterra.io"
  #   frontend_ip_configuration_name = "feip"
  # }
  # listener-qa-https = {
  #   frontend_port_name             = "feport-443"
  #   protocol                       = "Https"
  #   host_name                      = "qa.horizon.intterra.io"
  #   ssl_certificate_name           = "appgw-gateway-cert-horizon-dev"
  #   require_sni                    = true
  #   frontend_ip_configuration_name = "feip"
  # }
}

redirect_configurations = {
  redir-dev-http-to-https-public = {
    target_listener_name = "listener-dev-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-dev-http-to-https-private = {
    target_listener_name = "listener-dev-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-qa-http-to-https = {
  #   target_listener_name = "listener-qa-https"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}

routing_rules = [
  # dev
  # PUBLIC
  {
    name                        = "rule-dev-http-redirect-public"
    priority                    = 90
    http_listener_name          = "listener-dev-http-public"
    redirect_configuration_name = "redir-dev-http-to-https-public"
  },
  {
    name                       = "rule-dev-https-public"
    priority                   = 100
    http_listener_name         = "listener-dev-https-public"
    backend_address_pool_name  = "bepool-dev"
    backend_http_settings_name = "bhs-dev-https"
  },

  # PRIVATE
  {
    name                        = "rule-dev-http-redirect-private"
    priority                    = 190
    http_listener_name          = "listener-dev-http-private"
    redirect_configuration_name = "redir-dev-http-to-https-private"
  },
  {
    name                       = "rule-dev-https-private"
    priority                   = 200
    http_listener_name         = "listener-dev-https-private"
    backend_address_pool_name  = "bepool-dev"
    backend_http_settings_name = "bhs-dev-https"
  },

  # qa
  # {
  #   name                        = "rule-qa-http-redirect"
  #   priority                    = 190
  #   http_listener_name          = "listener-qa-http"
  #   redirect_configuration_name = "redir-qa-http-to-https"
  # },
  # {
  #   name                       = "rule-qa-https"
  #   priority                   = 200
  #   http_listener_name         = "listener-qa-https"
  #   backend_address_pool_name  = "bepool-qa"
  #   backend_http_settings_name = "bhs-qa-https"
  # }
]
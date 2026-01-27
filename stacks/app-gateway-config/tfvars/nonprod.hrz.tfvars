# Core context (match dev structure)
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
  app_public = {
    mode             = "Prevention"
    vpn_cidrs        = ["192.168.1.0/24"]
    restricted_paths = ["/admin"]
    blocked_countries = ["CN", "RU", "IR"]    # https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md

    # Disable managed rules by rule group + IDs
    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260","942340", "942370","942330","942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }
  # NEW: internal endpoint policy (US-only + VPN-only for ALL paths)
  app_logging = {
    mode                      = "Prevention"
    vpn_cidrs                 = ["192.168.1.0/24"]
    restricted_paths          = []          # not used when vpn_required_for_all_paths=true
    allowed_countries         = ["US"]
    vpn_required_for_all_paths = true

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260","942340", "942370","942330","942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }

  # qa = {
  #   mode             = "Prevention"
  #   vpn_cidrs        = ["192.168.1.0/24"]
  #   restricted_paths = ["/admin"]           # ["/admin", "/ops"]
  #   blocked_countries = ["CN", "RU", "IR"]  # https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md
  # 
  # Disable managed rules by rule group + IDs
    # disabled_rules_by_group = {
    #   "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260","942340", "942370","942330","942440"]
    #   "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
    #   "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    # }
  # }
}

# Distinct cert per listener but if multiple listeners use same cert, they can reference same sslCertificate element
ssl_certificates = {
  appgw-gateway-cert-horizon-dev = {
    secret_name    = "appgw-gateway-cert-horizon-dev" # or whatever your wildcard secret is - wildcard-horizon-intterra-io
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
  bepool-internal-dev = { ip_addresses = ["1.1.1.1"] }
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

  probe-internal-dev = {
    protocol            = "Https"
    host                = "internal.dev.horizon.intterra.io"
    path                = "/logs/login"
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

  bhs-internal-dev-https = {
    port                = 443
    protocol            = "Https"
    request_timeout     = 20
    cookie_based_affinity = "Disabled"
    probe_name          = "probe-internal-dev"
    host_name           = "internal.dev.horizon.intterra.io"
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
    waf_policy_key                 = "app_public"
  }

  listener-dev-https-public = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-dev"
    require_sni                    = true
    frontend                       = "public"
    waf_policy_key                 = "app_public"
  }

  # PRIVATE
  listener-dev-http-private = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.horizon.intterra.io"
    frontend                       = "private"
    waf_policy_key                 = "app_public"
  }

  listener-dev-https-private = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.horizon.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-horizon-dev"
    require_sni                    = true
    frontend                       = "private"
    waf_policy_key                 = "app_public"
  }

  # INTERNAL (PRIVATE ONLY)
  listener-internal-dev-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.dev.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app_logging"
  }

  listener-internal-dev-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-dev"  # SAME CERT
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app_logging"
  }

  # PUBLIC
  # listener-qa-http-public = {
  #   frontend_port_name             = "feport-80"
  #   protocol                       = "Http"
  #   host_name                      = "qa.horizon.intterra.io"
  #   frontend                       = "public"
  #   waf_policy_key                 = "qa"
  # }

  # listener-qa-https-public = {
  #   frontend_port_name             = "feport-443"
  #   protocol                       = "Https"
  #   host_name                      = "qa.horizon.intterra.io"
  #   ssl_certificate_name           = "appgw-gateway-cert-horizon-qa"
  #   require_sni                    = true
  #   frontend                       = "public"
  #   waf_policy_key                 = "qa"
  # }

  # # PRIVATE
  # listener-qa-http-private = {
  #   frontend_port_name             = "feport-80"
  #   protocol                       = "Http"
  #   host_name                      = "qa.horizon.intterra.io"
  #   frontend                       = "private"
  #   waf_policy_key                 = "qa"
  # }

  # listener-qa-https-private = {
  #   frontend_port_name             = "feport-443"
  #   protocol                       = "Https"
  #   host_name                      = "qa.horizon.intterra.io"
  #   ssl_certificate_name           = "appgw-gateway-cert-horizon-qa"
  #   require_sni                    = true
  #   frontend                       = "private"
  #   waf_policy_key                 = "qa"
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

  redir-internal-dev-http-to-https-private = {
    target_listener_name = "listener-internal-dev-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-qa-http-to-https-public = {
  #   target_listener_name = "listener-qa-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }

  # redir-qa-http-to-https-private = {
  #   target_listener_name = "listener-qa-https-private"
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
  }

  # INTERNAL (PRIVATE)
  {
    name                        = "rule-internal-dev-http-redirect-private"
    priority                    = 210
    http_listener_name          = "listener-internal-dev-http-private"
    redirect_configuration_name = "redir-internal-dev-http-to-https-private"
  },
  {
    name                       = "rule-internal-dev-https-private"
    priority                   = 220
    http_listener_name         = "listener-internal-dev-https-private"
    backend_address_pool_name  = "bepool-internal-dev"
    backend_http_settings_name = "bhs-internal-dev-https"
  }
  
  # qa
  # PUBLIC
  # {
  #   name                        = "rule-qa-http-redirect-public"
  #   priority                    = 90
  #   http_listener_name          = "listener-qa-http-public"
  #   redirect_configuration_name = "redir-qa-http-to-https-public"
  # },
  # {
  #   name                       = "rule-qa-https-public"
  #   priority                   = 100
  #   http_listener_name         = "listener-qa-https-public"
  #   backend_address_pool_name  = "bepool-qa"
  #   backend_http_settings_name = "bhs-qa-https"
  # },

  # # PRIVATE
  # {
  #   name                        = "rule-qa-http-redirect-private"
  #   priority                    = 190
  #   http_listener_name          = "listener-qa-http-private"
  #   redirect_configuration_name = "redir-qa-http-to-https-private"
  # },
  # {
  #   name                       = "rule-qa-https-private"
  #   priority                   = 200
  #   http_listener_name         = "listener-qa-https-private"
  #   backend_address_pool_name  = "bepool-qa"
  #   backend_http_settings_name = "bhs-qa-https"
  # }
]
product  = "hrz"
plane    = "nonprod"
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
  app-main-dev = {
    mode              = "Prevention"
    vpn_cidrs          = ["192.168.1.0/24"]
    restricted_paths   = ["/admin"]
    allowed_countries  = ["US"]
    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200","942260","942340","942370","942330","942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300","920320"]
    }
  }

  obs-internal-dev = {
    mode                       = "Prevention"
    vpn_cidrs                  = ["192.168.1.0/24"]
    restricted_paths           = []  
    allowed_countries          = ["US"]
    vpn_required_for_all_paths = true
    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200","942260","942340","942370","942330","942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300","920320"]
    }
  }

  # --- QA (copy of dev; update CIDRs/paths if needed) ---
  # app-main-qa = {
  #   mode              = "Prevention"
  #   vpn_cidrs          = ["192.168.1.0/24"]
  #   restricted_paths   = ["/admin"]
  #   allowed_countries  = ["US"]
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200","942260","942340","942370","942330","942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300","920320"]
  #   }
  # }
  #
  # obs-internal-qa = {
  #   mode                       = "Prevention"
  #   vpn_cidrs                  = ["192.168.1.0/24"]
  #   restricted_paths           = []  
  #   allowed_countries          = ["US"]
  #   vpn_required_for_all_paths = true
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200","942260","942340","942370","942330","942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300","920320"]
  #   }
  # }
}

ssl_certificates = {
  appgw-gateway-cert-horizon-dev = {
    secret_name = "appgw-gateway-cert-horizon-dev"
  }

  # appgw-gateway-cert-horizon-qa = {
  #   secret_name = "appgw-gateway-cert-horizon-qa"
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-app-dev          = { ip_addresses = ["62.10.212.49"] }
  bepool-obs-internal-dev = { ip_addresses = ["1.1.1.1"] }

  # bepool-app-qa          = { ip_addresses = ["62.10.212.50"] }
  # bepool-obs-internal-qa = { ip_addresses = ["1.1.1.1"] }
}

probes = {
  probe-app-dev = {
    protocol            = "Https"
    host                = "dev.horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-obs-internal-dev = {
    protocol            = "Https"
    host                = "internal.dev.horizon.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-app-qa = {
  #   protocol            = "Https"
  #   host                = "qa.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-obs-internal-qa = {
  #   protocol            = "Https"
  #   host                = "internal.qa.horizon.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

backend_http_settings = {
  bhs-app-dev-https = {
    port                          = 443
    protocol                      = "Https"
    request_timeout               = 20
    cookie_based_affinity         = "Disabled"
    probe_name                    = "probe-app-dev"
    host_name                     = "dev.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-obs-internal-dev-https = {
    port                          = 443
    protocol                      = "Https"
    request_timeout               = 20
    cookie_based_affinity         = "Disabled"
    probe_name                    = "probe-obs-internal-dev"
    host_name                     = "internal.dev.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-app-qa-https = {
  #   port                          = 443
  #   protocol                      = "Https"
  #   request_timeout               = 20
  #   cookie_based_affinity         = "Disabled"
  #   probe_name                    = "probe-app-qa"
  #   host_name                     = "qa.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-obs-internal-qa-https = {
  #   port                          = 443
  #   protocol                      = "Https"
  #   request_timeout               = 20
  #   cookie_based_affinity         = "Disabled"
  #   probe_name                    = "probe-obs-internal-qa"
  #   host_name                     = "internal.qa.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  listener-app-dev-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "dev.horizon.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-main-dev"
  }

  listener-app-dev-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-dev"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-main-dev"
  }

  listener-app-dev-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "dev.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-main-dev"
  }

  listener-app-dev-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-main-dev"
  }

  listener-obs-internal-dev-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.dev.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "obs-internal-dev"
  }

  listener-obs-internal-dev-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "obs-internal-dev"
  }

  # --- QA (structure mirrors dev) ---
  # listener-app-qa-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "qa.horizon.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-main-qa"
  # }
  #
  # listener-app-qa-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-qa"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-main-qa"
  # }
  #
  # listener-app-qa-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "qa.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-main-qa"
  # }
  #
  # listener-app-qa-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-qa"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-main-qa"
  # }
  #
  # listener-obs-internal-qa-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.qa.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "obs-internal-qa"
  # }
  #
  # listener-obs-internal-qa-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-qa"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "obs-internal-qa"
  # }
}

redirect_configurations = {
  redir-app-dev-http-to-https-public = {
    target_listener_name = "listener-app-dev-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-app-dev-http-to-https-private = {
    target_listener_name = "listener-app-dev-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-obs-internal-dev-http-to-https-private = {
    target_listener_name = "listener-obs-internal-dev-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-app-qa-http-to-https-public = {
  #   target_listener_name = "listener-app-qa-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-app-qa-http-to-https-private = {
  #   target_listener_name = "listener-app-qa-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-obs-internal-qa-http-to-https-private = {
  #   target_listener_name = "listener-obs-internal-qa-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}

routing_rules = [
  {
    name                        = "rule-app-dev-http-redirect-public"
    priority                    = 90
    http_listener_name          = "listener-app-dev-http-public"
    redirect_configuration_name = "redir-app-dev-http-to-https-public"
  },
  {
    name                       = "rule-app-dev-https-public"
    priority                   = 100
    http_listener_name         = "listener-app-dev-https-public"
    backend_address_pool_name  = "bepool-app-dev"
    backend_http_settings_name = "bhs-app-dev-https"
  },
  {
    name                        = "rule-app-dev-http-redirect-private"
    priority                    = 190
    http_listener_name          = "listener-app-dev-http-private"
    redirect_configuration_name = "redir-app-dev-http-to-https-private"
  },
  {
    name                       = "rule-app-dev-https-private"
    priority                   = 200
    http_listener_name         = "listener-app-dev-https-private"
    backend_address_pool_name  = "bepool-app-dev"
    backend_http_settings_name = "bhs-app-dev-https"
  },
  {
    name                        = "rule-obs-internal-dev-http-redirect-private"
    priority                    = 210
    http_listener_name          = "listener-obs-internal-dev-http-private"
    redirect_configuration_name = "redir-obs-internal-dev-http-to-https-private"
  },
  {
    name                       = "rule-obs-internal-dev-https-private"
    priority                   = 220
    http_listener_name         = "listener-obs-internal-dev-https-private"
    backend_address_pool_name  = "bepool-obs-internal-dev"
    backend_http_settings_name = "bhs-obs-internal-dev-https"
  }

  # --- QA (mirrors dev priorities; adjust if you need gaps) ---
  # {
  #   name                        = "rule-app-qa-http-redirect-public"
  #   priority                    = 91
  #   http_listener_name          = "listener-app-qa-http-public"
  #   redirect_configuration_name = "redir-app-qa-http-to-https-public"
  # },
  # {
  #   name                       = "rule-app-qa-https-public"
  #   priority                   = 101
  #   http_listener_name         = "listener-app-qa-https-public"
  #   backend_address_pool_name  = "bepool-app-qa"
  #   backend_http_settings_name = "bhs-app-qa-https"
  # },
  # {
  #   name                        = "rule-app-qa-http-redirect-private"
  #   priority                    = 191
  #   http_listener_name          = "listener-app-qa-http-private"
  #   redirect_configuration_name = "redir-app-qa-http-to-https-private"
  # },
  # {
  #   name                       = "rule-app-qa-https-private"
  #   priority                   = 201
  #   http_listener_name         = "listener-app-qa-https-private"
  #   backend_address_pool_name  = "bepool-app-qa"
  #   backend_http_settings_name = "bhs-app-qa-https"
  # },
  # {
  #   name                        = "rule-obs-internal-qa-http-redirect-private"
  #   priority                    = 211
  #   http_listener_name          = "listener-obs-internal-qa-http-private"
  #   redirect_configuration_name = "redir-obs-internal-qa-http-to-https-private"
  # },
  # {
  #   name                       = "rule-obs-internal-qa-https-private"
  #   priority                   = 221
  #   http_listener_name         = "listener-obs-internal-qa-https-private"
  #   backend_address_pool_name  = "bepool-obs-internal-qa"
  #   backend_http_settings_name = "bhs-obs-internal-qa-https"
  # }
]
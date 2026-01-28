product  = "hrz"
plane    = "prod"
location = "USGov Arizona"
region   = "usaz"

tags = {
  purpose = "appgw-config"
  plane   = "prod"
}

shared_network_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/hrz/usaz/pr.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/hrz/usaz/pr.tfstate"
}

waf_policies = {
  app-main-prod = {
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

  obs-internal-prod = {
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

  # --- UAT (copy of prod; update CIDRs/paths if needed) ---
  # app-main-uat = {
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
  # obs-internal-uat = {
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
  appgw-gateway-cert-horizon-prod = {
    secret_name = "appgw-gateway-cert-horizon-prod"
  }

  # appgw-gateway-cert-horizon-uat = {
  #   secret_name = "appgw-gateway-cert-horizon-uat"
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-app-prod          = { ip_addresses = ["62.10.212.49"] }
  bepool-obs-internal-prod = { ip_addresses = ["62.10.212.49"] }

  # bepool-app-uat          = { ip_addresses = ["62.10.212.50"] }
  # bepool-obs-internal-uat = { ip_addresses = ["62.10.212.50"] }
}

probes = {
  probe-app-prod = {
    protocol            = "Https"
    host                = "horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-obs-internal-prod = {
    protocol            = "Https"
    host                = "internal.horizon.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-app-uat = {
  #   protocol            = "Https"
  #   host                = "uat.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-obs-internal-uat = {
  #   protocol            = "Https"
  #   host                = "internal.uat.horizon.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

backend_http_settings = {
  bhs-app-prod-https = {
    port                          = 443
    protocol                      = "Https"
    request_timeout               = 20
    cookie_based_affinity         = "Disabled"
    probe_name                    = "probe-app-prod"
    host_name                     = "horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-obs-internal-prod-https = {
    port                          = 443
    protocol                      = "Https"
    request_timeout               = 20
    cookie_based_affinity         = "Disabled"
    probe_name                    = "probe-obs-internal-prod"
    host_name                     = "internal.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-app-uat-https = {
  #   port                          = 443
  #   protocol                      = "Https"
  #   request_timeout               = 20
  #   cookie_based_affinity         = "Disabled"
  #   probe_name                    = "probe-app-uat"
  #   host_name                     = "uat.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-obs-internal-uat-https = {
  #   port                          = 443
  #   protocol                      = "Https"
  #   request_timeout               = 20
  #   cookie_based_affinity         = "Disabled"
  #   probe_name                    = "probe-obs-internal-uat"
  #   host_name                     = "internal.uat.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  listener-app-prod-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "horizon.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-main-prod"
  }

  listener-app-prod-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-main-prod"
  }

  listener-app-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-main-prod"
  }

  listener-app-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-main-prod"
  }

  listener-obs-internal-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "obs-internal-prod"
  }

  listener-obs-internal-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "obs-internal-prod"
  }

  # --- UAT (structure mirrors prod) ---
  # listener-app-uat-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.horizon.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-main-uat"
  # }
  #
  # listener-app-uat-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-uat"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-main-uat"
  # }
  #
  # listener-app-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-main-uat"
  # }
  #
  # listener-app-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-main-uat"
  # }
  #
  # listener-obs-internal-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.uat.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "obs-internal-uat"
  # }
  #
  # listener-obs-internal-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "obs-internal-uat"
  # }
}

redirect_configurations = {
  redir-app-prod-http-to-https-public = {
    target_listener_name = "listener-app-prod-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-app-prod-http-to-https-private = {
    target_listener_name = "listener-app-prod-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-obs-internal-prod-http-to-https-private = {
    target_listener_name = "listener-obs-internal-prod-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-app-uat-http-to-https-public = {
  #   target_listener_name = "listener-app-uat-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-app-uat-http-to-https-private = {
  #   target_listener_name = "listener-app-uat-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-obs-internal-uat-http-to-https-private = {
  #   target_listener_name = "listener-obs-internal-uat-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}

routing_rules = [
  {
    name                        = "rule-app-prod-http-redirect-public"
    priority                    = 90
    http_listener_name          = "listener-app-prod-http-public"
    redirect_configuration_name = "redir-app-prod-http-to-https-public"
  },
  {
    name                       = "rule-app-prod-https-public"
    priority                   = 100
    http_listener_name         = "listener-app-prod-https-public"
    backend_address_pool_name  = "bepool-app-prod"
    backend_http_settings_name = "bhs-app-prod-https"
  },
  {
    name                        = "rule-app-prod-http-redirect-private"
    priority                    = 190
    http_listener_name          = "listener-app-prod-http-private"
    redirect_configuration_name = "redir-app-prod-http-to-https-private"
  },
  {
    name                       = "rule-app-prod-https-private"
    priority                   = 200
    http_listener_name         = "listener-app-prod-https-private"
    backend_address_pool_name  = "bepool-app-prod"
    backend_http_settings_name = "bhs-app-prod-https"
  },
  {
    name                        = "rule-obs-internal-prod-http-redirect-private"
    priority                    = 210
    http_listener_name          = "listener-obs-internal-prod-http-private"
    redirect_configuration_name = "redir-obs-internal-prod-http-to-https-private"
  },
  {
    name                       = "rule-obs-internal-prod-https-private"
    priority                   = 220
    http_listener_name         = "listener-obs-internal-prod-https-private"
    backend_address_pool_name  = "bepool-obs-internal-prod"
    backend_http_settings_name = "bhs-obs-internal-prod-https"
  }

  # --- UAT (mirrors prod priorities; adjust if you want gaps) ---
  # {
  #   name                        = "rule-app-uat-http-redirect-public"
  #   priority                    = 290
  #   http_listener_name          = "listener-app-uat-http-public"
  #   redirect_configuration_name = "redir-app-uat-http-to-https-public"
  # },
  # {
  #   name                       = "rule-app-uat-https-public"
  #   priority                   = 300
  #   http_listener_name         = "listener-app-uat-https-public"
  #   backend_address_pool_name  = "bepool-app-uat"
  #   backend_http_settings_name = "bhs-app-uat-https"
  # },
  # {
  #   name                        = "rule-app-uat-http-redirect-private"
  #   priority                    = 390
  #   http_listener_name          = "listener-app-uat-http-private"
  #   redirect_configuration_name = "redir-app-uat-http-to-https-private"
  # },
  # {
  #   name                       = "rule-app-uat-https-private"
  #   priority                   = 400
  #   http_listener_name         = "listener-app-uat-https-private"
  #   backend_address_pool_name  = "bepool-app-uat"
  #   backend_http_settings_name = "bhs-app-uat-https"
  # },
  # {
  #   name                        = "rule-obs-internal-uat-http-redirect-private"
  #   priority                    = 410
  #   http_listener_name          = "listener-obs-internal-uat-http-private"
  #   redirect_configuration_name = "redir-obs-internal-uat-http-to-https-private"
  # },
  # {
  #   name                       = "rule-obs-internal-uat-https-private"
  #   priority                   = 420
  #   http_listener_name         = "listener-obs-internal-uat-https-private"
  #   backend_address_pool_name  = "bepool-obs-internal-uat"
  #   backend_http_settings_name = "bhs-obs-internal-uat-https"
  # }
]
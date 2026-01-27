# Core context (match dev structure)
product = "hrz"
plane   = "prod"

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
  app_public = {
    mode             = "Prevention"
    vpn_cidrs        = ["192.168.1.0/24"]
    restricted_paths = ["/admin"]
    allowed_countries = ["US"]    # https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md

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

  # uat = {
  #   mode              = "Prevention"
  #   vpn_cidrs         = ["192.168.1.0/24"]
  #   restricted_paths  = ["/admin"] # ["/admin", "/ops"]
  #   blocked_countries = ["CN", "RU", "IR"] # https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md

  #   # Disable managed rules by rule group + IDs
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942340", "942370"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI" = ["931130"]
  #     # "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300"]
  #   }
  # }
}

# Distinct cert per listener but if multiple listeners use same cert, they can reference same sslCertificate element
ssl_certificates = {
  appgw-gateway-cert-horizon-prod = {
    secret_name    = "appgw-gateway-cert-horizon-prod" # or wildcard secret name if you use one
    secret_version = null
  }

  # appgw-gateway-cert-horizon-uat = {
  #   secret_name    = "appgw-gateway-cert-horizon-uat" # or reuse prod wildcard if applicable
  #   secret_version = null
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-prod = { ip_addresses = ["62.10.212.49"] }
  bepool-internal-prod = { ip_addresses = ["62.10.212.49"] }
  # bepool-uat  = { ip_addresses = ["62.10.212.50"] }
}

probes = {
  probe-prod = {
    protocol            = "Https"
    host                = "horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-internal-prod = {
    protocol            = "Https"
    host                = "internal.horizon.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-uat = {
  #   protocol            = "Https"
  #   host                = "uat.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

backend_http_settings = {
  bhs-prod-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-prod"
    host_name                           = "horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-internal-prod-https = {
    port                = 443
    protocol            = "Https"
    request_timeout     = 20
    cookie_based_affinity = "Disabled"
    probe_name          = "probe-internal-prod"
    host_name           = "internal.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-uat-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-uat"
  #   host_name                           = "uat.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  # PROD (PUBLIC)
  listener-prod-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "horizon.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app_public"
  }

  listener-prod-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app_public"
  }

  # PROD (PRIVATE)
  listener-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app_public"
  }

  listener-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app_public"
  }

  # INTERNAL (PRIVATE ONLY)
  listener-internal-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app_logging"
  }

  listener-internal-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.horizon.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-horizon-prod"  # SAME CERT
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app_logging"
  }

  # # UAT (PUBLIC)
  # listener-uat-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.horizon.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "uat"
  # }

  # listener-uat-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-uat"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "uat"
  # }

  # # UAT (PRIVATE)
  # listener-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "uat"
  # }

  # listener-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-horizon-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "uat"
  # }
}

redirect_configurations = {
  redir-prod-http-to-https-public = {
    target_listener_name = "listener-prod-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-prod-http-to-https-private = {
    target_listener_name = "listener-prod-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-internal-prod-http-to-https-private = {
    target_listener_name = "listener-internal-prod-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-uat-http-to-https-public = {
  #   target_listener_name = "listener-uat-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }

  # redir-uat-http-to-https-private = {
  #   target_listener_name = "listener-uat-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}

routing_rules = [
  # PROD
  # PUBLIC
  {
    name                        = "rule-prod-http-redirect-public"
    priority                    = 90
    http_listener_name          = "listener-prod-http-public"
    redirect_configuration_name = "redir-prod-http-to-https-public"
  },
  {
    name                       = "rule-prod-https-public"
    priority                   = 100
    http_listener_name         = "listener-prod-https-public"
    backend_address_pool_name  = "bepool-prod"
    backend_http_settings_name = "bhs-prod-https"
  },

  # PRIVATE
  {
    name                        = "rule-prod-http-redirect-private"
    priority                    = 190
    http_listener_name          = "listener-prod-http-private"
    redirect_configuration_name = "redir-prod-http-to-https-private"
  },
  {
    name                       = "rule-prod-https-private"
    priority                   = 200
    http_listener_name         = "listener-prod-https-private"
    backend_address_pool_name  = "bepool-prod"
    backend_http_settings_name = "bhs-prod-https"
  },

  # INTERNAL (PRIVATE)
  {
    name                        = "rule-internal-prod-http-redirect-private"
    priority                    = 210
    http_listener_name          = "listener-internal-prod-http-private"
    redirect_configuration_name = "redir-internal-prod-http-to-https-private"
  },
  {
    name                       = "rule-internal-prod-https-private"
    priority                   = 220
    http_listener_name         = "listener-internal-prod-https-private"
    backend_address_pool_name  = "bepool-internal-prod"
    backend_http_settings_name = "bhs-internal-prod-https"
  }

  # # UAT
  # # PUBLIC
  # {
  #   name                        = "rule-uat-http-redirect-public"
  #   priority                    = 290
  #   http_listener_name          = "listener-uat-http-public"
  #   redirect_configuration_name = "redir-uat-http-to-https-public"
  # },
  # {
  #   name                       = "rule-uat-https-public"
  #   priority                   = 300
  #   http_listener_name         = "listener-uat-https-public"
  #   backend_address_pool_name  = "bepool-uat"
  #   backend_http_settings_name = "bhs-uat-https"
  # },

  # # PRIVATE
  # {
  #   name                        = "rule-uat-http-redirect-private"
  #   priority                    = 390
  #   http_listener_name          = "listener-uat-http-private"
  #   redirect_configuration_name = "redir-uat-http-to-https-private"
  # },
  # {
  #   name                       = "rule-uat-https-private"
  #   priority                   = 400
  #   http_listener_name         = "listener-uat-https-private"
  #   backend_address_pool_name  = "bepool-uat"
  #   backend_http_settings_name = "bhs-uat-https"
  # }
]
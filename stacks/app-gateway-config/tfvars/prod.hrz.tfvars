product = "hrz"
plane   = "prod"

location = "usgovarizona"
region   = "usaz"

tags = {
  purpose = "appgw-config"
  plane   = "prod"
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

# WAF policies
waf_policies = {

  # PROD (PUBLIC APP) - AFD-only allow-list

  "app-prod-afd-only" = {
    mode = "Prevention"

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      {
        name     = "BlockNonAFD"
        priority = 5
        action   = "Block"
        match_conditions = [
          {
            match_variable     = "RequestHeaders"
            selector           = "X-Azure-FDID"
            operator           = "Equal"
            match_values       = ["d0d30354-45c6-454a-9493-33340d3190cd"] # <-- replace with HRZ AFD profile FDID
            negation_condition = true
          }
        ]
      }
    ]
  }

  # PROD (APP - private/frontend) - Geo + VPN restriction for /admin
  "app-prod-somevpn" = {
    mode = "Prevention"

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      # {
      #   name     = "BlockNonAllowedCountries"
      #   priority = 5
      #   action   = "Block"
      #   match_conditions = [
      #     {
      #       match_variable     = "RemoteAddr"
      #       operator           = "GeoMatch"
      #       match_values       = ["US"]
      #       negation_condition = true
      #     }
      #   ]
      # },
      {
        name     = "BlockNonvpnRestrictedPaths"
        priority = 10
        action   = "Block"
        match_conditions = [
          {
            match_variable = "RequestUri"
            operator       = "BeginsWith"
            match_values   = ["/admin"]
            transforms     = ["Lowercase"]
          },
          {
            match_variable     = "RemoteAddr"
            operator           = "IPMatch"
            match_values       = ["192.168.1.0/24"]
            negation_condition = true
          }
        ]
      }
    ]
  }

  # PROD (OBS INTERNAL) - VPN required for all paths
  "app-prod-protected" = {
    mode = "Prevention"

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      {
        name     = "BlockNonVpnAllPaths"
        priority = 10
        action   = "Block"
        match_conditions = [
          {
            match_variable     = "RemoteAddr"
            operator           = "IPMatch"
            match_values       = ["192.168.1.0/24"]
            negation_condition = true
          }
        ]
      }
    ]
  }

  # UAT placeholders (commented out)

  # "app-uat-afd-only" = {
  #   mode = "Prevention"
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  #
  #   custom_rules = [
  #     {
  #       name     = "BlockNonAFD"
  #       priority = 5
  #       action   = "Block"
  #       match_conditions = [
  #         {
  #           match_variable     = "RequestHeaders"
  #           selector           = "X-Azure-FDID"
  #           operator           = "Equal"
  #           match_values       = ["<HRZ_UAT_AFD_FDID_GUID>"]
  #           negation_condition = true
  #         }
  #       ]
  #     }
  #   ]
  # }
  #
  # "app-uat-somevpn" = {
  #   mode = "Prevention"
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  #
  #   custom_rules = [
  #     {
  #       name     = "BlockNonAllowedCountries"
  #       priority = 5
  #       action   = "Block"
  #       match_conditions = [
  #         {
  #           match_variable     = "RemoteAddr"
  #           operator           = "GeoMatch"
  #           match_values       = ["US"]
  #           negation_condition = true
  #         }
  #       ]
  #     },
  #     {
  #       name     = "BlockNonvpnRestrictedPaths"
  #       priority = 10
  #       action   = "Block"
  #       match_conditions = [
  #         {
  #           match_variable = "RequestUri"
  #           operator       = "BeginsWith"
  #           match_values   = ["/admin"]
  #           transforms     = ["Lowercase"]
  #         },
  #         {
  #           match_variable     = "RemoteAddr"
  #           operator           = "IPMatch"
  #           match_values       = ["192.168.1.0/24"]
  #           negation_condition = true
  #         }
  #       ]
  #     }
  #   ]
  # }
  #
  # "app-uat-protected" = {
  #   mode = "Prevention"
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  #
  #   custom_rules = [
  #     {
  #       name     = "BlockNonVpnAllPaths"
  #       priority = 10
  #       action   = "Block"
  #       match_conditions = [
  #         {
  #           match_variable     = "RemoteAddr"
  #           operator           = "IPMatch"
  #           match_values       = ["192.168.1.0/24"]
  #           negation_condition = true
  #         }
  #       ]
  #     }
  #   ]
  # }
}

# certs (prod now; uat later)
ssl_certificates = {
  appgw-cert-hrz-prod = {
    secret_name = "appgw-gateway-cert-horizon-prod"
  }

  # appgw-cert-hrz-uat = {
  #   secret_name = "appgw-gateway-cert-horizon-uat"
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

# Backends (NO publiclayers)
backend_pools = {
  be-prod-app = { ip_addresses = ["52.244.243.161"] }
  be-prod-obs = { ip_addresses = ["1.1.1.1"] }

  # # UAT placeholders
  # be-uat-app = { ip_addresses = ["<UAT_APP_IP>"] }
  # be-uat-obs = { ip_addresses = ["<UAT_OBS_IP>"] }
}

# Probes (NO publiclayers)
probes = {
  probe-prod-app = {
    protocol            = "Https"
    host                = "horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-prod-obs = {
    protocol            = "Https"
    host                = "internal.horizon.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # # UAT placeholders
  # probe-uat-app = {
  #   protocol            = "Https"
  #   host                = "uat.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-uat-obs = {
  #   protocol            = "Https"
  #   host                = "internal.uat.horizon.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

# Backend HTTP settings (NO publiclayers)
backend_http_settings = {
  bhs-prod-app-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-prod-app"
    host_name                           = "horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-prod-obs-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-prod-obs"
    host_name                           = "internal.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # # UAT placeholders
  # bhs-uat-app-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-uat-app"
  #   host_name                           = "uat.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-uat-obs-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-uat-obs"
  #   host_name                           = "internal.uat.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

# Listeners
listeners = {
  # PROD APP (PUBLIC) - AFD-only
  lis-prod-app-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-horizon.horizon.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-prod-afd-only"
  }

  lis-prod-app-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-horizon.horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-prod-afd-only"
  }

  # PROD APP (PRIVATE) - somevpn
  lis-prod-app-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-prod-somevpn"
  }

  lis-prod-app-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-prod-somevpn"
  }

  # PROD OBS (PRIVATE ONLY) - protected
  lis-prod-obs-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-prod-protected"
  }

  lis-prod-obs-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-prod-protected"
  }

  # UAT placeholders

  # lis-uat-app-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "origin-horizon.uat.horizon.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-uat-afd-only"
  # }
  #
  # lis-uat-app-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "origin-horizon.uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-uat"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-uat-afd-only"
  # }
  #
  # lis-uat-app-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-uat-somevpn"
  # }
  #
  # lis-uat-app-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-uat-somevpn"
  # }
  #
  # lis-uat-obs-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.uat.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-uat-protected"
  # }
  #
  # lis-uat-obs-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.uat.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-uat-protected"
  # }
}

# Redirects
redirect_configurations = {
  redir-prod-app-http-to-https-public = {
    target_listener_name = "lis-prod-app-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-prod-app-http-to-https-private = {
    target_listener_name = "lis-prod-app-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-prod-obs-http-to-https-private = {
    target_listener_name = "lis-prod-obs-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # # UAT placeholders
  # redir-uat-app-http-to-https-public = {
  #   target_listener_name = "lis-uat-app-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-uat-app-http-to-https-private = {
  #   target_listener_name = "lis-uat-app-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-uat-obs-http-to-https-private = {
  #   target_listener_name = "lis-uat-obs-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}

# Routing rules
routing_rules = [
  # PROD APP (PUBLIC)
  {
    name                        = "rule-prod-app-http-redirect-public"
    priority                    = 90
    http_listener_name          = "lis-prod-app-http-public"
    redirect_configuration_name = "redir-prod-app-http-to-https-public"
  },
  {
    name                       = "rule-prod-app-https-public"
    priority                   = 100
    http_listener_name         = "lis-prod-app-https-public"
    backend_address_pool_name  = "be-prod-app"
    backend_http_settings_name = "bhs-prod-app-https"
  },

  # PROD APP (PRIVATE)
  {
    name                        = "rule-prod-app-http-redirect-private"
    priority                    = 190
    http_listener_name          = "lis-prod-app-http-private"
    redirect_configuration_name = "redir-prod-app-http-to-https-private"
  },
  {
    name                       = "rule-prod-app-https-private"
    priority                   = 200
    http_listener_name         = "lis-prod-app-https-private"
    backend_address_pool_name  = "be-prod-app"
    backend_http_settings_name = "bhs-prod-app-https"
  },

  # PROD OBS (PRIVATE)
  {
    name                        = "rule-prod-obs-http-redirect-private"
    priority                    = 210
    http_listener_name          = "lis-prod-obs-http-private"
    redirect_configuration_name = "redir-prod-obs-http-to-https-private"
  },
  {
    name                       = "rule-prod-obs-https-private"
    priority                   = 220
    http_listener_name         = "lis-prod-obs-https-private"
    backend_address_pool_name  = "be-prod-obs"
    backend_http_settings_name = "bhs-prod-obs-https"
  }

  # # UAT placeholders (commented out)
  # ,
  # {
  #   name                        = "rule-uat-app-http-redirect-public"
  #   priority                    = 91
  #   http_listener_name          = "lis-uat-app-http-public"
  #   redirect_configuration_name = "redir-uat-app-http-to-https-public"
  # },
  # {
  #   name                       = "rule-uat-app-https-public"
  #   priority                   = 101
  #   http_listener_name         = "lis-uat-app-https-public"
  #   backend_address_pool_name  = "be-uat-app"
  #   backend_http_settings_name = "bhs-uat-app-https"
  # },
  # {
  #   name                        = "rule-uat-app-http-redirect-private"
  #   priority                    = 191
  #   http_listener_name          = "lis-uat-app-http-private"
  #   redirect_configuration_name = "redir-uat-app-http-to-https-private"
  # },
  # {
  #   name                       = "rule-uat-app-https-private"
  #   priority                   = 201
  #   http_listener_name         = "lis-uat-app-https-private"
  #   backend_address_pool_name  = "be-uat-app"
  #   backend_http_settings_name = "bhs-uat-app-https"
  # },
  # {
  #   name                        = "rule-uat-obs-http-redirect-private"
  #   priority                    = 211
  #   http_listener_name          = "lis-uat-obs-http-private"
  #   redirect_configuration_name = "redir-uat-obs-http-to-https-private"
  # },
  # {
  #   name                       = "rule-uat-obs-https-private"
  #   priority                   = 221
  #   http_listener_name         = "lis-uat-obs-https-private"
  #   backend_address_pool_name  = "be-uat-obs"
  #   backend_http_settings_name = "bhs-uat-obs-https"
  # }
]
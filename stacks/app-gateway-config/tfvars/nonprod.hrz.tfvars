product = "hrz"
plane   = "nonprod"

location = "usgovarizona"
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

# WAF policies
waf_policies = {

  # DEV (PUBLIC APP) - AFD-only allow-list

  "app-dev-afd-only" = {
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
            match_values       = ["19318404-6447-4ef1-8ce2-60c307fb7161"] # <-- replace with HRZ AFD profile FDID
            negation_condition = true
          }
        ]
      }
    ]
  }

  # DEV (APP - private/frontend) - Geo + VPN restriction for /admin
  "app-dev-somevpn" = {
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

  # DEV (OBS INTERNAL) - VPN required for all paths
  "app-dev-protected" = {
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

  # QA placeholders (commented out)

  # "app-qa-afd-only" = {
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
  #           match_values       = ["<HRZ_QA_AFD_FDID_GUID>"]
  #           negation_condition = true
  #         }
  #       ]
  #     }
  #   ]
  # }
  #
  # "app-qa-somevpn" = {
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
  # "app-qa-protected" = {
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

# certs (dev now; qa later)
ssl_certificates = {
  appgw-cert-hrz-dev = {
    secret_name = "appgw-gateway-cert-horizon-dev"
  }

  # appgw-cert-hrz-qa = {
  #   secret_name = "appgw-gateway-cert-horizon-qa"
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

# Backends (NO publiclayers)
backend_pools = {
  be-dev-app = { ip_addresses = ["62.10.212.185"] }
  be-dev-obs = { ip_addresses = ["10.10.2.8"] }

  # # QA placeholders
  # be-qa-app = { ip_addresses = ["<QA_APP_IP>"] }
  # be-qa-obs = { ip_addresses = ["<QA_OBS_IP>"] }
}


# Probes (NO publiclayers)

probes = {
  probe-dev-app = {
    protocol            = "Https"
    host                = "dev.horizon.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-dev-obs = {
    protocol            = "Https"
    host                = "internal.dev.horizon.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # # QA placeholders
  # probe-qa-app = {
  #   protocol            = "Https"
  #   host                = "qa.horizon.intterra.io"
  #   path                = "/api/identity/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-qa-obs = {
  #   protocol            = "Https"
  #   host                = "internal.qa.horizon.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

# Backend HTTP settings (NO publiclayers)
backend_http_settings = {
  bhs-dev-app-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-dev-app"
    host_name                           = "dev.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-dev-obs-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-dev-obs"
    host_name                           = "internal.dev.horizon.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # # QA placeholders
  # bhs-qa-app-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-qa-app"
  #   host_name                           = "qa.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-qa-obs-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-qa-obs"
  #   host_name                           = "internal.qa.horizon.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

# Listeners
listeners = {
  # DEV APP (PUBLIC) - AFD-only
  lis-dev-app-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-horizon.dev.horizon.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-dev-afd-only"
  }

  lis-dev-app-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-horizon.dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-dev"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-dev-afd-only"
  }

  # DEV APP (PRIVATE) - somevpn
  lis-dev-app-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "dev.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-dev-somevpn"
  }

  lis-dev-app-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-dev-somevpn"
  }

  # DEV OBS (PRIVATE ONLY) - protected
  lis-dev-obs-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.dev.horizon.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-dev-protected"
  }

  lis-dev-obs-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.dev.horizon.intterra.io"
    ssl_certificate_name = "appgw-cert-hrz-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-dev-protected"
  }

  # QA placeholders

  # lis-qa-app-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "origin-horizon.qa.horizon.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-qa-afd-only"
  # }
  #
  # lis-qa-app-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "origin-horizon.qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-qa"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-qa-afd-only"
  # }
  #
  # lis-qa-app-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "qa.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-qa-somevpn"
  # }
  #
  # lis-qa-app-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-qa"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-qa-somevpn"
  # }
  #
  # lis-qa-obs-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.qa.horizon.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-qa-protected"
  # }
  #
  # lis-qa-obs-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.qa.horizon.intterra.io"
  #   ssl_certificate_name = "appgw-cert-hrz-qa"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-qa-protected"
  # }
}

# Redirects
redirect_configurations = {
  redir-dev-app-http-to-https-public = {
    target_listener_name = "lis-dev-app-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-dev-app-http-to-https-private = {
    target_listener_name = "lis-dev-app-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-dev-obs-http-to-https-private = {
    target_listener_name = "lis-dev-obs-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # # QA placeholders
  # redir-qa-app-http-to-https-public = {
  #   target_listener_name = "lis-qa-app-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-qa-app-http-to-https-private = {
  #   target_listener_name = "lis-qa-app-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-qa-obs-http-to-https-private = {
  #   target_listener_name = "lis-qa-obs-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
}


# Routing rules

routing_rules = [
  # DEV APP (PUBLIC)
  {
    name                        = "rule-dev-app-http-redirect-public"
    priority                    = 90
    http_listener_name          = "lis-dev-app-http-public"
    redirect_configuration_name = "redir-dev-app-http-to-https-public"
  },
  {
    name                       = "rule-dev-app-https-public"
    priority                   = 100
    http_listener_name         = "lis-dev-app-https-public"
    backend_address_pool_name  = "be-dev-app"
    backend_http_settings_name = "bhs-dev-app-https"
  },

  # DEV APP (PRIVATE)
  {
    name                        = "rule-dev-app-http-redirect-private"
    priority                    = 190
    http_listener_name          = "lis-dev-app-http-private"
    redirect_configuration_name = "redir-dev-app-http-to-https-private"
  },
  {
    name                       = "rule-dev-app-https-private"
    priority                   = 200
    http_listener_name         = "lis-dev-app-https-private"
    backend_address_pool_name  = "be-dev-app"
    backend_http_settings_name = "bhs-dev-app-https"
  },

  # DEV OBS (PRIVATE)
  {
    name                        = "rule-dev-obs-http-redirect-private"
    priority                    = 210
    http_listener_name          = "lis-dev-obs-http-private"
    redirect_configuration_name = "redir-dev-obs-http-to-https-private"
  },
  {
    name                       = "rule-dev-obs-https-private"
    priority                   = 220
    http_listener_name         = "lis-dev-obs-https-private"
    backend_address_pool_name  = "be-dev-obs"
    backend_http_settings_name = "bhs-dev-obs-https"
  }

  # # QA placeholders (commented out)
  # ,
  # {
  #   name                        = "rule-qa-app-http-redirect-public"
  #   priority                    = 91
  #   http_listener_name          = "lis-qa-app-http-public"
  #   redirect_configuration_name = "redir-qa-app-http-to-https-public"
  # },
  # {
  #   name                       = "rule-qa-app-https-public"
  #   priority                   = 101
  #   http_listener_name         = "lis-qa-app-https-public"
  #   backend_address_pool_name  = "be-qa-app"
  #   backend_http_settings_name = "bhs-qa-app-https"
  # },
  # {
  #   name                        = "rule-qa-app-http-redirect-private"
  #   priority                    = 191
  #   http_listener_name          = "lis-qa-app-http-private"
  #   redirect_configuration_name = "redir-qa-app-http-to-https-private"
  # },
  # {
  #   name                       = "rule-qa-app-https-private"
  #   priority                   = 201
  #   http_listener_name         = "lis-qa-app-https-private"
  #   backend_address_pool_name  = "be-qa-app"
  #   backend_http_settings_name = "bhs-qa-app-https"
  # },
  # {
  #   name                        = "rule-qa-obs-http-redirect-private"
  #   priority                    = 211
  #   http_listener_name          = "lis-qa-obs-http-private"
  #   redirect_configuration_name = "redir-qa-obs-http-to-https-private"
  # },
  # {
  #   name                       = "rule-qa-obs-https-private"
  #   priority                   = 221
  #   http_listener_name         = "lis-qa-obs-https-private"
  #   backend_address_pool_name  = "be-qa-obs"
  #   backend_http_settings_name = "bhs-qa-obs-https"
  # }
]
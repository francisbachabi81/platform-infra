product = "pub"
plane   = "nonprod"

location = "Central US"
region   = "cus"

tags = {
  purpose = "appgw-config"
  plane   = "nonprod"
}

shared_network_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/pub/cus/np.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/pub/cus/np.tfstate"
}

# WAF policies
waf_policies = {
  # DEV (current)
  "app-main-dev" = {
    mode              = "Prevention"
    vpn_cidrs         = ["192.168.1.0/24"]
    restricted_paths  = ["/admin"]
    allowed_countries = ["US"]

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }

  "obs-internal-dev" = {
    mode                       = "Prevention"
    vpn_cidrs                  = ["192.168.1.0/24"]
    restricted_paths           = []  
    allowed_countries          = ["US"]
    vpn_required_for_all_paths = true

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }


  # QA (copies of DEV) - enable when you add QA listeners
  # NOTE: keys must be unique so the policy names are unique

  # "app-main-qa" = {
  #   mode              = "Prevention"
  #   vpn_cidrs         = ["192.168.1.0/24"]
  #   restricted_paths  = ["/admin"]
  #   allowed_countries = ["US"]
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  # }
  #
  # "obs-internal-qa" = {
  #   mode                       = "Prevention"
  #   vpn_cidrs                  = ["192.168.1.0/24"]
  #   restricted_paths           = []
  #   allowed_countries          = ["US"]
  #   vpn_required_for_all_paths = true
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  # }
}

# certs (dev now; qa later)
ssl_certificates = {
  appgw-cert-pub-dev = {
    secret_name = "appgw-gateway-cert-public-dev"
  }

  # appgw-cert-pub-qa = {
  #   secret_name = "appgw-gateway-cert-public-qa"
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

# Backends
backend_pools = {
  be-dev-app = { ip_addresses = ["20.84.250.156"] }
  be-dev-obs = { ip_addresses = ["20.84.250.156"] }

  # # QA
  # be-qa-app = { ip_addresses = ["<QA_APP_IP>"] }
  # be-qa-obs = { ip_addresses = ["<QA_OBS_IP>"] }
}

# Probes
probes = {
  probe-dev-app = {
    protocol            = "Https"
    host                = "public.dev.public.intterra.io"
    path                = "/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-dev-obs = {
    protocol            = "Https"
    host                = "internal.dev.public.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # # QA
  # probe-qa-app = {
  #   protocol            = "Https"
  #   host                = "public.qa.public.intterra.io"
  #   path                = "/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-qa-obs = {
  #   protocol            = "Https"
  #   host                = "internal.qa.public.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

# Backend HTTP settings
backend_http_settings = {
  bhs-dev-app-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-dev-app"
    host_name                           = "public.dev.public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-dev-obs-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-dev-obs"
    host_name                           = "internal.dev.public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # # QA
  # bhs-qa-app-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-qa-app"
  #   host_name                           = "public.qa.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-qa-obs-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-qa-obs"
  #   host_name                           = "internal.qa.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

# Listeners
listeners = {
  # DEV APP (PUBLIC)
  lis-dev-app-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.dev.public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-main-dev"
  }

  lis-dev-app-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-main-dev"
  }

  # DEV OBS (PRIVATE ONLY)
  lis-dev-obs-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.dev.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "obs-internal-dev"
  }

  lis-dev-obs-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "obs-internal-dev"
  }

  # QA (enable when ready)
  # # QA APP (PUBLIC)
  # lis-qa-app-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "public.qa.public.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-main-qa"
  # }
  #
  # lis-qa-app-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "public.qa.public.intterra.io"
  #   ssl_certificate_name = "appgw-cert-pub-qa"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-main-qa"
  # }
  #
  # # QA OBS (PRIVATE ONLY)
  # lis-qa-obs-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.qa.public.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "obs-internal-qa"
  # }
  #
  # lis-qa-obs-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.qa.public.intterra.io"
  #   ssl_certificate_name = "appgw-cert-pub-qa"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "obs-internal-qa"
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

  redir-dev-obs-http-to-https-private = {
    target_listener_name = "lis-dev-obs-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # # QA
  # redir-qa-app-http-to-https-public = {
  #   target_listener_name = "lis-qa-app-https-public"
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

  # QA (enable when ready)
  # ,
  # {
  #   name                        = "rule-qa-app-http-redirect-public"
  #   priority                    = 110
  #   http_listener_name          = "lis-qa-app-http-public"
  #   redirect_configuration_name = "redir-qa-app-http-to-https-public"
  # },
  # {
  #   name                       = "rule-qa-app-https-public"
  #   priority                   = 120
  #   http_listener_name         = "lis-qa-app-https-public"
  #   backend_address_pool_name  = "be-qa-app"
  #   backend_http_settings_name = "bhs-qa-app-https"
  # },
  # {
  #   name                        = "rule-qa-obs-http-redirect-private"
  #   priority                    = 230
  #   http_listener_name          = "lis-qa-obs-http-private"
  #   redirect_configuration_name = "redir-qa-obs-http-to-https-private"
  # },
  # {
  #   name                       = "rule-qa-obs-https-private"
  #   priority                   = 240
  #   http_listener_name         = "lis-qa-obs-https-private"
  #   backend_address_pool_name  = "be-qa-obs"
  #   backend_http_settings_name = "bhs-qa-obs-https"
  # }
]
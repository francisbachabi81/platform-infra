product = "pub"
plane   = "prod"

location = "Central US"
region   = "cus"

tags = {
  purpose = "appgw-config"
  plane   = "prod"
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

  # PROD (PUBLIC APP)
  # - always: blockNonAllowedCountries
  # - plus:  blockNonvpnRestrictedPaths

  "app-prod-afd-only" = {
    mode = "Prevention"

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      # Only allow requests that came through this AFD profile
      {
        name     = "BlockNonAFD"
        priority = 5
        action   = "Block"
        match_conditions = [
          {
            match_variable     = "RequestHeaders"
            selector           = "X-Azure-FDID"
            operator           = "Equal"
            match_values       = ["cd34e1e1-284c-4f43-8732-5774f47b49ed"]
            negation_condition = true # block if header != expected (or missing)
          }
        ]
      }
    ]
  }

  "app-prod-somevpn" = {
    mode = "Prevention"

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      # blockNonAllowedCountries (implicit allow-list)
      {
        name     = "BlockNonAllowedCountries"
        priority = 5
        action   = "Block"
        match_conditions = [
          {
            match_variable     = "RemoteAddr"
            operator           = "GeoMatch"
            match_values       = ["US"]
            negation_condition = true
          }
        ]
      },

      # blockNonvpnRestrictedPaths (only restrict /admin AND require VPN)
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

  # PROD (OBS INTERNAL)
  # - always: blockNonAllowedCountries
  # - plus:  blockNonVpnAllPaths

  "app-prod-protected" = {
    mode = "Prevention"
    # vpn_cidrs = ["192.168.1.0/24"]
    # restricted_paths           = []
    # allowed_countries          = ["US"]
    # vpn_required_for_all_paths = true

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942330", "942340", "942370", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }

    custom_rules = [
      # blockNonAllowedCountries (implicit allow-list)
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

      # blockNonVpnAllPaths (force VPN for *everything*)
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
}

# certs (prod now; uat later)
ssl_certificates = {
  appgw-cert-pub-prod = {
    secret_name = "appgw-gateway-cert-public-production"
  }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

# Backends
backend_pools = {
  be-prod-app = { ip_addresses = ["20.84.136.238"] }
  be-prod-obs = { ip_addresses = ["172.14.2.9"] }

  be-prod-publiclayers-blob = {
    fqdns = ["sapublyrpubprodcus01.blob.core.windows.net"]
  }
}

# Probes
probes = {
  probe-prod-app = {
    protocol            = "Https"
    host                = "public.intterra.io"
    path                = "/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-prod-obs = {
    protocol            = "Https"
    host                = "internal.public.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-prod-publiclayers-blob = {
    protocol            = "Https"
    host                = "sapublyrpubprodcus01.blob.core.windows.net"
    path                = "/public-layers/health.txt"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    # Blob may return 404 if file missing; include it so AppGW still treats it healthy if desired.
    # (Ideally create the health blob and keep this 200-399 only.)
    match_status_codes = ["200-399", "404"]
  }
}

# Backend HTTP settings
backend_http_settings = {
  bhs-prod-app-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-prod-app"
    host_name                           = "public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-prod-obs-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-prod-obs"
    host_name                           = "internal.public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-prod-publiclayers-blob-https = {
    port                  = 443
    protocol              = "Https"
    request_timeout       = 30
    cookie_based_affinity = "Disabled"
    probe_name            = "probe-prod-publiclayers-blob"

    # Ensure Host header matches blob endpoint
    host_name                           = "sapublyrpubprodcus01.blob.core.windows.net"
    pick_host_name_from_backend_address = false
  }
}

# Listeners
listeners = {
  # PROD APP (PUBLIC)
  lis-prod-app-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-public.public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-prod-afd-only"
  }

  lis-prod-app-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-public.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-prod-afd-only"
  }

  lis-prod-publiclayers-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-publiclayers.public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-prod-afd-only"
  }

  lis-prod-publiclayers-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-publiclayers.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-prod-afd-only"
  }

  lis-prod-publiclayers-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "publiclayers.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-prod-protected"
  }

  lis-prod-publiclayers-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "publiclayers.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-prod-protected"
  }

  # PROD APP (PRIVATE) - public.intterra.io (same backend/pool/settings/probe/cert; private frontend; protected WAF)
  lis-prod-app-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.intterra.io"
    frontend           = "private"            # <- private interface (NOT public)
    waf_policy_key     = "app-prod-protected" # <- use protected WAF policy
  }

  lis-prod-app-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-prod"
    require_sni          = true
    frontend             = "private"            # <- private interface (NOT public)
    waf_policy_key       = "app-prod-protected" # <- use protected WAF policy
  }

  # PROD OBS (PRIVATE ONLY)
  lis-prod-obs-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-prod-protected"
  }

  lis-prod-obs-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-prod-protected"
  }
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

  redir-prod-publiclayers-http-to-https-public = {
    target_listener_name = "lis-prod-publiclayers-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  redir-prod-publiclayers-http-to-https-private = {
    target_listener_name = "lis-prod-publiclayers-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }
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
  # PROD APP (PRIVATE) - public.intterra.io
  {
    name                        = "rule-prod-app-http-redirect-private"
    priority                    = 170
    http_listener_name          = "lis-prod-app-http-private"
    redirect_configuration_name = "redir-prod-app-http-to-https-private"
  },
  {
    name                       = "rule-prod-app-https-private"
    priority                   = 180
    http_listener_name         = "lis-prod-app-https-private"
    backend_address_pool_name  = "be-prod-app"
    backend_http_settings_name = "bhs-prod-app-https"
  },
  # PublicLayers (PUBLIC)
  {
    name                        = "rule-prod-publiclayers-http-redirect-public"
    priority                    = 130
    http_listener_name          = "lis-prod-publiclayers-http-public"
    redirect_configuration_name = "redir-prod-publiclayers-http-to-https-public"
  },
  {
    name                       = "rule-prod-publiclayers-https-public"
    priority                   = 140
    http_listener_name         = "lis-prod-publiclayers-https-public"
    backend_address_pool_name  = "be-prod-publiclayers-blob"
    backend_http_settings_name = "bhs-prod-publiclayers-blob-https"
  },
  {
    name                        = "rule-prod-publiclayers-http-redirect-private"
    priority                    = 250
    http_listener_name          = "lis-prod-publiclayers-http-private"
    redirect_configuration_name = "redir-prod-publiclayers-http-to-https-private"
  },
  {
    name                       = "rule-prod-publiclayers-https-private"
    priority                   = 260
    http_listener_name         = "lis-prod-publiclayers-https-private"
    backend_address_pool_name  = "be-prod-publiclayers-blob"
    backend_http_settings_name = "bhs-prod-publiclayers-blob-https"
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
]
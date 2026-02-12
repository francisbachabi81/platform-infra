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

  # DEV (PUBLIC APP)
  # - always: blockNonAllowedCountries
  # - plus:  blockNonvpnRestrictedPaths

  "app-dev-afd-only" = {
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
            match_values       = ["9bd0434f-db6b-455a-a464-fadf05ec7970"]
            negation_condition = true # block if header != expected (or missing)
          }
        ]
      }
    ]
  }

  "app-dev-somevpn" = {
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

  # DEV (OBS INTERNAL)
  # - always: blockNonAllowedCountries
  # - plus:  blockNonVpnAllPaths

  "app-dev-protected" = {
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

# certs (dev now; qa later)
ssl_certificates = {
  appgw-cert-pub-dev = {
    secret_name = "appgw-gateway-cert-public-dev"
  }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

# Backends
backend_pools = {
  be-dev-app = { ip_addresses = ["20.84.250.156"] }
  be-dev-obs = { ip_addresses = ["172.10.2.8"] }

  be-dev-publiclayers-blob = {
    fqdns = ["sapublyrpubdevcus01.blob.core.windows.net"]
  }
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

  probe-dev-publiclayers-blob = {
    protocol            = "Https"
    host                = "sapublyrpubdevcus01.blob.core.windows.net"
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

  bhs-dev-publiclayers-blob-https = {
    port                  = 443
    protocol              = "Https"
    request_timeout       = 30
    cookie_based_affinity = "Disabled"
    probe_name            = "probe-dev-publiclayers-blob"

    # Ensure Host header matches blob endpoint
    host_name                           = "sapublyrpubdevcus01.blob.core.windows.net"
    pick_host_name_from_backend_address = false
  }
}

# Listeners
listeners = {
  # DEV APP (PUBLIC)
  lis-dev-app-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-public.dev.public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-dev-afd-only"
  }

  lis-dev-app-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-public.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-dev-afd-only"
  }

  # DEV APP (PRIVATE) - public.dev.public.intterra.io
  lis-dev-app-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.dev.public.intterra.io"
    frontend           = "private" # <- internal/private interface
    waf_policy_key     = "app-dev-protected"
  }
  lis-dev-app-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "private" # <- internal/private interface
    waf_policy_key       = "app-dev-protected"
  }

  lis-dev-publiclayers-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "origin-publiclayers.dev.public.intterra.io" #"origin-publiclayers.dev.public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-dev-afd-only"
  }

  lis-dev-publiclayers-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "origin-publiclayers.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-dev-afd-only"
  }

  # PublicLayers (PRIVATE)
  lis-dev-publiclayers-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "publiclayers.dev.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-dev-protected"
  }

  lis-dev-publiclayers-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "publiclayers.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-dev-protected"
  }

  # DEV OBS (PRIVATE ONLY)
  lis-dev-obs-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.dev.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "app-dev-protected"
  }

  lis-dev-obs-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.dev.public.intterra.io"
    ssl_certificate_name = "appgw-cert-pub-dev"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "app-dev-protected"
  }
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

  redir-dev-publiclayers-http-to-https-public = {
    target_listener_name = "lis-dev-publiclayers-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # DEV PUBLICLAYERS (PRIVATE)
  redir-dev-publiclayers-http-to-https-private = {
    target_listener_name = "lis-dev-publiclayers-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }
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

  # DEV APP (PRIVATE) - public.dev.public.intterra.io
  {
    name                        = "rule-dev-app-http-redirect-private"
    priority                    = 170
    http_listener_name          = "lis-dev-app-http-private"
    redirect_configuration_name = "redir-dev-app-http-to-https-private"
  },
  {
    name                       = "rule-dev-app-https-private"
    priority                   = 180
    http_listener_name         = "lis-dev-app-https-private"
    backend_address_pool_name  = "be-dev-app"
    backend_http_settings_name = "bhs-dev-app-https"
  },

  # PublicLayers (PUBLIC)
  {
    name                        = "rule-dev-publiclayers-http-redirect-public"
    priority                    = 130
    http_listener_name          = "lis-dev-publiclayers-http-public"
    redirect_configuration_name = "redir-dev-publiclayers-http-to-https-public"
  },
  {
    name                       = "rule-dev-publiclayers-https-public"
    priority                   = 140
    http_listener_name         = "lis-dev-publiclayers-https-public"
    backend_address_pool_name  = "be-dev-publiclayers-blob"
    backend_http_settings_name = "bhs-dev-publiclayers-blob-https"
  },

  # PublicLayers (PRIVATE)
  {
    name                        = "rule-dev-publiclayers-http-redirect-private"
    priority                    = 250
    http_listener_name          = "lis-dev-publiclayers-http-private"
    redirect_configuration_name = "redir-dev-publiclayers-http-to-https-private"
  },
  {
    name                       = "rule-dev-publiclayers-https-private"
    priority                   = 260
    http_listener_name         = "lis-dev-publiclayers-https-private"
    backend_address_pool_name  = "be-dev-publiclayers-blob"
    backend_http_settings_name = "bhs-dev-publiclayers-blob-https"
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
]
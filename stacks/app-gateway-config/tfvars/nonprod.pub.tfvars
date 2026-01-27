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

waf_policies = {
  dev = {
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
  appgw-gateway-cert-public-dev = {
    secret_name    = "appgw-gateway-cert-public-dev" # or whatever your wildcard secret is - wildcard-public-intterra-io
    secret_version = null
  }

  # appgw-gateway-cert-public-qa = {
  #   secret_name    = "appgw-gateway-cert-public-dev"
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
    host                = "dev.public.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-qa = {
  #   protocol            = "Https"
  #   host                = "qa.public.intterra.io"
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
    host_name           = "dev.public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-qa-https = {
  #   port                = 443
  #   protocol            = "Https"
  #   request_timeout     = 20
  #   cookie_based_affinity = "Disabled"
  #   probe_name          = "probe-qa"
  #   host_name           = "qa.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  # PUBLIC
  listener-dev-http-public = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.public.intterra.io"
    frontend                       = "public"
    waf_policy_key                 = "dev"
  }

  listener-dev-https-public = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.public.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-public-dev"
    require_sni                    = true
    frontend                       = "public"
    waf_policy_key                 = "dev"
  }

  # PRIVATE
  listener-dev-http-private = {
    frontend_port_name             = "feport-80"
    protocol                       = "Http"
    host_name                      = "dev.public.intterra.io"
    frontend                       = "private"
    waf_policy_key                 = "dev"
  }

  listener-dev-https-private = {
    frontend_port_name             = "feport-443"
    protocol                       = "Https"
    host_name                      = "dev.public.intterra.io"
    ssl_certificate_name           = "appgw-gateway-cert-public-dev"
    require_sni                    = true
    frontend                       = "private"
    waf_policy_key                 = "dev"
  }

  # PUBLIC
  # listener-qa-http-public = {
  #   frontend_port_name             = "feport-80"
  #   protocol                       = "Http"
  #   host_name                      = "qa.public.intterra.io"
  #   frontend                       = "public"
  #   waf_policy_key                 = "qa"
  # }

  # listener-qa-https-public = {
  #   frontend_port_name             = "feport-443"
  #   protocol                       = "Https"
  #   host_name                      = "qa.public.intterra.io"
  #   ssl_certificate_name           = "appgw-gateway-cert-public-qa"
  #   require_sni                    = true
  #   frontend                       = "public"
  #   waf_policy_key                 = "qa"
  # }

  # # PRIVATE
  # listener-qa-http-private = {
  #   frontend_port_name             = "feport-80"
  #   protocol                       = "Http"
  #   host_name                      = "qa.public.intterra.io"
  #   frontend                       = "private"
  #   waf_policy_key                 = "qa"
  # }

  # listener-qa-https-private = {
  #   frontend_port_name             = "feport-443"
  #   protocol                       = "Https"
  #   host_name                      = "qa.public.intterra.io"
  #   ssl_certificate_name           = "appgw-gateway-cert-public-qa"
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
# Core context (match dev structure)
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
  key                  = "shared-network/pub/cus/pr.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/pub/cus/pr.tfstate"
}

waf_policies = {
  prod = {
    mode              = "Prevention"
    vpn_cidrs         = ["192.168.1.0/24"]
    restricted_paths  = ["/admin"]
    blocked_countries = ["CN", "RU", "IR"] # https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/web-application-firewall/ag/geomatch-custom-rules.md

    # Disable managed rules by rule group + IDs
    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260","942340", "942370"]
      "REQUEST-931-APPLICATION-ATTACK-RFI" = ["931130"]
      # "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300"]
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
  appgw-gateway-cert-public-prod = {
    secret_name    = "appgw-gateway-cert-public-prod" # or wildcard secret name if you use one
    secret_version = null
  }

  # appgw-gateway-cert-public-uat = {
  #   secret_name    = "appgw-gateway-cert-public-uat" # or reuse prod wildcard if applicable
  #   secret_version = null
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-prod = { ip_addresses = ["62.10.212.49"] }
  bepool-uat  = { ip_addresses = ["62.10.212.50"] }
}

probes = {
  probe-prod = {
    protocol            = "Https"
    host                = "public.intterra.io"
    path                = "/api/identity/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-uat = {
  #   protocol            = "Https"
  #   host                = "uat.public.intterra.io"
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
    host_name                           = "public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-uat-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-uat"
  #   host_name                           = "uat.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  # PROD (PUBLIC)
  listener-prod-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "prod"
  }

  listener-prod-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-public-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "prod"
  }

  # PROD (PRIVATE)
  listener-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "prod"
  }

  listener-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-public-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "prod"
  }

  # # UAT (PUBLIC)
  # listener-uat-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.public.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "uat"
  # }

  # listener-uat-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-uat"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "uat"
  # }

  # # UAT (PRIVATE)
  # listener-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.public.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "uat"
  # }

  # listener-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-uat"
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
product  = "pub"
plane    = "prod"
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
  app-main-prod = {
    mode             = "Prevention"
    vpn_cidrs        = ["192.168.1.0/24"]
    restricted_paths = ["/admin"]
    allowed_countries = ["US"]

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942340", "942370", "942330", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }

  obs-internal-prod = {
    mode                       = "Prevention"
    vpn_cidrs                  = ["192.168.1.0/24"]
    restricted_paths           = []
    allowed_countries          = ["US"]
    vpn_required_for_all_paths = true

    disabled_rules_by_group = {
      "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942340", "942370", "942330", "942440"]
      "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
      "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
    }
  }

  # app-main-uat = {
  #   mode             = "Prevention"
  #   vpn_cidrs        = ["192.168.1.0/24"]
  #   restricted_paths = ["/admin"]
  #   allowed_countries = ["US"]
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942340", "942370", "942330", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  # }
  #
  # obs-internal-uat = {
  #   mode                       = "Prevention"
  #   vpn_cidrs                  = ["192.168.1.0/24"]
  #   restricted_paths           = []
  #   allowed_countries          = ["US"]
  #   vpn_required_for_all_paths = true
  #
  #   disabled_rules_by_group = {
  #     "REQUEST-942-APPLICATION-ATTACK-SQLI" = ["942200", "942260", "942340", "942370", "942330", "942440"]
  #     "REQUEST-931-APPLICATION-ATTACK-RFI"  = ["931130"]
  #     "REQUEST-920-PROTOCOL-ENFORCEMENT"    = ["920300", "920320"]
  #   }
  # }
}

ssl_certificates = {
  appgw-gateway-cert-public-prod = {
    secret_name    = "appgw-gateway-cert-public-prod"
    secret_version = null
  }

  # appgw-gateway-cert-public-uat = {
  #   secret_name    = "appgw-gateway-cert-public-uat"
  #   secret_version = null
  # }
}

frontend_ports = {
  feport-80  = 80
  feport-443 = 443
}

backend_pools = {
  bepool-app-main-prod     = { ip_addresses = ["62.10.212.49"] }
  bepool-obs-internal-prod = { ip_addresses = ["1.1.1.1"] }

  # bepool-app-main-uat     = { ip_addresses = ["62.10.212.50"] }
  # bepool-obs-internal-uat = { ip_addresses = ["1.1.1.1"] }
}

probes = {
  probe-app-main-prod = {
    protocol            = "Https"
    host                = "public.intterra.io"
    path                = "/health/ready"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  probe-obs-internal-prod = {
    protocol            = "Https"
    host                = "internal.public.intterra.io"
    path                = "/logs/login"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match_status_codes  = ["200-399"]
  }

  # probe-app-main-uat = {
  #   protocol            = "Https"
  #   host                = "uat.public.intterra.io"
  #   path                = "/health/ready"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
  #
  # probe-obs-internal-uat = {
  #   protocol            = "Https"
  #   host                = "internal.uat.public.intterra.io"
  #   path                = "/logs/login"
  #   interval            = 30
  #   timeout             = 30
  #   unhealthy_threshold = 3
  #   match_status_codes  = ["200-399"]
  # }
}

backend_http_settings = {
  bhs-app-main-prod-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-app-main-prod"
    host_name                           = "public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  bhs-obs-internal-prod-https = {
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    cookie_based_affinity               = "Disabled"
    probe_name                          = "probe-obs-internal-prod"
    host_name                           = "internal.public.intterra.io"
    pick_host_name_from_backend_address = false
  }

  # bhs-app-main-uat-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-app-main-uat"
  #   host_name                           = "uat.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
  #
  # bhs-obs-internal-uat-https = {
  #   port                                = 443
  #   protocol                            = "Https"
  #   request_timeout                     = 20
  #   cookie_based_affinity               = "Disabled"
  #   probe_name                          = "probe-obs-internal-uat"
  #   host_name                           = "internal.uat.public.intterra.io"
  #   pick_host_name_from_backend_address = false
  # }
}

listeners = {
  listener-app-main-prod-http-public = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "public.intterra.io"
    frontend           = "public"
    waf_policy_key     = "app-main-prod"
  }

  listener-app-main-prod-https-public = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "public.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-public-prod"
    require_sni          = true
    frontend             = "public"
    waf_policy_key       = "app-main-prod"
  }

  # listener-app-main-prod-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "public.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-main-prod"
  # }

  # listener-app-main-prod-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-prod"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-main-prod"
  # }

  listener-obs-internal-prod-http-private = {
    frontend_port_name = "feport-80"
    protocol           = "Http"
    host_name          = "internal.public.intterra.io"
    frontend           = "private"
    waf_policy_key     = "obs-internal-prod"
  }

  listener-obs-internal-prod-https-private = {
    frontend_port_name   = "feport-443"
    protocol             = "Https"
    host_name            = "internal.public.intterra.io"
    ssl_certificate_name = "appgw-gateway-cert-public-prod"
    require_sni          = true
    frontend             = "private"
    waf_policy_key       = "obs-internal-prod"
  }

  # listener-app-main-uat-http-public = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.public.intterra.io"
  #   frontend           = "public"
  #   waf_policy_key     = "app-main-uat"
  # }
  #
  # listener-app-main-uat-https-public = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-uat"
  #   require_sni          = true
  #   frontend             = "public"
  #   waf_policy_key       = "app-main-uat"
  # }
  #
  # listener-app-main-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "uat.public.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "app-main-uat"
  # }
  #
  # listener-app-main-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "uat.public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "app-main-uat"
  # }
  #
  # listener-obs-internal-uat-http-private = {
  #   frontend_port_name = "feport-80"
  #   protocol           = "Http"
  #   host_name          = "internal.uat.public.intterra.io"
  #   frontend           = "private"
  #   waf_policy_key     = "obs-internal-uat"
  # }
  #
  # listener-obs-internal-uat-https-private = {
  #   frontend_port_name   = "feport-443"
  #   protocol             = "Https"
  #   host_name            = "internal.uat.public.intterra.io"
  #   ssl_certificate_name = "appgw-gateway-cert-public-uat"
  #   require_sni          = true
  #   frontend             = "private"
  #   waf_policy_key       = "obs-internal-uat"
  # }
}

redirect_configurations = {
  redir-app-main-prod-http-to-https-public = {
    target_listener_name = "listener-app-main-prod-https-public"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-app-main-prod-http-to-https-private = {
  #   target_listener_name = "listener-app-main-prod-https-private"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }

  redir-obs-internal-prod-http-to-https-private = {
    target_listener_name = "listener-obs-internal-prod-https-private"
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
  }

  # redir-app-main-uat-http-to-https-public = {
  #   target_listener_name = "listener-app-main-uat-https-public"
  #   redirect_type        = "Permanent"
  #   include_path         = true
  #   include_query_string = true
  # }
  #
  # redir-app-main-uat-http-to-https-private = {
  #   target_listener_name = "listener-app-main-uat-https-private"
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
    name                        = "rule-app-main-prod-http-redirect-public"
    priority                    = 90
    http_listener_name          = "listener-app-main-prod-http-public"
    redirect_configuration_name = "redir-app-main-prod-http-to-https-public"
  },
  {
    name                       = "rule-app-main-prod-https-public"
    priority                   = 100
    http_listener_name         = "listener-app-main-prod-https-public"
    backend_address_pool_name  = "bepool-app-main-prod"
    backend_http_settings_name = "bhs-app-main-prod-https"
  },
  # {
  #   name                        = "rule-app-main-prod-http-redirect-private"
  #   priority                    = 190
  #   http_listener_name          = "listener-app-main-prod-http-private"
  #   redirect_configuration_name = "redir-app-main-prod-http-to-https-private"
  # },
  # {
  #   name                       = "rule-app-main-prod-https-private"
  #   priority                   = 200
  #   http_listener_name         = "listener-app-main-prod-https-private"
  #   backend_address_pool_name  = "bepool-app-main-prod"
  #   backend_http_settings_name = "bhs-app-main-prod-https"
  # },
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

  # {
  #   name                        = "rule-app-main-uat-http-redirect-public"
  #   priority                    = 290
  #   http_listener_name          = "listener-app-main-uat-http-public"
  #   redirect_configuration_name = "redir-app-main-uat-http-to-https-public"
  # },
  # {
  #   name                       = "rule-app-main-uat-https-public"
  #   priority                   = 300
  #   http_listener_name         = "listener-app-main-uat-https-public"
  #   backend_address_pool_name  = "bepool-app-main-uat"
  #   backend_http_settings_name = "bhs-app-main-uat-https"
  # },
  # {
  #   name                        = "rule-app-main-uat-http-redirect-private"
  #   priority                    = 390
  #   http_listener_name          = "listener-app-main-uat-http-private"
  #   redirect_configuration_name = "redir-app-main-uat-http-to-https-private"
  # },
  # {
  #   name                       = "rule-app-main-uat-https-private"
  #   priority                   = 400
  #   http_listener_name         = "listener-app-main-uat-https-private"
  #   backend_address_pool_name  = "bepool-app-main-uat"
  #   backend_http_settings_name = "bhs-app-main-uat-https"
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
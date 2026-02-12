product = "pub"
plane   = "prod"

# env kept only for tagging/naming if needed elsewhere
env = "prod"

location = "Central US"
region   = "cus"

enable_origin_private_link = true

tags = {
  purpose = "afd-config"
  plane   = "prod"
}

shared_network_state = {
  resource_group_name  = "rg-core-tfstate-01"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/pub/nonprod/terraform.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-tfstate-01"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/pub/np/terraform.tfstate"
}

waf_resource_group_name = "rg-pub-pr-cus-net-01"

# ------------------------------------------------------------
# ORIGIN GROUPS (prod + uat together)
# ------------------------------------------------------------
origin_groups = {
  # App backends
  app-prod = {
    probe = {
      interval_in_seconds = 30
      path                = "/health/ready"
      protocol            = "Https"
      request_type        = "GET"
    }
  }

  # app-uat = {
  #   probe = {
  #     interval_in_seconds = 30
  #     path                = "/health/ready"
  #     protocol            = "Https"
  #     request_type        = "GET"
  #   }
  # }

  # Blob backends
  layers-prod = {
    probe = {
      interval_in_seconds = 60
      path                = "/public-layers/health.txt"
      protocol            = "Https"
      request_type        = "GET"
    }
  }

  # layers-uat = {
  #   probe = {
  #     interval_in_seconds = 60
  #     path                = "/public-layers/health.txt"
  #     protocol            = "Https"
  #     request_type        = "GET"
  #   }
  # }
}

# ------------------------------------------------------------
# ORIGINS (prod + uat together)
# ------------------------------------------------------------
origins = {
  # AppGW (PROD)
  app-prod-origin = {
    origin_group_key               = "app-prod"
    host_name                      = "origin-public.public.intterra.io"
    https_port                     = 443
    origin_host_header             = "origin-public.public.intterra.io"
    certificate_name_check_enabled = true

    private_link = {
      kind            = "appgw_pls"
      location        = "centralus"
      pls_id          = "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-pr-cus-01_pl"
      request_message = "AFD Premium to AppGW - app"
    }
  }

  # AppGW (UAT)
  # app-uat-origin = {
  #   origin_group_key               = "app-uat"
  #   host_name                      = "origin-public.uat.public.intterra.io"
  #   https_port                     = 443
  #   origin_host_header             = "origin-public.uat.public.intterra.io"
  #   certificate_name_check_enabled = true
  #
  #   private_link = {
  #     kind            = "appgw_pls"
  #     location        = "centralus"
  #     pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
  #     request_message = "AFD Premium to AppGW - app"
  #   }
  # }

  # Blob (PROD)
  layers-prod-origin = {
    origin_group_key               = "layers-prod"
    host_name                      = "origin-publiclayers.public.intterra.io"
    https_port                     = 443
    origin_host_header             = "origin-publiclayers.public.intterra.io"
    certificate_name_check_enabled = true

    private_link = {
      kind            = "appgw_pls"
      location        = "centralus"
      pls_id          = "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-pr-cus-01_pl"
      request_message = "AFD Premium to AppGW - publiclayers"
    }
  }

  # Blob (UAT)
  # layers-uat-origin = {
  #   origin_group_key               = "layers-uat"
  #   host_name                      = "origin-publiclayers.uat.public.intterra.io"
  #   https_port                     = 443
  #   origin_host_header             = "origin-publiclayers.uat.public.intterra.io"
  #   certificate_name_check_enabled = true
  #
  #   private_link = {
  #     kind            = "appgw_pls"
  #     location        = "centralus"
  #     pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
  #     request_message = "AFD Premium to AppGW - publiclayers"
  #   }
  # }
}

# ------------------------------------------------------------
# Customer certs (prod + uat together)
# ------------------------------------------------------------
customer_certificates = {
  public-prod-public = {
    key_vault_certificate_id = "https://kvt-pub-pr-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-production/71396477c536468f9207268f3614da5a"
  }

  # public-uat-public = {
  #   key_vault_certificate_id = "REPLACE_WITH_UAT_CERT"
  # }

  publiclayers-prod-public = {
    key_vault_certificate_id = "https://kvt-pub-pr-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-production/71396477c536468f9207268f3614da5a"
  }

  # publiclayers-uat-public = {
  #   key_vault_certificate_id = "REPLACE_WITH_UAT_CERT"
  # }
}

# ------------------------------------------------------------
# CUSTOM DOMAINS
# ------------------------------------------------------------
custom_domains = {
  # App domain (PROD)
  app-prod-public = {
    host_name                = "public.intterra.io"
    certificate_type         = "CustomerCertificate"
    customer_certificate_key = "public-prod-public"
  }

  # App domain (UAT)
  # app-uat-public = {
  #   host_name                = "uat.public.intterra.io"
  #   certificate_type         = "CustomerCertificate"
  #   customer_certificate_key = "public-uat-public"
  # }

  # Blob domain (PROD)
  publiclayers-prod-public = {
    host_name                = "publiclayers.public.intterra.io"
    certificate_type         = "CustomerCertificate"
    customer_certificate_key = "publiclayers-prod-public"
  }

  # Blob domain (UAT)
  # publiclayers-uat-public = {
  #   host_name                = "publiclayers.uat.public.intterra.io"
  #   certificate_type         = "CustomerCertificate"
  #   customer_certificate_key = "publiclayers-uat-public"
  # }
}

# ------------------------------------------------------------
# ROUTES
# ------------------------------------------------------------
routes = {
  # App route (PROD)
  app-prod-public-route = {
    origin_group_key       = "app-prod"
    origin_keys            = ["app-prod-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["app-prod-public"]
    link_to_default_domain = false
  }

  # App route (UAT)
  # app-uat-public-route = {
  #   origin_group_key       = "app-uat"
  #   origin_keys            = ["app-uat-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["app-uat-public"]
  #   link_to_default_domain = false
  # }

  # Blob route (PROD)
  publiclayers-prod-public-route = {
    origin_group_key       = "layers-prod"
    origin_keys            = ["layers-prod-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["publiclayers-prod-public"]
    link_to_default_domain = false
  }

  # Blob route (UAT)
  # publiclayers-uat-public-route = {
  #   origin_group_key       = "layers-uat"
  #   origin_keys            = ["layers-uat-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["publiclayers-uat-public"]
  #   link_to_default_domain = false
  # }
}

# ------------------------------------------------------------
# WAF (Front Door)
# ------------------------------------------------------------
waf_policy = {
  sku_name = "Premium_AzureFrontDoor"
  mode     = "Prevention"

  managed_rule = {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
  }

  associated_custom_domain_keys = [
    "app-prod-public",
    # "app-uat-public",
    "publiclayers-prod-public",
    # "publiclayers-uat-public",
  ]

  patterns_to_match = ["/*"]

  custom_rules = [
    {
      name               = "BlockNonUS"
      priority           = 5
      action             = "Block"
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      match_values       = ["US"]
      negation_condition = true
    }
  ]
}
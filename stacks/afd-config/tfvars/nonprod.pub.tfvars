product = "pub"
plane   = "nonprod"

# env is no longer used to "select" dev vs qa in Model A.
# Keep it only if you use it for tagging or naming elsewhere.
env = "dev"

location = "Central US"
region   = "cus"

enable_origin_private_link = true

tags = {
  purpose = "afd-config"
  plane   = "nonprod"
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

waf_resource_group_name = "rg-pub-np-cus-net-01" # adjust

# ------------------------------------------------------------
# ORIGIN GROUPS (dev + qa together)
# ------------------------------------------------------------
origin_groups = {
  # App backends
  app-dev = {
    probe = {
      interval_in_seconds = 30
      path                = "/health/ready"
      protocol            = "Https"
      request_type        = "GET"
    }
  }

  # app-qa = {
  #   probe = {
  #     interval_in_seconds = 30
  #     path                = "/health/ready"
  #     protocol            = "Https"
  #     request_type        = "GET"
  #   }
  # }

  # Blob backends (public layers)
  layers-dev = {
    probe = {
      interval_in_seconds = 60
      path                = "/public-layers/health.txt" # blob endpoints usually respond here
      protocol            = "Https"
      request_type        = "GET"
    }
  }

  # layers-qa = {
  #   probe = {
  #     interval_in_seconds = 60
  #     path                = "/public-layers/health.txt" # keep consistent with dev
  #     protocol            = "Https"
  #     request_type        = "GET"
  #   }
  # }
}

# ------------------------------------------------------------
# ORIGINS (dev + qa together)
# ------------------------------------------------------------
origins = {
  # AppGW (DEV)
  app-dev-origin = {
    origin_group_key               = "app-dev"
    host_name                      = "origin-public.dev.public.intterra.io" # A record -> AppGW Public IP
    https_port                     = 443
    origin_host_header             = "origin-public.dev.public.intterra.io"
    certificate_name_check_enabled = true

    private_link = {
      kind            = "appgw_pls" # signals AzAPI path
      location        = "centralus"
      pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
      request_message = "AFD Premium to AppGW (nonprod) - app"
    }
  }

  # AppGW (QA) - placeholder mirrors dev naming
  # app-qa-origin = {
  #   origin_group_key               = "app-qa"
  #   host_name                      = "origin-public.qa.public.intterra.io"
  #   https_port                     = 443
  #   origin_host_header             = "origin-public.qa.public.intterra.io"
  #   certificate_name_check_enabled = true
  #
  #   private_link = {
  #     kind            = "appgw_pls"
  #     location        = "centralus"
  #     pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
  #     request_message = "AFD Premium to AppGW (nonprod) - app"
  #   }
  # }

  # Blob (DEV)
  layers-dev-origin = {
    origin_group_key               = "layers-dev"
    host_name                      = "origin-publiclayers.dev.public.intterra.io"
    https_port                     = 443
    origin_host_header             = "origin-publiclayers.dev.public.intterra.io"
    certificate_name_check_enabled = true

    private_link = {
      kind            = "appgw_pls"
      location        = "centralus"
      pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
      request_message = "AFD Premium to AppGW (nonprod) - publiclayers"
    }
  }

  # Blob (QA) - placeholder mirrors dev naming
  # layers-qa-origin = {
  #   origin_group_key               = "layers-qa"
  #   host_name                      = "origin-publiclayers.qa.public.intterra.io"
  #   https_port                     = 443
  #   origin_host_header             = "origin-publiclayers.qa.public.intterra.io"
  #   certificate_name_check_enabled = true
  #
  #   private_link = {
  #     kind            = "appgw_pls"
  #     location        = "centralus"
  #     pls_id          = "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-pub-np-cus-01_pl"
  #     request_message = "AFD Premium to AppGW (nonprod)"
  #   }
  # }
}

# ------------------------------------------------------------
# Customer certs (dev + qa together)
# ------------------------------------------------------------
customer_certificates = {
  public-dev-public = {
    key_vault_certificate_id = "https://kvt-pub-np-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-dev/9da411da5fa94da889d0230f3d31dbb1"
  }

  # public-qa-public = {
  #   key_vault_certificate_id = "https://kvt-pub-np-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-qa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  # }

  publiclayers-dev-public = {
    key_vault_certificate_id = "https://kvt-pub-np-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-dev/9da411da5fa94da889d0230f3d31dbb1"
  }

  # publiclayers-qa-public = {
  #   key_vault_certificate_id = "https://kvt-pub-np-cus-core-01.vault.azure.net/certificates/appgw-gateway-cert-public-qa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  # }
}

# ------------------------------------------------------------
# CUSTOM DOMAINS (dev + qa together)
# - REMOVED: public-dev-public
# ------------------------------------------------------------
custom_domains = {
  # App domain (DEV) - keep the main app hostname only
  app-dev-public = {
    host_name                = "public.dev.public.intterra.io"
    certificate_type         = "CustomerCertificate"
    customer_certificate_key = "public-dev-public"
  }

  # App domain (QA) - placeholder mirrors dev pattern
  # app-qa-public = {
  #   host_name                = "public.qa.public.intterra.io"
  #   certificate_type         = "CustomerCertificate"
  #   customer_certificate_key = "public-qa-public"
  # }

  # Blob domain (DEV)
  publiclayers-dev-public = {
    host_name                = "publiclayers.dev.public.intterra.io"
    certificate_type         = "CustomerCertificate"
    customer_certificate_key = "publiclayers-dev-public"
  }

  # Blob domain (QA) - placeholder mirrors dev pattern
  # publiclayers-qa-public = {
  #   host_name                = "publiclayers.qa.public.intterra.io"
  #   certificate_type         = "CustomerCertificate"
  #   customer_certificate_key = "publiclayers-qa-public"
  # }
}

# ------------------------------------------------------------
# ROUTES (dev + qa together)
# - UPDATED: removed public-dev-public from custom_domain_keys
# ------------------------------------------------------------
routes = {
  # App route (DEV)
  app-dev-public-route = {
    origin_group_key       = "app-dev"
    origin_keys            = ["app-dev-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["app-dev-public"]
    link_to_default_domain = false
  }

  # App route (QA) - placeholder mirrors dev pattern
  # public-qa-public-route = {
  #   origin_group_key       = "app-qa"
  #   origin_keys            = ["app-qa-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["app-qa-public"]
  #   link_to_default_domain = false
  # }

  # Blob route (DEV)
  publiclayers-dev-public-route = {
    origin_group_key       = "layers-dev"
    origin_keys            = ["layers-dev-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["publiclayers-dev-public"]
    link_to_default_domain = false
  }

  # Blob route (QA) - placeholder mirrors dev pattern
  # publiclayers-qa-public-route = {
  #   origin_group_key       = "layers-qa"
  #   origin_keys            = ["layers-qa-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["publiclayers-qa-public"]
  #   link_to_default_domain = false
  # }
}

# ------------------------------------------------------------
# OPTIONAL WAF (Front Door)
# - UPDATED: removed public-dev-public from associated_custom_domain_keys
# ------------------------------------------------------------
waf_policy = {
  sku_name = "Premium_AzureFrontDoor" # "Standard_AzureFrontDoor", "Premium_AzureFrontDoor"
  mode     = "Prevention"

  managed_rule = {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
  }

  associated_custom_domain_keys = [
    "app-dev-public",
    # "app-qa-public",
    "publiclayers-dev-public",
    # "publiclayers-qa-public",
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
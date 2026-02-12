product = "hrz"
plane   = "nonprod"

# env is no longer used to "select" dev vs qa in Model A.
# Keep it only if you use it for tagging or naming elsewhere.
env = "dev"

location = "USGov Arizona"
region   = "usaz"

enable_origin_private_link = true

tags = {
  purpose = "afd-config"
  plane   = "nonprod"
}

shared_network_state = {
  resource_group_name  = "rg-core-tfstate-01"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/hrz/nonprod/terraform.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-tfstate-01"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/hrz/np/terraform.tfstate"
}

waf_resource_group_name = "rg-hrz-np-usaz-net-01" # adjust

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
}

# ------------------------------------------------------------
# ORIGINS (dev + qa together)
# ------------------------------------------------------------
origins = {
  # AppGW (DEV)
  app-dev-origin = {
    origin_group_key               = "app-dev"
    host_name                      = "origin-horizon.dev.horizon.intterra.io" # A record -> AppGW horizon IP (HRZ)
    https_port                     = 443
    origin_host_header             = "origin-horizon.dev.horizon.intterra.io"
    certificate_name_check_enabled = true

    # private_link = {
    #   kind            = "appgw_pls" # signals AzAPI path
    #   location        = "usgovarizona"
    #   pls_id          = "/subscriptions/<HRZ_SUBSCRIPTION_ID>/resourceGroups/rg-hrz-np-usaz-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-hrz-np-usaz-01_pl"
    #   request_message = "AFD Premium to AppGW (nonprod) - app"
    # }
  }

  # AppGW (QA) - placeholder mirrors dev naming
  # app-qa-origin = {
  #   origin_group_key               = "app-qa"
  #   host_name                      = "origin-horizon.qa.horizon.intterra.io"
  #   https_port                     = 443
  #   origin_host_header             = "origin-horizon.qa.horizon.intterra.io"
  #   certificate_name_check_enabled = true
  #
  #   private_link = {
  #     kind            = "appgw_pls"
  #     location        = "usgovarizona"
  #     pls_id          = "/subscriptions/<HRZ_SUBSCRIPTION_ID>/resourceGroups/rg-hrz-np-usaz-net-01/providers/Microsoft.Network/privateLinkServices/_e41f87a2_agw-hrz-np-usaz-01_pl"
  #     request_message = "AFD Premium to AppGW (nonprod) - app"
  #   }
  # }
}

# ------------------------------------------------------------
# Customer certs (dev + qa together)
#   NOTE: For Front Door secret, this MUST be a Key Vault *certificate ID* URL.
# - HRZ: only app cert(s)
# ------------------------------------------------------------
customer_certificates = {
  app-dev-horizon = {
    key_vault_certificate_id = "https://kvt-hrz-np-usaz-core-01.vault.usgovcloudapi.net/certificates/appgw-gateway-cert-horizon-dev/5493e9da851b41c49d2ea5a8cf76b239"
  }

  # app-qa-horizon = {
  #   key_vault_certificate_id = "https://kvt-hrz-np-usaz-core-01.vault.usgovcloudapi.net/certificates/appgw-gateway-cert-app-qa/<CERT_VERSION_GUID>"
  # }
}

# ------------------------------------------------------------
# CUSTOM DOMAINS (dev + qa together)
# ------------------------------------------------------------
custom_domains = {
  # App domain (DEV)
  app-dev-horizon = {
    host_name                = "dev.horizon.intterra.io"
    certificate_type         = "CustomerCertificate"
    customer_certificate_key = "app-dev-horizon"
  }

  # App domain (QA) - placeholder mirrors dev pattern
  # app-qa-horizon = {
  #   host_name                = "qa.horizon.intterra.io"
  #   certificate_type         = "CustomerCertificate"
  #   customer_certificate_key = "app-qa-horizon"
  # }
}

# ------------------------------------------------------------
# ROUTES (dev + qa together)
# ------------------------------------------------------------
routes = {
  # App route (DEV)
  app-dev-horizon-route = {
    origin_group_key       = "app-dev"
    origin_keys            = ["app-dev-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["app-dev-horizon"]
    link_to_default_domain = false
  }

  # App route (QA) - placeholder mirrors dev pattern
  # app-qa-horizon-route = {
  #   origin_group_key       = "app-qa"
  #   origin_keys            = ["app-qa-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["app-qa-horizon"]
  #   link_to_default_domain = false
  # }
}

# OPTIONAL WAF (Front Door)
waf_policy = {
  sku_name = "Standard_AzureFrontDoor" # "Standard_AzureFrontDoor", "Premium_AzureFrontDoor"
  mode     = "Prevention"

  managed_rule = {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
  }

  associated_custom_domain_keys = [
    "app-dev-horizon",
    # "app-qa-horizon",
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
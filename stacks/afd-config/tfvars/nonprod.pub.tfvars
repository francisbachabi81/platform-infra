product  = "pub"
plane    = "nonprod"
env      = "dev"

location = "Central US"
region   = "cus"

tags = {
  purpose = "afd-config"
  plane   = "nonprod"
}

shared_network_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "shared-network/pub/nonprod/terraform.tfstate"
}

core_state = {
  resource_group_name  = "rg-core-infra-state"
  storage_account_name = "sacoretfstateinfra"
  container_name       = "tfstate"
  key                  = "core/pub/np/terraform.tfstate"
}

waf_resource_group_name = "rg-pub-np-cus-net-01" # adjust

# ------------------------------------------------------------
# ORIGIN GROUPS
# ------------------------------------------------------------
origin_groups = {
  # DEV
  app-dev = {
    probe = {
      protocol = "Https"
      path     = "/health/ready"
    }
  }

  # QA (enable when ready)
  # app-qa = {
  #   probe = {
  #     protocol = "Https"
  #     path     = "/health/ready"
  #   }
  # }
}

# ------------------------------------------------------------
# ORIGINS
#   NOTE: host_name can be an IP or FQDN.
#   origin_host_header is what AFD sends to your backend.
#   Today: public.<env>.public.intterra.io (may change later)
# ------------------------------------------------------------
origins = {
  # DEV
  app-dev-origin = {
    origin_group_key   = "app-dev"
    host_name          = "<APPGW_PUBLIC_IP_OR_FQDN>" #appgw.dev.public.intterra.io → A record to AppGW Public IP (origin target)
    https_port         = 443
    origin_host_header = "public.dev.public.intterra.io" # may change later
  }

  # QA (enable when ready)
  # app-qa-origin = {
  #   origin_group_key   = "app-qa"
  #   host_name          = "<APPGW_PUBLIC_IP_OR_FQDN>"
  #   https_port         = 443
  #   origin_host_header = "public.qa.public.intterra.io" # may change later
  # }
}

# ------------------------------------------------------------
# CUSTOM DOMAINS
#   AFD should ONLY serve:
#     - dev.public.intterra.io
#     - qa.public.intterra.io (later)
# ------------------------------------------------------------
custom_domains = {
  # DEV
  dev-public = {
    host_name        = "dev.public.intterra.io"
    certificate_type = "ManagedCertificate"
  }

  # QA (enable when ready)
  # qa-public = {
  #   host_name        = "qa.public.intterra.io"
  #   certificate_type = "ManagedCertificate"
  # }
}

# ------------------------------------------------------------
# ROUTES
#   Map the public custom domain to the app origin group.
# ------------------------------------------------------------
routes = {
  # DEV
  dev-public-route = {
    origin_group_key       = "app-dev"
    origin_keys            = ["app-dev-origin"]
    patterns_to_match      = ["/*"]
    supported_protocols    = ["Http", "Https"]
    https_redirect_enabled = true
    forwarding_protocol    = "HttpsOnly"
    custom_domain_keys     = ["dev-public"]
  }

  # QA (enable when ready)
  # qa-public-route = {
  #   origin_group_key       = "app-qa"
  #   origin_keys            = ["app-qa-origin"]
  #   patterns_to_match      = ["/*"]
  #   supported_protocols    = ["Http", "Https"]
  #   https_redirect_enabled = true
  #   forwarding_protocol    = "HttpsOnly"
  #   custom_domain_keys     = ["qa-public"]
  # }
}

# ------------------------------------------------------------
# OPTIONAL WAF (Front Door)
#   Associate only the public domains served by AFD.
# ------------------------------------------------------------
waf_policy = {
  sku_name = "Standard_AzureFrontDoor"
  mode     = "Prevention"

  managed_rule = {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
  }

  associated_custom_domain_keys = [
    "dev-public",
    # "qa-public", # enable when ready
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
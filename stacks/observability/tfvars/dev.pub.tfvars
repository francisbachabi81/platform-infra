# ---- Observability (PUB | dev) ----
product  = "pub"
env      = "dev"
# plane is derived from env; to pass explicitly: plane = "nonprod"
location = "Central US"

# Optional Action Group name override
ag_name  = "ag-obs-pub-dev-cus-01"

# Use either the structured list below OR simple alert_emails = [...]
action_group_email_receivers = [
  {
    name                    = "Ops"
    email_address           = "azure-alerts@intterragroup.com"
    use_common_alert_schema = true
  },
  {
    name          = "OnCall"
    email_address = "francis.bachabi@intterragroup.com"
  }
]

# alert_emails = ["ops@example.com"]

# Extra tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}

# env_rg_name = "rg-pub-dev-cus-01"
# env_subscription_id = "57f8aa30-981c-4764-94f6-6691c4d5c01c"
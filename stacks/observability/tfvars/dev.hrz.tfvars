# ---- Observability (HRZ | dev) ----
product  = "hrz"
env      = "dev"
# plane is derived from env; to pass explicitly: plane = "nonprod"
location    = "USGov Arizona"

# Optional Action Group name override
ag_name  = "ag-obs-hrz-dev-cus-01"

# Use either the structured list below OR simple alert_emails = [...]
action_group_email_receivers = [
  {
    name                    = "Ops"
    email_address           = "ops@example.gov"
    use_common_alert_schema = true
  },
  {
    name          = "OnCall"
    email_address = "oncall@example.gov"
  }
]

# alert_emails = ["ops@example.com"]

# Extra tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}

# env_rg_name = "rg-hrz-dev-cus-01"
env_subscription_id = "62ae6908-cbcb-40cb-8773-54bd318ff7f9"
# ---- Observability (PUB | dev) ----
product  = "pub"
env      = "dev"
# plane is derived from env; if you want to pass plane explicitly, use: plane = "nonprod"
location = "Central US"
region   = "cus"

# Optional, informational only (declared and safe to keep)
law_name = "law-pub-dev-cus-01"
ag_name  = "ag-obs-pub-dev-cus-01"

# Use either the structured list below OR simple alert_emails = [...]
action_group_email_receivers = [
  { name = "Ops", email_address = "ops@example.com" }
]

# If you prefer the simple list instead, comment the block above and use:
# alert_emails = ["ops@example.com"]

# Extra tags (now applied to the Action Group)
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}

env_rg_name="rg-pub-dev-cus-01"
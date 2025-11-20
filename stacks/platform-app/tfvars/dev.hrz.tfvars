# ---- Observability (HRZ | dev) ----
env         = "dev"
product     = "hrz"
plane       = "np"                       # dev/qa => np, uat/prod => pr
location    = "USGov Arizona"
region      = "usaz"

# Naming
rg_name     = "rg-obs-hrz-dev-usaz-01"
law_name    = "law-hrz-dev-usaz-01"
ag_name     = "ag-obs-hrz-dev-usaz-01"   # Action Group

# Log Analytics
law_sku             = "PerGB2018"
law_retention_days  = 30

# Solutions / DCR flags
enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

# Action Group email receivers
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

# Diagnostics categories to enable (add/remove as needed)
diag_categories = [
  "AuditEvent",
  "SignInLogs",
  "Security",
  "AppServiceHTTPLogs",
  "StorageRead",
  "StorageWrite",
]

# Optional tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}

servicebus_queues = [
  "incident-processor"
]

# servicebus_topics = [
#   "topic1",
#   "topic3",
# ]

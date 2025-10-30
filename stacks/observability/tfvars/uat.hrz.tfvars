# ---- Observability (HRZ | uat) ----
env         = "uat"
product     = "hrz"
plane       = "pr"
location    = "USGov Arizona"
region      = "usaz"

rg_name     = "rg-obs-hrz-uat-usaz-01"
law_name    = "law-hrz-uat-usaz-01"
ag_name     = "ag-obs-hrz-uat-usaz-01"

law_sku             = "PerGB2018"
law_retention_days  = 60

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "UAT-Ops", email_address = "uat-ops@example.gov" }
]

diag_categories = ["AuditEvent","SignInLogs","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", layer = "platform" }

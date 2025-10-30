# ---- Observability (HRZ | qa) ----
env         = "qa"
product     = "hrz"
plane       = "np"
location    = "USGov Arizona"
region      = "usaz"

rg_name     = "rg-obs-hrz-qa-usaz-01"
law_name    = "law-hrz-qa-usaz-01"
ag_name     = "ag-obs-hrz-qa-usaz-01"

law_sku             = "PerGB2018"
law_retention_days  = 30

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "QA-Ops", email_address = "qa-ops@example.gov" }
]

diag_categories = ["AuditEvent","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", layer = "platform" }

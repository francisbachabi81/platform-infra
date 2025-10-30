# ---- Observability (HRZ | prod) ----
env         = "prod"
product     = "hrz"
plane       = "pr"
location    = "USGov Arizona"
region      = "usaz"

rg_name     = "rg-obs-hrz-prod-usaz-01"
law_name    = "law-hrz-prod-usaz-01"
ag_name     = "ag-obs-hrz-prod-usaz-01"

law_sku             = "PerGB2018"
law_retention_days  = 90

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "Ops-Primary", email_address = "ops-primary@example.gov" },
  { name = "Ops-Secondary", email_address = "ops-secondary@example.gov" }
]

diag_categories = ["AuditEvent","SignInLogs","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", criticality = "high", layer = "platform" }

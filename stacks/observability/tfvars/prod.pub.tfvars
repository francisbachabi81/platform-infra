# ---- Observability (PUB | prod) ----
env         = "prod"
product     = "pub"
plane       = "pr"
location    = "Central US"
region      = "cus"

rg_name     = "rg-obs-pub-prod-cus-01"
law_name    = "law-pub-prod-cus-01"
ag_name     = "ag-obs-pub-prod-cus-01"

law_sku             = "PerGB2018"
law_retention_days  = 90

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "Ops-Primary", email_address = "ops-primary@example.com" },
  { name = "Ops-Secondary", email_address = "ops-secondary@example.com" }
]

diag_categories = ["AuditEvent","SignInLogs","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", criticality = "high", layer = "platform" }

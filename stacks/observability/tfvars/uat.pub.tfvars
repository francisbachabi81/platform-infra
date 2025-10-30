# ---- Observability (PUB | uat) ----
env         = "uat"
product     = "pub"
plane       = "pr"
location    = "Central US"
region      = "cus"

rg_name     = "rg-obs-pub-uat-cus-01"
law_name    = "law-pub-uat-cus-01"
ag_name     = "ag-obs-pub-uat-cus-01"

law_sku             = "PerGB2018"
law_retention_days  = 60

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "UAT-Ops", email_address = "uat-ops@example.com" }
]

diag_categories = ["AuditEvent","SignInLogs","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", layer = "platform" }

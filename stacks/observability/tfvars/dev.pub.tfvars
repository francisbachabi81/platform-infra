# ---- Observability (PUB | dev) ----
env         = "dev"
product     = "pub"
plane       = "np"
location    = "Central US"
region      = "cus"

rg_name     = "rg-obs-pub-dev-cus-01"
law_name    = "law-pub-dev-cus-01"
ag_name     = "ag-obs-pub-dev-cus-01"

law_sku             = "PerGB2018"
law_retention_days  = 30

enable_container_insights = true
enable_vm_insights        = true
enable_ama_dcr            = true

action_group_email_receivers = [
  { name = "Ops", email_address = "ops@example.com" }
]

diag_categories = ["AuditEvent","Security","AppServiceHTTPLogs","StorageRead","StorageWrite"]
tags_extra = { purpose = "observability", layer = "platform" }

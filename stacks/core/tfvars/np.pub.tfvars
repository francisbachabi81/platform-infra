plane           = "np"
product         = "pub"
location        = "Central US"
region          = "cus"

tags = {
  plane   = "np"
  product = "pub"
}

law_sku                 = "PerGB2018"
law_retention_days      = 30
appi_internet_ingestion_enabled = false
appi_internet_query_enabled     = false

state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_state_enabled = true

action_group_email_receivers = [
  {
    name                    = "Ops Manager"
    email_address           = "francis.bachabi@intterragroup.com"
    use_common_alert_schema = true
  },
  {
    name                    = "Cloud Ops Alerts"
    email_address           = "cloudops@intterragroup.com"
    use_common_alert_schema = true
  }
]

enable_custom_domain    = true
custom_domain_name      = "dev.public.intterra.io"
associate_custom_domain = false
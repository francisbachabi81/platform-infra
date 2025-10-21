plane           = "np"
product         = "hrz"
location        = "USGov Arizona"
region          = "usaz"

subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

tags = {
  plane   = "np"
  product = "hrz"
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
    name                    = "Primary On-Call"
    email_address           = "francis.bachabi@intterragoup.com"
    # use_common_alert_schema defaults to true (omitted)
  }#,
  # {
  #   name                    = "Ops Manager"
  #   email_address           = "ops.manager@intterra.example"
  #   use_common_alert_schema = false
  # }
]
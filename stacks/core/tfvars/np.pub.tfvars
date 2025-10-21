plane           = "np"
product         = "pub"
location        = "Central US"
region          = "cus"

subscription_id = "ee8a4693-54d4-4de8-842b-b6f35fc0674d"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

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
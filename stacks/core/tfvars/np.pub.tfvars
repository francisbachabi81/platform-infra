plane           = "np"
product         = "pub"
location        = "Central US"
region          = "cus"

subscription_id = "aab00dd1-a61d-4ecc-9010-e1b43ef16c9f"
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
plane           = "np"
product         = "hrz"
location        = "USGov Arizona"
region          = "usaz"

tags = {
  plane   = "np"
  product = "hrz"
}

law_sku                 = "PerGB2018"
law_retention_days      = 30
appi_internet_ingestion_enabled = false
appi_internet_query_enabled     = false
law_daily_quota_gb = 1

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
custom_domain_name      = "dev.horizon.intterra.io"
associate_custom_domain = false

create_core_vm     = true
core_vm_private_ip = "10.10.13.10"
core_vm_admin_username = "coreadmin"
# VM size suggestions:
# - "Standard_D2s_v5": light CI / tooling, low cost
# - "Standard_D4s_v5": medium workloads
# - "Standard_D8s_v5": heavier pipelines or multiple runners
#   - Standard_B2ms  → 2 vCPU, 8 GiB RAM (good default, burstable)
#   - Standard_B1ms  → 1 vCPU, 2 GiB RAM (lighter workloads)
#   - Standard_B1s   → 1 vCPU, 1 GiB RAM (very light / test only)
core_runner_vm_size = "Standard_B2ms"
# Ubuntu image suggestions:
# Keep defaults for latest Ubuntu 22.04 LTS:
core_runner_vm_image_publisher = "Canonical"
core_runner_vm_image_offer     = "0001-com-ubuntu-server-jammy"
core_runner_vm_image_sku       = "22_04-lts-gen2"
core_runner_vm_image_version   = "latest"
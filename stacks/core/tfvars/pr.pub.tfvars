plane           = " pr"
product         = "pub"
location        = "Central US"
region          = "cus"

tags = {
  plane   = " pr"
  product = "pub"
}

law_sku                      = "PerGB2018"
law_retention_days           = 90
appi_internet_ingestion_enabled = false
appi_internet_query_enabled     = false
law_daily_quota_gb           = 5

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
custom_domain_name      = "public.intterra.io"
associate_custom_domain = false

create_core_vm     = true
core_vm_private_ip = "172.13.13.10"
core_vm_admin_username = "coreadmin"

# VM size suggestions:
# - "Standard_D2s_v5": light CI / tooling, low cost
# - "Standard_D4s_v5": medium workloads
# - "Standard_D8s_v5": heavier pipelines or multiple runners
#   - Standard_B2ms  → 2 vCPU, 8 GiB RAM (good default, burstable)
#   - Standard_B1ms  → 1 vCPU, 2 GiB RAM (lighter workloads)
#   - Standard_B1s   → 1 vCPU, 1 GiB RAM (very light / test only)
core_runner_vm_size = "Standard_D2s_v4"

# Ubuntu image suggestions:
# Keep defaults for latest Ubuntu 22.04 LTS:
core_runner_vm_image_publisher = "Canonical"
core_runner_vm_image_offer     = "0001-com-ubuntu-server-jammy"
core_runner_vm_image_sku       = "22_04-lts-gen2"
core_runner_vm_image_version   = "latest"

create_query_pack = true
query_pack_queries = {
  nsg_denies_detail = {
    display_name = "NSG denies (detailed)"
    description  = "Detailed denied NSG flow entries with normalized direction/protocol + rule priority"
    body = <<KQL
AzureNetworkAnalytics_CL
| where FlowStatus_s == "D"   // Denied
| extend Time          = TimeGenerated
| extend Direction     = case(FlowDirection_s == "I", "Inbound", FlowDirection_s == "O", "Outbound", FlowDirection_s)
| extend Protocol      = case(L4Protocol_s == "T", "TCP", L4Protocol_s == "U", "UDP", L4Protocol_s)
| extend NSGRulePriority = toint(split(NSGRules_s, "|")[4])
| project
    Time,
    Direction,
    Protocol,
    SrcIP_s,
    DestPublicIPs_s,
    DestPort_d,
    L7Protocol_s,
    NSGList_s,
    NSGRule_s,
    NSGRuleType_s,
    NSGRulePriority,
    VNet = tostring(Subnet_s),
    NIC_s,
    VM_s,
    Region_s,
    FlowType_s,
    DeniedInFlows_d,
    DeniedOutFlows_d,
    FlowCount_d
| order by Time desc
KQL

    # must be one of the allowed lowercase values
    categories = ["network"]

    # use tags for sub-category / labeling
    tags = {
      labels = "nsg,flowlogs,denied,detail"
      group  = "nsg-flow-logs"
    }
  }

  nsg_denies_timechart_1h = {
    display_name = "NSG denies (hourly timechart)"
    description  = "Denied NSG flows aggregated by hour"
    body = <<KQL
AzureNetworkAnalytics_CL
| where FlowStatus_s == "D"
| summarize DeniedCount = sum(FlowCount_d) by bin(TimeGenerated, 1h)
| order by TimeGenerated asc
| render timechart
KQL

    categories = ["network"]
    tags = {
      labels = "nsg,flowlogs,denied,timechart,1h"
      group  = "nsg-flow-logs"
    }
  }

  nsg_denies_timechart_5m = {
    display_name = "NSG denies (5m timechart)"
    description  = "Denied NSG flows aggregated every 5 minutes"
    body = <<KQL
AzureNetworkAnalytics_CL
| where FlowStatus_s == "D"
| summarize DeniedCount = sum(FlowCount_d) by bin(TimeGenerated, 5m)
| order by TimeGenerated asc
| render timechart
KQL

    categories = ["network"]
    tags = {
      labels = "nsg,flowlogs,denied,timechart,5m"
      group  = "nsg-flow-logs"
    }
  }
}

# create_storage_cmk → **IMPORTANT first-run behavior**:
# Set to false **on the first Core stack deployment** so the stack can create the Key Vault and the GitHub runner VM.
# The Key Vault is created with **public access disabled**, so if create_storage_cmk = true on the first run, the CMK/key creation can fail (no private access path exists yet).
# After the VM is created, **configure the self-hosted runner** on that VM and update workflows to use it for deployments.
# Then set create_storage_cmk = true and re-apply to create the CMK/keys, since the runner VM has internal network access to the Key Vault.
create_storage_cmk = true
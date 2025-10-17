# env
env             = "dev"
product         = "hrz"
location        = "USGov Arizona"
region          = "usaz"
rg_name         = "rg-hrz-dev-usaz-01"
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# hub overrides (optional)
hub_subscription_id = null
hub_tenant_id       = null

# state (shared-network + core)
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-hrz-np-usaz-01"

shared_state_enabled = true
core_state_enabled   = true
# default core key will be "core/np/terraform.tfstate"; override if needed:
# core_state_key = "core/np/terraform.tfstate"

# tags
tags = { env = "dev", product = "hrz" }
name_suffix = ""

# key vault
purge_protection_enabled   = false
soft_delete_retention_days = 7

# storage
sa_replication_type = "LRS"

# aks
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-hrz-np-aksnodes-usaz"
aks_node_vm_size    = "Standard_B2s"
aks_node_count      = 2
aks_pod_cidr        = "10.210.0.0/16"
aks_service_cidr    = "10.110.0.0/16"
aks_dns_service_ip  = "10.110.0.10"
aks_sku_tier        = "Free"

# acr (gov)
acr_sku                        = "Basic"
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices"
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

# service bus
create_servicebus             = true
servicebus_sku                = "Standard"
servicebus_capacity           = 1
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version    = "1.2"

# cosmos db for postgresql (citus)
create_cdbpg                          = true
cdbpg_node_count                      = 0
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "BurstableGeneralPurpose"
cdbpg_coordinator_vcore_count         = 2
cdbpg_coordinator_storage_quota_in_mb = 131072
cdbpg_node_server_edition             = "GeneralPurpose"
cdbpg_node_vcore_count                = 2
cdbpg_node_storage_quota_in_mb        = 131072
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"

# postgres flex
pg_version               = "16"
pg_sku_name              = "B_Standard_B1ms"
pg_storage_mb            = 32768
pg_geo_redundant_backup  = false
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled      = true
pg_ha_enabled            = false
pg_zone                  = "1"
pg_ha_zone               = "2"
pg_firewall_rules        = []
pg_databases             = ["appdb"]
pg_replica_enabled       = false
pg_enable_postgis        = true

# cosmos (nosql)
cosno_total_throughput_limit = 400

# redis
redis_sku_name   = "Standard"
redis_sku_family = "C"
redis_capacity   = 1

# app service plan (functions)
asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"

# front door
fd_create_frontdoor = false
fd_sku_name         = "Standard_AzureFrontDoor"

# optional networking overrides
# pe_subnet_id           = "<subnet-id>"
# aks_nodepool_subnet_id = "<subnet-id>"
# private_dns_zone_ids = { ... }
# pg_delegated_subnet_id = "<subnet-id>"

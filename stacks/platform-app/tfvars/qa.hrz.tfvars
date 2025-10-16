env            = "qa"
product        = "hrz"
location       = "USGov Arizona"
region         = "usaz"
rg_name        = "rg-hrz-qa-usaz-01"
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-hrz-np-usaz-01"

tags = { 
    env = "qa"
    product = "hrz" 
}

purge_protection_enabled   = false
soft_delete_retention_days = 7

sa_replication_type = "LRS"

create_aks          = false                      # per your logic, qa can skip AKS if desired
kubernetes_version  = "1.33.3"
node_resource_group = "rg-hrz-np-aksnodes-usaz"
aks_node_vm_size    = "Standard_B2s"
aks_node_count      = 2
aks_pod_cidr        = "10.212.0.0/16"
aks_service_cidr    = "10.112.0.0/16"
aks_dns_service_ip  = "10.112.0.10"
aks_sku_tier        = "Free"

acr_sku                        = "Basic"
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices"
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

create_servicebus             = true
servicebus_sku                = "Standard"
servicebus_capacity           = 1
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-qa-manage"
servicebus_min_tls_version    = "1.2"

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

pg_version              = "16"
pg_sku_name             = "B_Standard_B1ms"
pg_storage_mb           = 32768
pg_geo_redundant_backup = false
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled     = true
pg_ha_enabled           = false
pg_zone                 = "1"
pg_ha_zone              = "2"
pg_firewall_rules       = []
pg_databases            = ["appdb"]
pg_replica_enabled      = false
pg_enable_postgis       = true

cosno_total_throughput_limit = 400

redis_sku_name   = "Standard"
redis_sku_family = "C"
redis_capacity   = 1

asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"

fd_create_frontdoor = false
fd_sku_name         = "Standard_AzureFrontDoor"
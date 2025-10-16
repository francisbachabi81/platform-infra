env            = "prod"
product        = "hrz"
location       = "USGov Arizona"
region         = "usaz"
rg_name        = "rg-hrz-prod-usaz-01"
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-hrz-pr-usaz-01"

tags = { 
    env = "prod"
    product = "hrz" 
}

purge_protection_enabled   = true
soft_delete_retention_days = 30

sa_replication_type = "ZRS"

create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-hrz-pr-aksnodes-usaz"
aks_node_vm_size    = "Standard_D8s_v5"
aks_node_count      = 4
aks_pod_cidr        = "10.214.0.0/16"
aks_service_cidr    = "10.114.0.0/16"
aks_dns_service_ip  = "10.114.0.10"
aks_sku_tier        = "Standard"

acr_sku                        = "Premium"
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices"
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = true

create_servicebus             = true
servicebus_sku                = "Standard"
servicebus_capacity           = 2
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = false
servicebus_manage_policy_name = "sb-prod-manage"
servicebus_min_tls_version    = "1.2"

create_cdbpg                          = true
cdbpg_node_count                      = 2
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "GeneralPurpose"
cdbpg_coordinator_vcore_count         = 8
cdbpg_coordinator_storage_quota_in_mb = 524288
cdbpg_node_server_edition             = "GeneralPurpose"
cdbpg_node_vcore_count                = 4
cdbpg_node_storage_quota_in_mb        = 262144
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"

pg_version              = "16"
pg_sku_name             = "GP_Standard_D4s_v3"
pg_storage_mb           = 131072
pg_geo_redundant_backup = true
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled     = true
pg_ha_enabled           = true
pg_zone                 = "1"
pg_ha_zone              = "2"
pg_firewall_rules       = []
pg_databases            = ["appdb"]
pg_replica_enabled      = false
pg_enable_postgis       = true

cosno_total_throughput_limit = 1200

redis_sku_name   = "Premium"
redis_sku_family = "P"
redis_capacity   = 1

asp_os_type              = "Linux"
func_linux_plan_sku_name = "S2"

fd_create_frontdoor = false
fd_sku_name         = "Premium_AzureFrontDoor"
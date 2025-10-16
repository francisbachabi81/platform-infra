env            = "prod"
product        = "pub"
location       = "Central US"
region         = "cus"
rg_name        = "rg-pub-prod-cus-01"
subscription_id = "b055ea98-fdc4-4ec8-a599-67b1b6f88fe2"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

state_rg_name        = "rg-core-infra-state-com"
state_sa_name        = "sacoretfstateinfra-com"
state_container_name = "tfstate"
shared_network_rg    = "rg-pub-pr-cus-01"

tags = { 
    env = "prod"
    product = "pub" 
}

purge_protection_enabled   = true
soft_delete_retention_days = 30

sa_replication_type = "ZRS"

create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-pub-pr-aksnodes-cus"
aks_node_vm_size    = "Standard_D8s_v5"
aks_node_count      = 4
aks_pod_cidr        = "172.214.0.0/16"
aks_service_cidr    = "172.114.0.0/16"
aks_dns_service_ip  = "172.114.0.10"
aks_sku_tier        = "Standard"

acr_sku                        = "Basic"
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices"
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

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

fd_create_frontdoor = true
fd_sku_name         = "Premium_AzureFrontDoor"

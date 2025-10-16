# core / env
env            = "dev"                         # dev | qa | uat | prod
product        = "hrz"                         # gov-targeted product
location       = "USGov Arizona"
region         = "usaz"                        # short region (e.g., usaz, cus)
rg_name        = "rg-hrz-dev-usaz-01"
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# remote state (gov)
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-hrz-np-usaz-01"

# tags
tags = { 
    env = "dev"
    product = "hrz" 
}

# key vault
purge_protection_enabled   = false
soft_delete_retention_days = 7

# storage
sa_replication_type = "LRS"                     # LRS | ZRS | RAGRS | GZRS | RAGZRS

# aks
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-hrz-np-aksnodes-usaz"
aks_node_vm_size    = "Standard_B2s"
aks_node_count      = 2
aks_pod_cidr        = "10.210.0.0/16"
aks_service_cidr    = "10.110.0.0/16"
aks_dns_service_ip  = "10.110.0.10"
aks_sku_tier        = "Free"                    # Free | Standard | Premium

# acr (gov only)
acr_sku                        = "Basic"        # Basic | Standard | Premium
admin_enabled                  = true
public_network_access_enabled  = false          # honored on Premium only
acr_network_rule_bypass_option = "AzureServices" # None | AzureServices
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

# service bus
create_servicebus             = true
servicebus_sku                = "Standard"      # Basic | Standard | Premium
servicebus_capacity           = 1               # Premium MU: 1/2/4 (ignored for Basic/Standard)
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version    = "1.2"

# cosmos db for postgresql (citus)
create_cdbpg                          = true
cdbpg_node_count                      = 0
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "BurstableGeneralPurpose"  # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
cdbpg_coordinator_vcore_count         = 2
cdbpg_coordinator_storage_quota_in_mb = 131072
cdbpg_node_server_edition             = "GeneralPurpose"           # GeneralPurpose | MemoryOptimized
cdbpg_node_vcore_count                = 2
cdbpg_node_storage_quota_in_mb        = 131072
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"      # 1 | 2 | 3

# postgresql flexible server
pg_version              = "16"                   # 11–16
pg_sku_name             = "B_Standard_B1ms"     # B_Standard_B1ms | B_Standard_B2ms | GP_Standard_D2s_v3 | GP_Standard_D4s_v3 | MO_Standard_E4s_v3 | MO_Standard_E8s_v3
pg_storage_mb           = 32768                 # 32768–33553408
pg_geo_redundant_backup = false
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled     = true
pg_ha_enabled           = false
pg_zone                 = "1"                    # 1 | 2 | 3
pg_ha_zone              = "2"                    # 1 | 2 | 3
pg_firewall_rules       = []
pg_databases            = ["appdb"]
pg_replica_enabled      = false
pg_enable_postgis       = true

# cosmos (nosql)
cosno_total_throughput_limit = 400

# redis
redis_sku_name   = "Standard"                   # Basic | Standard | Premium
redis_sku_family = "C"
redis_capacity   = 1

# app service plan
asp_os_type              = "Linux"              # Linux | Windows
func_linux_plan_sku_name = "P0v3"               # e.g. Y1, EP1-3, B1-3, S1-3, P1v2-3, P0v3/P1v3/P2v3/P3v3, I1v2-I3v2

# front door (typically disabled in gov)
fd_create_frontdoor = false                     # set true if needed
fd_sku_name         = "Standard_AzureFrontDoor"
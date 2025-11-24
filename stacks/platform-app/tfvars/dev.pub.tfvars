# env / provider
env             = "dev"                         # dev | qa | uat | prod
product         = "pub"                         # hrz (Azure Gov) | pub (Azure Commercial)
location        = "Central US"
region          = "cus"

# Provider alias overrides used by AKS routing logic (shared nonprod)
shared_nonprod_subscription_id = "ee8a4693-54d4-4de8-842b-b6f35fc0674d"
shared_nonprod_tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# remote state (shared-network + core)
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"

shared_state_enabled = true
core_state_enabled   = true

# tags / naming
tags = {
  env     = "dev"
  product = "pub"
}
name_suffix = ""

# key vault
purge_protection_enabled   = false
soft_delete_retention_days = 7

# storage 
sa_replication_type = "LRS"                      # LRS | ZRS | RAGRS | GZRS | RAGZRS

# AKS (dev deploys in shared nonprod)
create_aks         = true
kubernetes_version = "1.33.5"                    # ensure this version is available in your region
aks_node_vm_size   = "Standard_B2s"
aks_node_count     = 1
aks_pod_cidr       = "172.210.0.0/16"
aks_service_cidr   = "172.110.0.0/16"
aks_dns_service_ip = "172.110.0.10"
aks_sku_tier       = "Free"                       # Free | Standard | Premium

# Service Bus (env)
create_servicebus             = true
servicebus_sku                = "Standard"       # Basic | Standard | Premium
servicebus_capacity           = 1
servicebus_queues = [
  "incident-processor",
  "location-processor",
]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version    = "1.2"

# Cosmos DB for PostgreSQL (Citus) (env)
create_cdbpg                          = true
cdbpg_node_count                      = 0
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "BurstableGeneralPurpose"  # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
cdbpg_coordinator_vcore_count         = 2
cdbpg_coordinator_storage_quota_in_mb = 131072
cdbpg_node_server_edition             = "GeneralPurpose"
cdbpg_node_vcore_count                = 2
cdbpg_node_storage_quota_in_mb        = 131072
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"
# cdbpg_admin_password via TF_VAR_cdbpg_admin_password

# PostgreSQL Flexible Server (env)
pg_version               = "16"
pg_sku_name              = "B_Standard_B2ms"
# Suggested SKUs when you move up environments:
#   dev:  "B_Standard_B1ms" or "B_Standard_B2s"       # Burstable, cheapest option — NO HA support
#   QA:  "GP_Standard_D2s_v3"   # 2 vCores, General Purpose, HA-capable
#   UAT: "GP_Standard_D4s_v3"   # 4 vCores, General Purpose, HA-capable
#   Prod (option 1): "GP_Standard_D8s_v3"   # 8 vCores, GP, HA-capable
#   Prod (option 2): "MO_Standard_E4s_v3"   # 4 vCores, Memory Optimized, HA-capable
#
# All GP_* / MO_* SKUs above support Flexible Server HA (SameZone/ZoneRedundant).
pg_storage_mb            = 32768
pg_geo_redundant_backup  = false
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled      = true
# HA/Replica logic:
# - pg_ha_enabled and pg_replica_enabled are mutually exclusive.
# - pg_ha_enabled = true → built-in HA (no replica module).
# - pg_replica_enabled = true & pg_ha_enabled = false → create read replica.
# - both = false → single primary only.
#
# Zones:
# - Azure Government (e.g. usgovarizona):
#       • Many SKUs (incl. Standard_B1ms) have supportedZones = [],
#         so pg_zone must be null and only SameZone HA is possible.
# - Azure Commercial:
#       • pg_zone may be set explicitly (1/2/3) if SKU/region supports it.
#       • HA may support SameZone or ZoneRedundant depending on SKU/region.
pg_ha_enabled            = true  # HA ON/OFF
pg_zone                  = "1"   # important change: no explicit AZ
pg_ha_zone               = "2"   # effectively ignored while HA is off and no explicit AZ
pg_firewall_rules        = []
pg_databases             = ["appdb"]
pg_replica_enabled       = false
pg_enable_postgis        = true
# pg_admin_password via TF_VAR_pg_admin_password

# Cosmos (NoSQL) (env) 
cosno_total_throughput_limit = 400

# Redis (env) 
redis_sku_name   = "Standard"                     # Basic | Standard | Premium
redis_sku_family = "C"
redis_capacity   = 1

# App Service Plan / Functions (env)
asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"

# Example for topics if needed later:
# servicebus_topics = [
#   "topic1",
#   "topic2",
# ]
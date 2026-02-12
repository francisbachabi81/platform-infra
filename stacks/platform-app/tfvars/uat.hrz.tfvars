# Core env / provider
env      = "uat" # dev | qa | uat | prod
product  = "hrz" # hrz (Azure Gov) | pub (Azure Commercial)
location = "USGov Arizona"
region   = "usaz"

# Provider alias overrides (AKS shared nonprod routing)
# Used by env=dev AKS routing logic to land cluster in shared nonprod subscription.
# shared_nonprod_subscription_id = "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
# shared_nonprod_tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# Remote state (shared-network + core)
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"

shared_state_enabled = true # read shared-network state (vnets, PDZs, subnets)
core_state_enabled   = true # read core state (LAW + App Insights connection)

# core_state_key can be overridden if layout changes:
# core_state_key = "core/hrz/pr/terraform.tfstate"

# Tags
tags = {
  env     = "uat"
  product = "hrz"
}

# Key Vault
purge_protection_enabled   = true
soft_delete_retention_days = 30

# Storage
sa_replication_type = "RAGRS" # LRS | ZRS | RAGRS | GZRS | RAGZRS

# AKS (env)
# uat: deploys into uat env subscription
create_aks         = true
kubernetes_version = "1.33.5"          # ensure this version is available in region
aks_node_vm_size   = "Standard_D2s_v4" # Standard_D2s_v5
aks_node_count     = 3

aks_pod_cidr       = "10.215.0.0/16"
aks_service_cidr   = "10.115.0.0/16"
aks_dns_service_ip = "10.115.0.10"

aks_sku_tier = "Free" # Free | Standard | Premium

# Service Bus (env)
create_servicebus   = true
servicebus_sku      = "Standard" # Basic | Standard | Premium
servicebus_capacity = 1          # for Premium: messaging units; for lower SKUs: 0/1/(sometimes accepted >1 depending on module)

servicebus_queues = [
  "incident-processor",
  "location-processor",
  "notification",
  "notification-dispatcher"
]

servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_authorization_rules_override = {
  app-manage = {
    name   = "sb-uat-manage"
    manage = true
  }
}
# servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version = "1.2"

# Cosmos DB for PostgreSQL (Citus) (env)
create_cdbpg = true

cdbpg_node_count    = 2
cdbpg_citus_version = "12.1"

# Coordinator
cdbpg_coordinator_server_edition      = "GeneralPurpose" # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
cdbpg_coordinator_vcore_count         = 2
cdbpg_coordinator_storage_quota_in_mb = 131072

# Workers
cdbpg_node_server_edition      = "GeneralPurpose"
cdbpg_node_vcore_count         = 2
cdbpg_node_storage_quota_in_mb = 131072

# Networking
cdbpg_enable_private_endpoint = true
cdbpg_preferred_primary_zone  = "2"
# cdbpg_admin_password via TF_VAR_cdbpg_admin_password

# PostgreSQL Flexible Server (env)
pg_version  = "16"
pg_sku_name = "GP_Standard_D2s_v3"

# Suggested SKUs per environment:
#   dev:  "B_Standard_B1ms" or "B_Standard_B2s"     # Burstable, cheapest option — NO HA support
#   QA:   "GP_Standard_D2s_v3"                      # 2 vCores, General Purpose, HA-capable
#   UAT:  "GP_Standard_D4s_v3"                      # 4 vCores, General Purpose, HA-capable
#   Prod: "GP_Standard_D8s_v3" or "MO_Standard_E4s_v3"
#
# All GP_* / MO_* SKUs support Flexible Server HA (SameZone/ZoneRedundant).

pg_storage_mb            = 131072
pg_geo_redundant_backup  = true
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled      = true

# HA/Replica logic:
# - pg_ha_enabled and pg_replica_enabled are mutually exclusive.
# - pg_ha_enabled = true  → built-in HA (no replica module).
# - pg_replica_enabled = true & pg_ha_enabled = false → create read replica.
# - both = false → single primary only.
pg_ha_enabled      = true  # HA ON/OFF
pg_replica_enabled = false # no replica

# Zones:
# - Azure Government (e.g. usgovarizona):
#   • Many SKUs have supportedZones behavior that varies by region/SKU.
#   • If zones are not supported for your chosen SKU, set pg_zone/pg_ha_zone to null and use SameZone HA only.
pg_zone    = null # no explicit AZ in Gov for this SKU
pg_ha_zone = null # ignored while HA is off and no explicit AZ

pg_firewall_rules = []
pg_databases      = ["appdb", "citus"]

pg_enable_postgis = true
# pg_admin_password via TF_VAR_pg_admin_password

pg_extensions = [
  "POSTGIS",
  "PGCRYPTO",
  "PG_STAT_STATEMENTS",
  "UUID-OSSP",
  "BTREE_GIN"
]

# PostgreSQL Flexible Server (AUTH)  ────────────────────────────
pg_auth_version               = "16"
pg_auth_sku_name              = "GP_Standard_D2s_v3"
pg_auth_storage_mb            = 32768
pg_auth_geo_redundant_backup  = true
pg_auth_delegated_subnet_name = "pgflex-auth"
# pg_aad_auth_enabled      = true

pg_auth_zone    = null # no explicit AZ in Gov for this SKU
pg_auth_ha_zone = null # ignored while HA is off and no explicit AZ

# Auth databases (recommended)
pg_auth_ha_enabled      = true
pg_auth_replica_enabled = false

pg_auth_databases = ["identity"]

# Extensions are usually minimal for auth; enable pgcrypto if you want server-side crypto helpers.
pg_auth_enable_postgis = true

pg_auth_extensions = [
  "postgis",
  "pgcrypto",
  "pg_stat_statements",
  "uuid-ossp",
  "btree_gin"
]

# Cosmos DB (NoSQL) (env)
cosno_total_throughput_limit = 1200

# Redis (env)
redis_sku_name   = "Standard" # Basic | Standard | Premium
redis_sku_family = "C"        # C | P
redis_capacity   = 1          # 0–6 depending on SKU

# App Service Plan / Functions (env)
asp_os_type              = "Linux" # Linux | Windows
func_linux_plan_sku_name = "P0v3"  # e.g. P0v3/P1v3 for Premium Functions in Gov
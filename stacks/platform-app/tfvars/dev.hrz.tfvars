# ── env / provider ────────────────────────────────────────────────────────────
env             = "dev"                         # dev | qa | uat | prod
product         = "hrz"                         # hrz (Azure Gov) | pub (Azure Public)
location        = "USGov Arizona"
region          = "usaz"
rg_name         = "rg-hrz-dev-usaz-01"
subscription_id = "62ae6908-cbcb-40cb-8773-54bd318ff7f9"  # ← dev subscription (NOT the shared nonprod)
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# Hub overrides — shared-network (nonprod hub) usually lives in the shared nonprod sub.
# Set these so data sources that use provider.azurerm.hub resolve correctly.
hub_subscription_id = "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
hub_tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# AKS provider alias for env=dev → shared nonprod subscription
shared_nonprod_subscription_id = "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
shared_nonprod_tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# (Optional for other env runs; defaults to subscription_id/tenant_id if omitted)
# prod_subscription_id = "..."
# prod_tenant_id       = "..."
# uat_subscription_id  = "..."
# uat_tenant_id        = "..."

# ── remote state (shared-network + core) ──────────────────────────────────────
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"

shared_state_enabled = true
core_state_enabled   = true
# default core key = core/np/terraform.tfstate
# core_state_key     = "core/np/terraform.tfstate"

# ── tags / naming ────────────────────────────────────────────────────────────
tags        = { 
    env = "dev"
    product = "hrz" 
}
name_suffix = ""

# ── key vault ─────────────────────────────────────────────────────────────────
purge_protection_enabled   = false
soft_delete_retention_days = 7

# ── storage ───────────────────────────────────────────────────────────────────
sa_replication_type = "LRS"                      # LRS | ZRS | RAGRS | GZRS | RAGZRS

# ── AKS (dev deploys in shared nonprod core RG; nodepool in nonprod hub/akspub) ─
create_aks         = true
kubernetes_version = "1.33.3"                    # ensure available in USGov region
aks_node_vm_size   = "Standard_B2s"
aks_node_count     = 1
aks_pod_cidr       = "10.210.0.0/16"
aks_service_cidr   = "10.110.0.0/16"
aks_dns_service_ip = "10.110.0.10"
aks_sku_tier       = "Free"                      # Free | Standard | Premium

# ── ACR (hub) ─────────────────────────────────────────────────────────────────
acr_sku                        = "Basic"         # Basic | Standard | Premium
admin_enabled                  = true
public_network_access_enabled  = false           # honored on Premium only
acr_network_rule_bypass_option = "AzureServices" # None | AzureServices
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

# ── Service Bus (env) ─────────────────────────────────────────────────────────
create_servicebus             = true
servicebus_sku                = "Standard"       # Basic | Standard | Premium
servicebus_capacity           = 1
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version    = "1.2"

# ── Cosmos DB for PostgreSQL (Citus) (env) ───────────────────────────────────
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

# ── PostgreSQL Flexible Server (env) ─────────────────────────────────────────
pg_version               = "16"
pg_sku_name              = "B_Standard_B1ms"
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
pg_ha_enabled            = false  # HA OFF
pg_zone                  = null   # important change: no explicit AZ
pg_ha_zone               = "2"    # effectively ignored while HA is off
pg_firewall_rules        = []
pg_databases             = ["appdb"]
pg_replica_enabled       = false  # no replica
pg_enable_postgis        = true
# pg_admin_password via TF_VAR_pg_admin_password

# ── Cosmos (NoSQL) (env) ─────────────────────────────────────────────────────
cosno_total_throughput_limit = 400

# ── Redis (env) ───────────────────────────────────────────────────────────────
redis_sku_name   = "Standard"                     # Basic | Standard | Premium
redis_sku_family = "C"
redis_capacity   = 1

# ── App Service Plan / Functions (env; often off in Gov for apps) ────────────
asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"
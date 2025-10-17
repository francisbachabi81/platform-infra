# ── env / provider ────────────────────────────────────────────────────────────
env             = "uat"                         # dev | qa | uat | prod
product         = "hrz"                         # hrz (Azure Gov)
location        = "USGov Arizona"
region          = "usaz"
rg_name         = "rg-hrz-uat-usaz-01"
subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
tenant_id       = "ed7990c3-61c2-477d-85e9-1a396c19ae94"

# Plane-scoped RG in hub subscription (pr = uat/prod plane; ACR/RSV live here)
rg_plane_name = "rg-hrz-pr-usaz-01"

# Hub overrides (only set if hub ≠ env subscription)
hub_subscription_id = null
hub_tenant_id       = null

# ── remote state (shared-network + core) ──────────────────────────────────────
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-hrz-pr-usaz-01"

shared_state_enabled = true
core_state_enabled   = true
# default core key = core/pr/terraform.tfstate
# core_state_key     = "core/pr/terraform.tfstate"

# ── tags / naming ────────────────────────────────────────────────────────────
tags        = { env = "uat", product = "hrz" }
name_suffix = ""

# ── key vault ─────────────────────────────────────────────────────────────────
purge_protection_enabled   = true
soft_delete_retention_days = 14

# ── storage ───────────────────────────────────────────────────────────────────
sa_replication_type = "ZRS"                      # LRS | ZRS | RAGRS | GZRS | RAGZRS

# ── AKS (uat deploys in env) ─────────────────────────────────────────────────
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-hrz-pr-aksnodes-usaz"  # module appends -01
aks_node_vm_size    = "Standard_D4s_v5"
aks_node_count      = 3
aks_pod_cidr        = "10.215.0.0/16"
aks_service_cidr    = "10.115.0.0/16"
aks_dns_service_ip  = "10.115.0.10"
aks_sku_tier        = "Standard"                 # Free | Standard | Premium

# ── ACR (hub pr) ──────────────────────────────────────────────────────────────
acr_sku                        = "Standard"      # Basic | Standard | Premium
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices" # None | AzureServices
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = true

# ── Service Bus (env) ─────────────────────────────────────────────────────────
create_servicebus             = true
servicebus_sku                = "Standard"       # Basic | Standard | Premium
servicebus_capacity           = 2
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = false
servicebus_manage_policy_name = "sb-uat-manage"
servicebus_min_tls_version    = "1.2"

# ── Cosmos DB for PostgreSQL (Citus) (env) ───────────────────────────────────
create_cdbpg                          = true
cdbpg_node_count                      = 0
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "GeneralPurpose"   # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
cdbpg_coordinator_vcore_count         = 4
cdbpg_coordinator_storage_quota_in_mb = 262144
cdbpg_node_server_edition             = "GeneralPurpose"
cdbpg_node_vcore_count                = 2
cdbpg_node_storage_quota_in_mb        = 131072
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"
# cdbpg_admin_password is provided securely by workflow via TF_VAR_cdbpg_admin_password

# ── PostgreSQL Flexible Server (env) ─────────────────────────────────────────
pg_version               = "16"
pg_sku_name              = "GP_Standard_D2s_v3"
pg_storage_mb            = 65536
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
# pg_admin_password is provided securely by workflow via TF_VAR_pg_admin_password

# ── Cosmos (NoSQL) (env) ─────────────────────────────────────────────────────
cosno_total_throughput_limit = 400

# ── Redis (env) ───────────────────────────────────────────────────────────────
redis_sku_name   = "Standard"                     # Basic | Standard | Premium
redis_sku_family = "C"
redis_capacity   = 2

# ── App Service Plan / Functions (env) ────────────────────────────────────────
asp_os_type              = "Linux"
func_linux_plan_sku_name = "S1"

# ── Front Door (usually disabled in Gov) ─────────────────────────────────────
fd_create_frontdoor = false
fd_sku_name         = "Standard_AzureFrontDoor"

# ── Optional networking overrides (only if shared-state not ready) ───────────
# pe_subnet_id           = "/subscriptions/.../subnets/privatelink"
# aks_nodepool_subnet_id = "/subscriptions/.../subnets/aks-hrz-pr-usaz"
# private_dns_zone_ids   = { "privatelink.blob.core.usgovcloudapi.net" = "/subscriptions/.../privateDnsZones/..." }
# pg_delegated_subnet_id = "/subscriptions/.../subnets/pgflex"

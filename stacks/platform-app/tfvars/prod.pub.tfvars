# ── env / provider ────────────────────────────────────────────────────────────
env             = "prod"                        # dev | qa | uat | prod
product         = "pub"                         # pub (Azure Commercial)
location        = "Central US"
region          = "cus"
rg_name         = "rg-pub-prod-cus-01"
subscription_id = "b055ea98-fdc4-4ec8-a599-67b1b6f88fe2"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# Plane-scoped RG in hub subscription (pr = uat/prod plane; ACR/RSV live here)
rg_plane_name = "rg-pub-pr-cus-01"

# Hub overrides (only set if hub ≠ env subscription)
hub_subscription_id = null
hub_tenant_id       = null

# ── remote state (shared-network + core) ──────────────────────────────────────
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-pub-pr-cus-01"

shared_state_enabled = true
core_state_enabled   = true
# default core key = core/pr/terraform.tfstate
# core_state_key     = "core/pr/terraform.tfstate"

# ── tags / naming ────────────────────────────────────────────────────────────
tags        = { env = "prod", product = "pub" }
name_suffix = ""

# ── key vault ─────────────────────────────────────────────────────────────────
purge_protection_enabled   = true
soft_delete_retention_days = 30

# ── storage ───────────────────────────────────────────────────────────────────
sa_replication_type = "ZRS"                      # LRS | ZRS | RAGRS | GZRS | RAGZRS

# ── AKS (prod deploys in env) ────────────────────────────────────────────────
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-pub-pr-aksnodes-cus"   # module appends -01
aks_node_vm_size    = "Standard_D8s_v5"
aks_node_count      = 4
aks_pod_cidr        = "172.214.0.0/16"
aks_service_cidr    = "172.114.0.0/16"
aks_dns_service_ip  = "172.114.0.10"
aks_sku_tier        = "Standard"                 # Free | Standard | Premium

# ── ACR (hub pr) ──────────────────────────────────────────────────────────────
acr_sku                        = "Basic"         # Basic | Standard | Premium
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices" # None | AzureServices
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

# ── Service Bus (env) ─────────────────────────────────────────────────────────
create_servicebus             = true
servicebus_sku                = "Standard"       # Basic | Standard | Premium
servicebus_capacity           = 2
servicebus_queues             = ["custom-dlq"]
servicebus_topics             = []
servicebus_local_auth_enabled = false
servicebus_manage_policy_name = "sb-prod-manage"
servicebus_min_tls_version    = "1.2"

# ── Cosmos DB for PostgreSQL (Citus) (env) ───────────────────────────────────
create_cdbpg                          = true
cdbpg_node_count                      = 2
cdbpg_citus_version                   = "12.1"
cdbpg_coordinator_server_edition      = "GeneralPurpose"    # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
cdbpg_coordinator_vcore_count         = 8
cdbpg_coordinator_storage_quota_in_mb = 524288
cdbpg_node_server_edition             = "GeneralPurpose"
cdbpg_node_vcore_count                = 4
cdbpg_node_storage_quota_in_mb        = 262144
cdbpg_enable_private_endpoint         = true
cdbpg_preferred_primary_zone          = "2"
# cdbpg_admin_password is supplied by workflow via TF_VAR_cdbpg_admin_password

# ── PostgreSQL Flexible Server (env) ─────────────────────────────────────────
pg_version               = "16"
pg_sku_name              = "GP_Standard_D4s_v3"
pg_storage_mb            = 131072
pg_geo_redundant_backup  = true
pg_delegated_subnet_name = "pgflex"
pg_aad_auth_enabled      = true
pg_ha_enabled            = true
pg_zone                  = "1"
pg_ha_zone               = "2"
pg_firewall_rules        = []
pg_databases             = ["appdb"]
pg_replica_enabled       = false
pg_enable_postgis        = true
# pg_admin_password is supplied by workflow via TF_VAR_pg_admin_password

# ── Cosmos (NoSQL) (env) ─────────────────────────────────────────────────────
cosno_total_throughput_limit = 1200

# ── Redis (env) ───────────────────────────────────────────────────────────────
redis_sku_name   = "Premium"                     # Basic | Standard | Premium
redis_sku_family = "P"
redis_capacity   = 1

# ── App Service Plan / Functions (env) ────────────────────────────────────────
asp_os_type              = "Linux"
func_linux_plan_sku_name = "S2"

# ── Optional networking overrides (only if shared-state not ready) ───────────
# pe_subnet_id           = "/subscriptions/.../subnets/privatelink"
# aks_nodepool_subnet_id = "/subscriptions/.../subnets/aks-pub-pr-cus"
# private_dns_zone_ids   = { "privatelink.blob.core.windows.net" = "/subscriptions/.../privateDnsZones/..." }
# pg_delegated_subnet_id = "/subscriptions/.../subnets/pgflex"

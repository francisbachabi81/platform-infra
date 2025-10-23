# ── env / provider ────────────────────────────────────────────────────────────
env             = "dev"                         # dev | qa | uat | prod
product         = "pub"                         # pub (Azure Commercial)
location        = "Central US"
region          = "cus"
rg_name         = "rg-pub-dev-cus-01"
subscription_id = "57f8aa30-981c-4764-94f6-6691c4d5c01c"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# Hub overrides (only set if hub ≠ env subscription)
hub_subscription_id = "ee8a4693-54d4-4de8-842b-b6f35fc0674d"
hub_tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# ── remote state (shared-network + core) ──────────────────────────────────────
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"

shared_state_enabled = true
core_state_enabled   = true
# default core key = core/np/terraform.tfstate
# core_state_key     = "core/np/terraform.tfstate"

# ── tags / naming ────────────────────────────────────────────────────────────
tags        = { env = "dev", product = "pub" }
name_suffix = ""

# ── key vault ─────────────────────────────────────────────────────────────────
purge_protection_enabled   = false
soft_delete_retention_days = 7

# ── storage ───────────────────────────────────────────────────────────────────
sa_replication_type = "LRS"                      # LRS | ZRS | RAGRS | GZRS | RAGZRS

# ── AKS (dev deploys in hub) ──────────────────────────────────────────────────
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-pub-np-aksnodes-cus"   # module appends -01
aks_node_vm_size    = "Standard_B2s"
aks_node_count      = 1
aks_pod_cidr        = "172.210.0.0/16"
aks_service_cidr    = "172.110.0.0/16"
aks_dns_service_ip  = "172.110.0.10"
aks_sku_tier        = "Free"                     # Free | Standard | Premium

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
servicebus_queues             = ["custom-dlq", "incident-processor"]
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
# cdbpg_admin_password is provided securely by the workflow via TF_VAR_cdbpg_admin_password

# ── PostgreSQL Flexible Server (env) ─────────────────────────────────────────
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
# pg_admin_password is provided securely by the workflow via TF_VAR_pg_admin_password

# ── Cosmos (NoSQL) (env) ─────────────────────────────────────────────────────
cosno_total_throughput_limit = 400

# ── Redis (env) ───────────────────────────────────────────────────────────────
redis_sku_name   = "Standard"                     # Basic | Standard | Premium
redis_sku_family = "C"
redis_capacity   = 1

# ── App Service Plan / Functions (env) ────────────────────────────────────────
asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"

# ── Optional networking overrides (only if shared-state not ready) ───────────
# pe_subnet_id           = "/subscriptions/.../subnets/privatelink"
# aks_nodepool_subnet_id = "/subscriptions/.../subnets/aks-pub-np-cus"
# private_dns_zone_ids   = { "privatelink.blob.core.windows.net" = "/subscriptions/.../privateDnsZones/..." }
# pg_delegated_subnet_id = "/subscriptions/.../subnets/pgflex"
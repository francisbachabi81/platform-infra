# ── core / env ────────────────────────────────────────────────────────────────
env             = "dev"
product         = "pub"
location        = "Central US"
region          = "cus"
rg_name         = "rg-pub-dev-cus-01"
subscription_id = "b055ea98-fdc4-4ec8-a599-67b1b6f88fe2"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# Optional: explicitly tie dev env to a specific sub/tenant (provider default if omitted)
dev_subscription_id = "b055ea98-fdc4-4ec8-a599-67b1b6f88fe2"
dev_tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# Optional: plane-shared (np/pr) hub overrides (leave null for default)
hub_subscription_id = null
hub_tenant_id       = null

# Used by data.terraform_remote_state to read shared-network state
state_rg_name        = "rg-core-infra-state"
state_sa_name        = "sacoretfstateinfra"
state_container_name = "tfstate"
shared_network_rg    = "rg-pub-np-cus-01"

# general naming helper (referenced by main.tf locals; safe to keep empty)
name_suffix = ""

# ── tags ──────────────────────────────────────────────────────────────────────
tags = {
  env     = "dev"
  product = "pub"
}

# ── key vault ─────────────────────────────────────────────────────────────────
purge_protection_enabled   = false
soft_delete_retention_days = 7

# ── storage ───────────────────────────────────────────────────────────────────
sa_replication_type = "LRS"

# ── observability (Log Analytics / App Insights) ──────────────────────────────
law_sku                   = "PerGB2018"
law_retention_days        = 30
appi_internet_ingestion_enabled = true           # Commercial typically OK
appi_internet_query_enabled     = true

# ── AKS ───────────────────────────────────────────────────────────────────────
create_aks          = true
kubernetes_version  = "1.33.3"
node_resource_group = "rg-pub-np-aksnodes-cus"    # module appends -01
aks_node_vm_size    = "Standard_B2s"
aks_node_count      = 2
aks_pod_cidr        = "172.210.0.0/16"
aks_service_cidr    = "172.110.0.0/16"
aks_dns_service_ip  = "172.110.0.10"
aks_sku_tier        = "Free"

# ── ACR (kept; module will honor product logic) ───────────────────────────────
acr_sku                        = "Basic"
admin_enabled                  = true
public_network_access_enabled  = false
acr_network_rule_bypass_option = "AzureServices"
acr_anonymous_pull_enabled     = false
acr_data_endpoint_enabled      = false
acr_zone_redundancy_enabled    = false

# ── Service Bus ───────────────────────────────────────────────────────────────
create_servicebus             = true
servicebus_sku                = "Standard"
servicebus_capacity           = 1
servicebus_queues             = ["custom-dlq", "incident-processor"]
servicebus_topics             = []
servicebus_local_auth_enabled = true
servicebus_manage_policy_name = "sb-dev-manage"
servicebus_min_tls_version    = "1.2"

# ── Cosmos DB for PostgreSQL (Citus) ──────────────────────────────────────────
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

# ── PostgreSQL Flexible Server ────────────────────────────────────────────────
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

# ── Cosmos (NoSQL) ────────────────────────────────────────────────────────────
cosno_total_throughput_limit = 400

# ── Redis ─────────────────────────────────────────────────────────────────────
redis_sku_name   = "Standard"
redis_sku_family = "C"
redis_capacity   = 1

# ── App Service Plan (Functions) ──────────────────────────────────────────────
asp_os_type              = "Linux"
func_linux_plan_sku_name = "P0v3"

# ── Front Door (enabled for Commercial) ───────────────────────────────────────
fd_create_frontdoor = true
fd_sku_name         = "Standard_AzureFrontDoor"
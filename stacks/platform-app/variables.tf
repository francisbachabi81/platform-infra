# Core scope & identity
variable "subscription_id" {
  description = "target subscription id"
  type        = string
}

variable "tenant_id" {
  description = "entra tenant id"
  type        = string
}

variable "location" {
  description = "azure region display name"
  type        = string
}

variable "product" {
  description = "product code: hrz or pub"
  type        = string
  validation {
    condition     = contains(["hrz", "pub"], lower(var.product))
    error_message = "product must be hrz or pub."
  }
}

variable "region" {
  description = "short region code, e.g. usaz or cus"
  type        = string
}

variable "env" {
  description = "environment: dev, qa, uat, prod, np, or pr"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "uat", "prod", "np", "pr"], lower(var.env))
    error_message = "env must be dev, qa, uat, prod, np, or pr."
  }
}

variable "kubernetes_version" {
  description = "aks kubernetes version"
  type        = string
  default     = "1.33.3"
}

# Remote state (shared-network & core)
variable "state_rg_name" {
  description = "remote state resource group"
  type        = string
  default     = "state_rg_name"
}

variable "state_sa_name" {
  description = "remote state storage account"
  type        = string
  default     = "state_sa_name"
}

variable "state_container_name" {
  description = "remote state container"
  type        = string
  default     = "state_container_name"
}

variable "shared_state_enabled" {
  description = "enable reading shared remote state"
  type        = bool
  default     = true
}

variable "core_state_enabled" {
  description = "enable reading core state for observability"
  type        = bool
  default     = true
}

variable "core_state_key" {
  description = "override for core state key"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "base tags applied to all resources"
  type        = map(string)
  default     = {}
}

# Private networking & DNS
variable "pe_subnet_id" {
  description = "private endpoint subnet id"
  type        = string
  default     = null
}

variable "aks_nodepool_subnet_id" {
  description = "aks nodepool subnet id"
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "map of privatelink zone ids"
  type        = map(string)
  default     = {}
}

variable "require_private_networking" {
  description = "enforce private networking"
  type        = bool
  default     = true
}

# Key Vault
variable "purge_protection_enabled" {
  description = "enable purge protection"
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "soft delete retention in days"
  type        = number
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be 7..90."
  }
}

# Storage
variable "sa_replication_type" {
  description = "storage account replication"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "RAGRS", "GZRS", "RAGZRS"], var.sa_replication_type)
    error_message = "sa_replication_type invalid."
  }
}

# Service Bus / Event Hubs
variable "create_servicebus" {
  description = "create service bus resources"
  type        = bool
  default     = true
}

variable "servicebus_sku" {
  description = "service bus sku"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.servicebus_sku)
    error_message = "servicebus_sku invalid."
  }
}

variable "servicebus_capacity" {
  description = "premium messaging units or 0/1 for lower skus"
  type        = number
  default     = 1
}

variable "servicebus_local_auth_enabled" {
  description = "enable local auth"
  type        = bool
  default     = false
}

variable "servicebus_queues" {
  description = "queue names"
  type        = list(string)
  default     = []
}

variable "servicebus_topics" {
  description = "topic names"
  type        = list(string)
  default     = []
}

variable "servicebus_manage_policy_name" {
  description = "management policy name"
  type        = string
  default     = null
}

variable "servicebus_min_tls_version" {
  description = "minimum tls version"
  type        = string
  default     = "1.2"
}

# AKS: sizing & networking
variable "rg_plane_name" {
  description = "plane-scoped hub resource group name"
  type        = string
  default     = null
}

variable "aks_node_vm_size" {
  description = "default node vm size"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_sku_tier" {
  description = "aks sku tier"
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier invalid."
  }
}

variable "aks_node_count" {
  description = "default node count"
  type        = number
  default     = 2
}

variable "aks_service_cidr" {
  description = "service cidr"
  type        = string
  default     = null
}

variable "aks_dns_service_ip" {
  description = "dns service ip"
  type        = string
  default     = null
}

variable "aks_pod_cidr" {
  description = "pod cidr"
  type        = string
  default     = "10.244.0.0/16"
}

variable "create_aks" {
  description = "force create aks or skip (null = use default per env)"
  type        = bool
  default     = null
}

# App Service Plan / Function Apps
variable "asp_os_type" {
  description = "app service plan os"
  type        = string
  default     = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.asp_os_type)
    error_message = "asp_os_type invalid."
  }
}

variable "func_linux_plan_sku_name" {
  description = "function app plan sku"
  type        = string
  default     = "S1"
}

# Cosmos DB (NoSQL)
variable "cosno_total_throughput_limit" {
  description = "cosmos nosql total throughput limit"
  type        = number
  default     = null
}

# PostgreSQL Flexible Server
variable "pg_sku_name" {
  description = "postgres flexible server sku"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "pg_storage_mb" {
  description = "postgres storage in mb"
  type        = number
  default     = 32768
}

variable "pg_version" {
  description = "postgres version"
  type        = string
  default     = "16"
}

variable "pg_admin_password" {
  description = "postgres admin password"
  type        = string
  sensitive   = true
  default     = null
}

variable "pg_geo_redundant_backup" {
  description = "enable geo-redundant backup"
  type        = bool
  default     = false
}

variable "pg_ha_enabled" {
  description = "enable ha"
  type        = bool
  default     = false
}

variable "pg_ha_zone" {
  description = "ha zone"
  type        = string
  default     = "1"
}

variable "pg_delegated_subnet_name" {
  description = "delegated subnet name"
  type        = string
  default     = "pgflex"
}

variable "pg_delegated_subnet_id" {
  description = "delegated subnet id"
  type        = string
  default     = null
}

variable "pg_firewall_rules" {
  description = "postgres firewall rules"
  type = list(object({
    name     = string
    start_ip = string
    end_ip   = string
  }))
  default = []
}

variable "pg_databases" {
  description = "postgres databases to create"
  type        = list(string)
  default     = ["appdb"]
}

variable "pg_aad_auth_enabled" {
  description = "enable aad authentication"
  type        = bool
  default     = false
}

variable "pg_zone" {
  description = "primary zone"
  type        = string
  default     = "1"
}

variable "pg_replica_enabled" {
  description = "create read replica"
  type        = bool
  default     = false
}

variable "pg_enable_postgis" {
  description = "enable postgis extension"
  type        = bool
  default     = false
}

variable "pg_extensions" {
  description = "List of PostgreSQL extensions to set on azure.extensions."
  type        = list(string)
  default = [
    "POSTGIS",
    "PGCRYPTO",
    "PG_STAT_STATEMENTS",
    "UUID-OSSP",
  ]
}

# Redis
variable "redis_sku_name" {
  description = "redis sku name"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "redis_sku_name invalid."
  }
}

variable "redis_sku_family" {
  description = "redis sku family"
  type        = string
  default     = "C"
  validation {
    condition     = contains(["C", "P"], var.redis_sku_family)
    error_message = "redis_sku_family invalid."
  }
}

variable "redis_capacity" {
  description = "redis capacity"
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "redis_capacity invalid."
  }
}

# Hub / subscription overrides
variable "hub_subscription_id" {
  description = "override hub subscription id"
  type        = string
  default     = null
}

variable "hub_tenant_id" {
  description = "override hub tenant id"
  type        = string
  default     = null
}

variable "shared_nonprod_subscription_id" {
  description = "Shared nonprod subscription ID (used for AKS when env=dev)"
  type        = string
  default     = null
}

variable "shared_nonprod_tenant_id" {
  description = "Tenant ID for the shared nonprod subscription (used for AKS when env=dev)"
  type        = string
  default     = null
}

variable "prod_subscription_id" {
  description = "Prod subscription ID override (AKS when env=prod; defaults to var.subscription_id)"
  type        = string
  default     = null
}

variable "prod_tenant_id" {
  description = "Tenant ID for the prod subscription override (defaults to var.tenant_id)"
  type        = string
  default     = null
}

variable "uat_subscription_id" {
  description = "UAT subscription ID override (AKS when env=uat; defaults to var.subscription_id)"
  type        = string
  default     = null
}

variable "uat_tenant_id" {
  description = "Tenant ID for the UAT subscription override (defaults to var.tenant_id)"
  type        = string
  default     = null
}

# Observability overrides (bypass core state)
variable "law_workspace_id_override" {
  description = "override law workspace id"
  type        = string
  default     = null
}

variable "appi_connection_string_override" {
  description = "override app insights connection string"
  type        = string
  default     = null
}

# Cosmos DB for PostgreSQL (Citus)
variable "create_cdbpg" {
  description = "create cosmos db for postgresql"
  type        = bool
  default     = false
}

variable "cdbpg_node_count" {
  description = "worker node count"
  type        = number
  default     = 0
}

variable "cdbpg_coordinator_vcore_count" {
  description = "coordinator vcores"
  type        = number
  default     = 4
}

variable "cdbpg_coordinator_storage_quota_in_mb" {
  description = "coordinator storage in mb"
  type        = number
  default     = 32768
}

variable "cdbpg_coordinator_server_edition" {
  description = "coordinator edition"
  type        = string
  default     = "BurstableGeneralPurpose"
}

variable "cdbpg_node_vcore_count" {
  description = "worker vcores"
  type        = number
  default     = 2
}

variable "cdbpg_node_storage_quota_in_mb" {
  description = "worker storage in mb"
  type        = number
  default     = 32768
}

variable "cdbpg_node_server_edition" {
  description = "worker edition"
  type        = string
  default     = "GeneralPurpose"
}

variable "cdbpg_citus_version" {
  description = "citus version"
  type        = string
  default     = null
}

variable "cdbpg_enable_private_endpoint" {
  description = "enable private endpoint"
  type        = bool
  default     = true
}

# variable "cdbpg_admin_password" {
#   description = "cluster admin password"
#   type        = string
#   sensitive   = true
# }

variable "cdbpg_preferred_primary_zone" {
  description = "preferred primary zone"
  type        = string
  default     = null
  validation {
    condition     = var.cdbpg_preferred_primary_zone == null || contains(["1", "2", "3"], var.cdbpg_preferred_primary_zone)
    error_message = "cdbpg_preferred_primary_zone must be 1, 2, or 3 (or null)."
  }
}

variable "servicebus_authorization_rules_override" {
  type = map(object({
    name   = string
    listen = optional(bool, true)
    send   = optional(bool, true)
    manage = optional(bool, true)
  }))
  description = "Optional override/additional SB namespace authorization rules."
  default     = {}
}

# Elastic Cluster subnet lookup
variable "pg_elastic_private_endpoint_subnet_name" {
  type        = string
  default     = "privatelink-pg"
  description = "Subnet name (key in subnet_ids_from_state) for PostgreSQL Elastic private endpoint."
}

# Or allow passing an ID directly (fallback)
variable "pg_elastic_private_endpoint_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for PostgreSQL Elastic private endpoint (used if subnet name lookup is null)."
}

variable "pg_elastic_private_endpoint_subresource_names" {
  type        = list(string)
  default     = ["coordinator"]
  description = "Private endpoint subresource names (groupIds) for PostgreSQL Elastic."
}

# Elastic sizing
variable "pg_elastic_coordinator_vcores" {
  type        = number
  default     = 4
  description = "Elastic coordinator vCores."
}

variable "pg_elastic_coordinator_storage_mb" {
  type        = number
  default     = 131072
  description = "Elastic coordinator storage in MB."
}

variable "pg_elastic_worker_count" {
  type        = number
  default     = 2
  description = "Elastic worker node count."
}

variable "pg_elastic_worker_vcores" {
  type        = number
  default     = 4
  description = "Elastic worker vCores."
}

variable "pg_elastic_worker_storage_mb" {
  type        = number
  default     = 131072
  description = "Elastic worker storage in MB."
}

# PostgreSQL Flexible Server (AUTH) - variables
variable "pg_auth_storage_mb" {
  type    = number
  default = 32768
}

variable "pg_auth_version" {
  type    = string
  default = "16"
}

variable "pg_auth_sku_name" {
  description = "SKU name for the AUTH PostgreSQL Flexible Server (e.g., B_Standard_B2s, GP_Standard_D2s_v3)."
  type        = string
  default     = "B_Standard_B2s"
}

variable "pg_auth_geo_redundant_backup" {
  description = "Enable geo-redundant backups for the AUTH PostgreSQL Flexible Server (typically prod-only and region-dependent)."
  type        = bool
  default     = false
}

variable "pg_auth_delegated_subnet_name" {
  description = "Name of the delegated subnet (from shared-network remote state) to use for the AUTH PostgreSQL Flexible Server."
  type        = string
  default     = "pgflex-auth"
}

variable "pg_auth_delegated_subnet_id" {
  description = "Optional explicit delegated subnet ID for AUTH PG (overrides subnet-name lookup when provided)."
  type        = string
  default     = null
}

variable "pg_auth_zone" {
  description = "Availability zone for the AUTH PostgreSQL Flexible Server primary (Commercial only when supported by SKU/region). Use null when not supported (common in Gov for many SKUs)."
  type        = string
  default     = "1"
}

variable "pg_auth_ha_zone" {
  description = "Availability zone for the AUTH PostgreSQL Flexible Server HA standby (only used when HA is enabled and zones are supported)."
  type        = string
  default     = "2"
}

variable "pg_auth_ha_enabled" {
  description = "Enable built-in HA for the AUTH PostgreSQL Flexible Server. Mutually exclusive with pg_auth_replica_enabled."
  type        = bool
  default     = false
}

variable "pg_auth_replica_enabled" {
  description = "Enable a read replica for the AUTH PostgreSQL Flexible Server (only when HA is disabled). Mutually exclusive with pg_auth_ha_enabled."
  type        = bool
  default     = false
}

variable "pg_auth_admin_password" {
  description = "Administrator password for the AUTH PostgreSQL Flexible Server. Provide via TF_VAR_pg_auth_admin_password or secret injection."
  type        = string
  sensitive   = true
}

variable "pg_auth_databases" {
  description = "List of databases to create on the AUTH PostgreSQL Flexible Server."
  type        = list(string)
  default     = ["identity"]

  validation {
    condition = alltrue([
      for db in var.pg_auth_databases :
      can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", db))
    ])
    error_message = "Each database name must start with a letter and contain only letters, numbers, and underscores (max 63 chars)."
  }
}

variable "pg_auth_enable_postgis" {
  description = "Enable PostGIS on the AUTH PostgreSQL Flexible Server (usually false for auth workloads)."
  type        = bool
  default     = false
}

variable "pg_auth_extensions" {
  description = "List of PostgreSQL extensions to enable on the AUTH PostgreSQL Flexible Server."
  type        = list(string)
  default = [
    "POSTGIS",
    "PGCRYPTO",
    "PG_STAT_STATEMENTS",
    "UUID-OSSP",
    "BTREE_GIN"
  ]
}
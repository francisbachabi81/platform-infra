########################################
# core env/provider
########################################
variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "location" {
  type = string
}

variable "product" {
  type = string # hrz | pub
}

variable "region" {
  type = string
}

variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "qa", "uat", "prod", "np", "pr"], var.env)
    error_message = "env must be dev, qa, uat, prod, np, or pr."
  }
}

variable "rg_name" {
  type = string
}

variable "node_resource_group" {
  type    = string
  default = ""
}

variable "kubernetes_version" {
  type    = string
  default = "1.33.3"
}

########################################
# remote states
########################################
variable "state_rg_name" {
  type = string
}

variable "state_sa_name" {
  type = string
}

variable "state_container_name" {
  type = string
}

variable "shared_state_enabled" {
  type    = bool
  default = true
}

########################################
# core state for observability
########################################
variable "core_state_enabled" {
  type    = bool
  default = true
}

variable "core_state_key" {
  type    = string
  default = null # overrides default "core/<plane>/terraform.tfstate"
}

########################################
# tags & naming
########################################
variable "tags" {
  type    = map(string)
  default = {}
}

variable "name_suffix" {
  type    = string
  default = ""
  validation {
    condition     = var.name_suffix == "" || can(regex("^[A-Za-z0-9]+$", var.name_suffix))
    error_message = "name_suffix must be empty or alphanumeric"
  }
}

########################################
# private networking overrides + strictness
########################################
variable "pe_subnet_id" {
  type    = string
  default = null
}

variable "aks_nodepool_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_ids" {
  type    = map(string)
  default = {}
}

variable "require_private_networking" {
  type    = bool
  default = true
}

########################################
# key vault
########################################
variable "purge_protection_enabled" {
  type    = bool
  default = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be 7..90"
  }
}

########################################
# storage
########################################
variable "sa_replication_type" {
  type    = string
  default = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "RAGRS", "GZRS", "RAGZRS"], var.sa_replication_type)
    error_message = "sa_replication_type invalid"
  }
}

########################################
# acr
########################################
variable "acr_sku" {
  type    = string
  default = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku invalid"
  }
}

variable "admin_enabled" {
  type    = bool
  default = false
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "acr_network_rule_bypass_option" {
  type    = string
  default = "AzureServices"
  validation {
    condition     = contains(["None", "AzureServices"], var.acr_network_rule_bypass_option)
    error_message = "acr bypass invalid"
  }
}

variable "acr_anonymous_pull_enabled" {
  type    = bool
  default = false
}

variable "acr_data_endpoint_enabled" {
  type    = bool
  default = false
}

variable "acr_zone_redundancy_enabled" {
  type    = bool
  default = false
}

########################################
# service bus
########################################
variable "create_servicebus" {
  type    = bool
  default = true
}

variable "servicebus_sku" {
  type    = string
  default = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.servicebus_sku)
    error_message = "servicebus_sku invalid"
  }
}

variable "servicebus_capacity" {
  type    = number
  default = 1
}

variable "servicebus_local_auth_enabled" {
  type    = bool
  default = false
}

variable "servicebus_queues" {
  type    = list(string)
  default = []
}

variable "servicebus_topics" {
  type    = list(string)
  default = []
}

variable "servicebus_manage_policy_name" {
  type    = string
  default = null
}

variable "servicebus_min_tls_version" {
  type    = string
  default = "1.2"
}

########################################
# aks sizing & networking
########################################
variable "aks_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_sku_tier" {
  type    = string
  default = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier invalid"
  }
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "aks_service_cidr" {
  type    = string
  default = null
}

variable "aks_dns_service_ip" {
  type    = string
  default = null
}

variable "aks_pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "create_aks" {
  type    = bool
  default = null
}

########################################
# app service plan + dns rg
########################################
variable "asp_os_type" {
  type    = string
  default = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.asp_os_type)
    error_message = "asp_os_type invalid"
  }
}

variable "func_linux_plan_sku_name" {
  type    = string
  default = "S1"
}

########################################
# cosmos (nosql)
########################################
variable "cosno_total_throughput_limit" {
  type    = number
  default = null
}

########################################
# postgres flex
########################################
variable "pg_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "pg_storage_mb" {
  type    = number
  default = 32768
}

variable "pg_version" {
  type    = string
  default = "16"
}

variable "pg_admin_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "pg_geo_redundant_backup" {
  type    = bool
  default = false
}

variable "pg_ha_enabled" {
  type    = bool
  default = false
}

variable "pg_ha_zone" {
  type    = string
  default = "1"
}

variable "pg_delegated_subnet_name" {
  type    = string
  default = "pgflex"
}

variable "pg_delegated_subnet_id" {
  type    = string
  default = null
}

variable "pg_firewall_rules" {
  type = list(object({
    name     = string
    start_ip = string
    end_ip   = string
  }))
  default = []
}

variable "pg_databases" {
  type    = list(string)
  default = ["appdb"]
}

variable "pg_aad_auth_enabled" {
  type    = bool
  default = false
}

variable "pg_zone" {
  type    = string
  default = "1"
}

variable "pg_replica_enabled" {
  type    = bool
  default = false
}

variable "pg_enable_postgis" {
  type    = bool
  default = false
}

########################################
# redis
########################################
variable "redis_sku_name" {
  type    = string
  default = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "redis_sku_name invalid"
  }
}

variable "redis_sku_family" {
  type    = string
  default = "C"
  validation {
    condition     = contains(["C", "P"], var.redis_sku_family)
    error_message = "redis_sku_family invalid"
  }
}

variable "redis_capacity" {
  type    = number
  default = 1
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "redis_capacity invalid"
  }
}

########################################
# plane-scoped hub rg
########################################
variable "rg_plane_name" {
  type    = string
  default = null
}

########################################
# optional hub overrides
########################################
variable "hub_subscription_id" {
  type    = string
  default = null
}

variable "hub_tenant_id" {
  type    = string
  default = null
}

########################################
# optional per-env overrides (compat)
########################################
variable "dev_subscription_id" {
  type    = string
  default = null
}

variable "dev_tenant_id" {
  type    = string
  default = null
}

variable "qa_subscription_id" {
  type    = string
  default = null
}

variable "qa_tenant_id" {
  type    = string
  default = null
}

variable "uat_subscription_id" {
  type    = string
  default = null
}

variable "uat_tenant_id" {
  type    = string
  default = null
}

variable "prod_subscription_id" {
  type    = string
  default = null
}

variable "prod_tenant_id" {
  type    = string
  default = null
}

########################################
# overrides to bypass core state for observability
########################################
variable "law_workspace_id_override" {
  type    = string
  default = null
}

variable "appi_connection_string_override" {
  type    = string
  default = null
}

########################################
# cosmos db for postgresql (citus)
########################################
variable "create_cdbpg" {
  type    = bool
  default = false
}

variable "cdbpg_node_count" {
  type    = number
  default = 0
}

variable "cdbpg_coordinator_vcore_count" {
  type    = number
  default = 4
}

variable "cdbpg_coordinator_storage_quota_in_mb" {
  type    = number
  default = 32768
}

variable "cdbpg_coordinator_server_edition" {
  type    = string
  default = "BurstableGeneralPurpose" # BurstableGeneralPurpose | GeneralPurpose | MemoryOptimized
}

variable "cdbpg_node_vcore_count" {
  type    = number
  default = 2
}

variable "cdbpg_node_storage_quota_in_mb" {
  type    = number
  default = 32768
}

variable "cdbpg_node_server_edition" {
  type    = string
  default = "GeneralPurpose" # GeneralPurpose | MemoryOptimized
}

variable "cdbpg_citus_version" {
  type    = string
  default = null             # e.g., "12.1"
}

variable "cdbpg_enable_private_endpoint" {
  type    = bool
  default = true
}

variable "cdbpg_admin_password" {
  type      = string
  sensitive = true
  # no default on purpose: must be provided via tfvars or pipeline secret
}

variable "cdbpg_preferred_primary_zone" {
  type    = string
  default = null
  validation {
    condition     = var.cdbpg_preferred_primary_zone == null || contains(["1", "2", "3"], var.cdbpg_preferred_primary_zone)
    error_message = "cdbpg_preferred_primary_zone must be \"1\", \"2\", or \"3\" (or null)."
  }
}



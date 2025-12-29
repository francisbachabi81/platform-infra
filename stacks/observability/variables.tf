# Core deployment context
variable "product" {
  type        = string
  description = "hrz (Azure Gov) or pub (Azure Commercial)"
}

variable "env" {
  type        = string
  default     = null
  description = "dev | qa | uat | prod (optional if plane provided)"
  validation {
    condition     = var.env == null || contains(["dev", "qa", "uat", "prod"], lower(var.env))
    error_message = "env must be one of: dev, qa, uat, prod."
  }
}

variable "plane" {
  type        = string
  default     = null
  description = "nonprod | prod (optional if env provided)"
  validation {
    condition     = var.plane == null || contains(["nonprod", "prod"], lower(var.plane))
    error_message = "plane must be one of: nonprod, prod."
  }
}

variable "location" {
  type    = string
  default = null
}

variable "region" {
  description = "short region code, e.g. usaz or cus"
  type        = string
}

variable "subscription_id" {
  type    = string
  default = null
}

variable "tenant_id" {
  type    = string
  default = null
}

# Remote state configuration
variable "state_rg" {
  type    = string
  default = null
}

variable "state_sa" {
  type    = string
  default = null
}

variable "state_container" {
  type    = string
  default = null
}

# Provider scoping and subscription/tenant overrides
variable "core_subscription_id" {
  type    = string
  default = null
}

variable "core_tenant_id" {
  type    = string
  default = null
}

variable "env_subscription_id" {
  type    = string
  default = null
}

variable "env_tenant_id" {
  type    = string
  default = null
}

variable "dev_subscription_id" {
  description = "optional dev subscription override"
  type        = string
  default     = null
}

variable "dev_tenant_id" {
  description = "optional dev tenant override"
  type        = string
  default     = null
}

variable "qa_subscription_id" {
  description = "optional qa subscription override"
  type        = string
  default     = null
}

variable "qa_tenant_id" {
  description = "optional qa tenant override"
  type        = string
  default     = null
}

variable "prod_subscription_id" {
  description = "optional prod subscription override"
  type        = string
  default     = null
}

variable "prod_tenant_id" {
  description = "optional prod tenant override"
  type        = string
  default     = null
}

variable "uat_subscription_id" {
  description = "optional uat subscription override"
  type        = string
  default     = null
}

variable "uat_tenant_id" {
  description = "optional uat tenant override"
  type        = string
  default     = null
}

variable "env_rg_name" {
  type        = string
  default     = null
  description = "ENV subscription resource group name (overrides remote-state value)."
}

# Diagnostic naming and LAW overrides
variable "diag_name" {
  type        = string
  default     = "obs-diag"
  description = "Diagnostic setting name to apply to resources."
}

variable "law_workspace_id_override" {
  type        = string
  default     = null
  description = "If set, send all diagnostic settings to this LAW id."
}

variable "law_workspace_guid_override" {
  description = "Optional override for the Log Analytics workspace GUID for Traffic Analytics, if not exposed via core remote state."
  type        = string
  default     = null
}

# Resource ID inputs for diagnostics
variable "enable_cosmos_diagnostics" {
  type        = bool
  default     = true
  description = "Enable Cosmos DB diagnostic settings when account IDs are discovered or provided."
}

variable "cosmos_account_ids" {
  type        = list(string)
  default     = []
  description = "Explicit Cosmos DB account resource IDs to enable diagnostics on."
}

variable "enable_kv_diagnostics" {
  type        = bool
  default     = true
  description = "Enable Key Vault diagnostic settings when vault IDs are discovered or provided."
}

variable "key_vault_ids" {
  type        = list(string)
  default     = []
  description = "Explicit Key Vault resource IDs to enable diagnostics on."
}

variable "enable_aks_diagnostics" {
  type        = bool
  default     = true
  description = "Enable AKS diagnostic settings when AKS ids are discovered."
}

# Alerting and tags
variable "alert_emails" {
  type        = list(string)
  default     = []
  description = "Email recipients for fallback Action Group (if core AG not found)."
}

variable "action_group_email_receivers" {
  type = list(object({
    name          = string
    email_address = string
  }))
  default     = []
  description = "Optional structured list of receivers; if set, overrides alert_emails."
}

variable "tags_extra" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to supported resources (e.g., Action Group)."
}

# Policy compliance (Event Grid + Logic App)
variable "enable_policy_compliance_alerts" {
  description = "Enable creation of PolicyStates Event Grid system topic + Logic App alerts."
  type        = bool
  default     = false
}

variable "policy_alert_email" {
  description = "Email address to receive policy non-compliance alerts."
  type        = string
  default     = "test@org.com"
}

variable "policy_source_subscriptions" {
  description = <<DESC
Map of subscriptions to monitor for policy compliance.
Key is a short label (e.g., "core", "nonprod", "prod").
Value is the subscription_id to use in the Event Grid system topic source.
DESC
  type = map(object({
    subscription_id = string
  }))
  default = {}
}

# Subscription budgets for policy sources
variable "enable_subscription_budgets" {
  type        = bool
  description = "Enable subscription-level consumption budgets for policy_source_subscriptions"
  default     = false
}

variable "subscription_budget_amount" {
  type        = number
  description = "Monthly budget amount (in currency of the subscription, e.g. USD)"
  default     = 500
}

variable "subscription_budget_threshold" {
  type        = number
  description = "Alert threshold percentage for budgets (e.g. 80 = 80%)"
  default     = 80
}

variable "subscription_budget_start_date" {
  type        = string
  description = "ISO8601 start date for budget (e.g. 2025-01-01T00:00:00Z)"
  default     = "2025-01-01T00:00:00Z"
}

variable "subscription_budget_end_date" {
  type        = string
  description = "ISO8601 end date for budget (far in the future is OK)"
  default     = "2030-01-01T00:00:00Z"
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "Emails to receive budget notifications (falls back to alert_emails if empty)"
  default     = []
}

# NSG flow logs
variable "enable_nsg_flow_logs" {
  description = "Enable NSG flow logs for all NSGs emitted by shared-network."
  type        = bool
  default     = true
}

variable "nsg_flow_logs_retention_days" {
  description = "Retention (days) for NSG flow logs in Traffic Analytics."
  type        = number
  default     = 30
}

variable "nsg_flow_logs_storage_account_id_override" {
  description = "Optional override for the Storage Account used for NSG flow logs. Must live in Core subscription."
  type        = string
  default     = null
}

# Global diagnostic toggles
variable "enable_subscription_diagnostics" {
  type        = bool
  description = "Enable subscription-level activity diagnostics"
  default     = true
}

variable "enable_nsg_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings on NSGs"
  default     = true
}

variable "enable_sa_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Storage Accounts"
  default     = true
}

variable "enable_sbns_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Service Bus namespaces"
  default     = true
}

variable "enable_ehns_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Event Hubs namespaces"
  default     = true
}

variable "enable_pg_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for PostgreSQL Flexible Server"
  default     = true
}

variable "enable_redis_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Azure Cache for Redis"
  default     = true
}

variable "enable_rsv_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Recovery Services Vaults"
  default     = true
}

variable "enable_appi_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Application Insights"
  default     = false
}

variable "enable_vpng_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for VPN Gateways"
  default     = true
}

variable "enable_fa_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Function Apps"
  default     = true
}

variable "enable_web_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Web Apps"
  default     = true
}

variable "enable_appgw_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Application Gateways"
  default     = true
}

variable "enable_afd_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings for Azure Front Door"
  default     = true
}

# Per-resource diagnostic log categories
variable "sa_log_categories" {
  type        = list(string)
  description = "Storage Account log categories to enable"
  default     = ["StorageRead", "StorageWrite", "StorageDelete"]
}

variable "kv_log_categories" {
  type        = list(string)
  description = "Key vault log categories to enable"
  default = [
    "AuditEvent",
    "AzurePolicyEvaluationDetails"
  ]
}

variable "sbns_log_categories" {
  type        = list(string)
  description = "Service Bus namespace log categories to enable"
  default = [
    "ApplicationMetricsLogs",
    "DataDRLogs",
    "DiagnosticErrorLogs",
    "OperationalLogs",
    "RuntimeAuditLogs",
    "VNetAndIPFilteringLogs"
  ]
}

variable "ehns_log_categories" {
  type        = list(string)
  description = "Event Hubs namespace log categories to enable"
  default = [
    "ApplicationMetricsLogs",
    "ArchiveLogs",
    "AutoScaleLogs",
    "CustomerManagedKeyUserLogs",
    "DataDRLogs",
    "DiagnosticErrorLogs",
    "EventHubVNetConnectionEvent",
    "KafkaCoordinatorLogs",
    "KafkaUserErrorLogs",
    "OperationalLogs",
    "RuntimeAuditLogs"
  ]
}

variable "pg_log_categories" {
  type        = list(string)
  description = "PostgreSQL Flexible Server log categories to enable"
  default     = [
    "PostgreSQLLogs",
    "PostgreSQLFlexTableStats",
    "PostgreSQLFlexSessions",
  ]
}

variable "redis_log_categories" {
  type        = list(string)
  description = "Redis log categories to enable"
  default     = [
    "ConnectedClientList",
    "CacheRead",
    "CacheWrite",
    "CacheDelete",
  ]
}

variable "appi_log_categories" {
  type        = list(string)
  description = "Application Insights log categories to enable"
  default     = [
    "AppRequests",
    "AppSystemEvents",
    "AppPerformanceCounters",
    "AppAvailabilityResults",
    "AppDependencies",
    "AppExceptions",
    "AppPageViews",
    "AppTraces",
  ]
}

variable "vpng_log_categories" {
  type        = list(string)
  description = "VPN Gateway log categories to enable"
  default     = [
    "GatewayDiagnosticLog",
    "TunnelDiagnosticLog",
    "RouteDiagnosticLog",
    "P2SDiagnosticLog"
  ]
}

variable "fa_log_categories" {
  type        = list(string)
  description = "Function App log categories to enable"
  default     = [
    "FunctionAppLogs"
  ]
}

variable "web_log_categories" {
  type        = list(string)
  description = "Web App log categories to enable"
  default     = [
    "AppServiceHTTPLogs",
    "AppServiceConsoleLogs",
    "AppServiceAppLogs",
  ]
}

variable "appgw_log_categories" {
  type        = list(string)
  description = "Application Gateway log categories to enable"
  default     = [
    "ApplicationGatewayAccessLog",
    "ApplicationGatewayPerformanceLog",
    "ApplicationGatewayFirewallLog",
  ]
}

variable "afd_log_categories" {
  type        = list(string)
  description = "Azure Front Door log categories to enable"
  default     = [
    "FrontdoorAccessLog",
    "FrontdoorWebApplicationFirewallLog",
  ]
}

variable "nsg_log_categories" {
  type        = list(string)
  description = "NSG diagnostic log categories to enable"
  default     = [
    "NetworkSecurityGroupEvent",
    "NetworkSecurityGroupRuleCounter",
  ]
}

variable "subscription_log_categories" {
  type        = list(string)
  description = "Subscription-level Activity Log categories to enable"
  default = [
    "Administrative",
    "Security",
    "ServiceHealth",
    "Alert",
    "Recommendation",
    "Policy",
    "Autoscale",
    "ResourceHealth"
  ]
}

variable "rsv_log_categories" {
  type        = list(string)
  description = "Recovery Services Vault log categories to enable"
  default = [
    "AzureSiteRecoveryJobs",
    "AzureSiteRecoveryEvents",
    "CoreAzureBackup",
  ]
}

variable "cosmos_log_categories" {
  type        = list(string)
  description = "Cosmos DB log categories to enable"
  default = [
    "DataPlaneRequests",
    "QueryRuntimeStatistics",
    "PartitionKeyRUConsumption",
    "ControlPlaneRequests",
  ]
}

# Cost exports (Cost Management)
variable "enable_cost_exports" {
  description = "Enable Cost Management exports (scheduled + manual) to a core storage account."
  type        = bool
  default     = false
}

variable "cost_exports_schedule_from" {
  type        = string
  description = "ISO8601 schedule start for cost exports (stable). Example: 2025-01-01T00:00:00Z"
  default     = "2025-01-01T00:00:00Z"
}

variable "cost_exports_container_name" {
  description = "Blob container name for cost exports."
  type        = string
  default     = "cost-exports"
}

variable "cost_exports_root_folder" {
  description = "Root folder path inside the container."
  type        = string
  default     = "cost-management"
}

variable "cost_exports_schedule_end_date" {
  description = "Optional schedule end date (ISO8601). Leave null for no end date."
  type        = string
  default     = null
}

variable "vnet_ids_by_env" {
  description = "Optional explicit VNet IDs by env. If empty, module will try to discover VNets from shared-network remote state."
  type        = map(list(string))
  default     = {}
}

# VNet flow logs (preferred; replaces NSG flow logs)
variable "enable_vnet_flow_logs" {
  description = "Enable VNet flow logs for VNets (hub/dev/qa/prod/uat) using Network Watcher."
  type        = bool
  default     = null
}

variable "vnet_flow_logs_retention_days" {
  description = "Retention (days) for VNet flow logs in Traffic Analytics."
  type        = number
  default     = null
}

variable "vnet_flow_logs_storage_account_id_override" {
  description = "Optional override for the Storage Account used for VNet flow logs. Must live in Core subscription."
  type        = string
  default     = null
}

variable "enable_cosmos_metrics" {
  type        = bool
  description = "Enable diagnostic metrics for Cosmos diagnostic settings."
  default     = true
}

variable "enable_rsv_metrics" {
  type        = bool
  description = "Enable diagnostic metrics for Recovery Services Vault diagnostic settings."
  default     = true
}

variable "aks_collect_all_logs" {
  type        = bool
  description = "Collect all Container Insights logs (portal-style 'Collected data: All')."
  default     = true
}

variable "aks_collect_performance" {
  type        = bool
  description = "Collect node/perf counters (Microsoft-Perf). High cost. Default off for cost optimization."
  default     = false
}

variable "enable_aks_managed_prometheus" {
  type        = bool
  description = "Enable managed Prometheus (separate cost). Default off."
  default     = false
}

variable "aks_resource_ids_override" {
  type        = list(string)
  description = "Optional: explicit AKS resource IDs to alert on (used when remote state does not expose AKS IDs)."
  default     = []
}

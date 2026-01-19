product  = "pub"
env      = "dev"
location = "Central US"
region          = "cus"

# Alerting (Action Group recipients)
action_group_email_receivers = [
  {
    name                    = "Ops Manager"
    email_address           = "francis.bachabi@intterragroup.com"
    use_common_alert_schema = true
  },
  {
    name                    = "Cloud Ops Alerts"
    email_address           = "cloudops@intterragroup.com"
    use_common_alert_schema = true
  }
]

# FedRAMP Policy events pipeline
# enable_policy_compliance_alerts = false
policy_alert_email   = "cloudops@intterragroup.com"

policy_source_subscriptions = {
  dev-core = {
    subscription_id = "57f8aa30-981c-4764-94f6-6691c4d5c01c"
  }
  core = {
    subscription_id = "ee8a4693-54d4-4de8-842b-b6f35fc0674d"
  }
  qa-core = {
    subscription_id = "647feab6-e53a-4db2-99ab-55d04a5997d7"
  }
}

# Subscription budgets
enable_subscription_budgets    = true
subscription_budget_amount     = 500
subscription_budget_threshold  = 80
subscription_budget_start_date = "2025-12-01T00:00:00Z"
subscription_budget_end_date   = "2035-01-01T00:00:00Z"

budget_alert_emails = [
  "cloudops@intterragroup.com"
]

# NSG flow logs
# enable_nsg_flow_logs = false

# Tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}

enable_cost_exports = true
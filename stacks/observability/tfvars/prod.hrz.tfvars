# Core context
product = "hrz"
env     = "prod"

location = "USGov Arizona"
region   = "usaz"

# Alerting (Action Group recipients)
action_group_email_receivers = [
  {
    name          = "Ops Manager"
    email_address = "francis.bachabi@intterragroup.com"
  },
  {
    name          = "Cloud Ops Alerts"
    email_address = "cloudops@intterragroup.com"
  }
]

# FedRAMP policy compliance pipeline
# enable_policy_compliance_alerts = false
policy_alert_email              = "cloudops@intterragroup.com"

policy_source_subscriptions = {
  prod-core = {
    subscription_id = "<PROD_CORE_SUBSCRIPTION_ID>"
  }
  core = {
    subscription_id = "<PROD_SHARED_CORE_SUBSCRIPTION_ID>"
  }
  uat-core = {
    subscription_id = "<UAT_CORE_SUBSCRIPTION_ID>"
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
# Core context
product = "hrz"
env     = "uat"

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

policy_alert_email = "cloudops@intterragroup.com"

policy_source_subscriptions = {
  prod-core = {
    subscription_id = "641d3872-8322-4bdb-83ce-bfbc119fa3cd"
  }
  core = {
    subscription_id = "d072f6c1-7c2d-4d27-8ffb-fd96f828c3b6"
  }
  uat-core = {
    subscription_id = "4d2bdae0-9da9-4657-827d-d44867ec2f0a"
  }
}

# Subscription budgets
enable_subscription_budgets    = false
subscription_budget_amount     = 500
subscription_budget_threshold  = 80
subscription_budget_start_date = "2026-01-01T00:00:00Z"
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

enable_cost_exports = false
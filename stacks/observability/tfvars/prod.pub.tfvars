# Core context
product = "pub"
env     = "prod"

location = "Central US"
region  = "cus"

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
    subscription_id = "7043433f-e23e-4206-9930-314695d94a6c"
  }
  core = {
    subscription_id = "ec41aef1-269c-4633-8637-924c395ad181"
  }
  uat-core = {
    subscription_id = "11494ded-2cf5-44b7-9b1c-58fd64125c20"
  }
}

# Subscription budgets
enable_subscription_budgets    = true
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

enable_cost_exports = true
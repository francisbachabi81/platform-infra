product  = "pub"
env      = "dev"
location = "Central US"
region          = "cus"

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
enable_policy_compliance_alerts = true
management_group_name = "b332ab98-00a1-42a1-9388-63538bc86612"
policy_alert_email   = "cloudops@intterragroup.com"
policy_source_subscriptions = {
  dev-core = {
    subscription_id = "62ae6908-cbcb-40cb-8773-54bd318ff7f9"
  }
  core = {
    subscription_id = "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
  }
  qa-core = {
    subscription_id = "d4c1d472-722c-49c2-857f-4243441104c8"
  }
}

enable_subscription_budgets = true
subscription_budget_amount = 500
subscription_budget_threshold = 80
subscription_budget_start_date = "2025-12-01T00:00:00Z"
subscription_budget_end_date   = "2035-01-01T00:00:00Z"
budget_alert_emails = [
  "cloudops@intterragroup.com"
]

# tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}
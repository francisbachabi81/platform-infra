product  = "hrz"
env      = "dev"
location    = "USGov Arizona"
region          = "usaz"

action_group_email_receivers = [
  {
    name                    = "Ops Manager"
    email_address           = "francis.bachabi@intterragroup.com"
    use_common_alert_schema = true
  },
  {
    name                    = "Ops Azure Alerts"
    email_address           = "azure-alerts@intterragroup.com"
    use_common_alert_schema = true
  }
]

# FedRAMP Policy events pipeline
enable_policy_compliance_alerts = true
management_group_name = "b332ab98-00a1-42a1-9388-63538bc86612"
policy_alert_email   = "francis.bachabi@intterragroup.com"
policy_subscriptions = [
  {
    subscription_id     = "62ae6908-cbcb-40cb-8773-54bd318ff7f9"
    resource_group_name = "rg-hrz-np-usaz-core-01"
  },
  {
    subscription_id     = "df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
    resource_group_name = "rg-hrz-np-usaz-core-01"
  },
  {
    subscription_id     = "d4c1d472-722c-49c2-857f-4243441104c8"
    resource_group_name = "rg-hrz-np-usaz-core-01"
  },
]

# tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}
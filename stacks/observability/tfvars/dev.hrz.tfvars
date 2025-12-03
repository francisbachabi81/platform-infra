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

# tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}
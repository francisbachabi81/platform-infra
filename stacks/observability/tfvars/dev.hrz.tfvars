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

# tags
tags_extra = {
  purpose = "observability"
  layer   = "platform"
}
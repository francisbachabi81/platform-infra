resource "azurerm_web_application_firewall_policy" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  policy_settings {
    enabled             = true
    mode                = var.mode
    request_body_check  = true
  }

  managed_rules {
    managed_rule_set {
      type    = var.managed_rule_set_type
      version = var.managed_rule_set_version
    }

    dynamic "exclusion" {
      for_each = var.exclusions
      content {
        match_variable          = exclusion.value.match_variable
        selector_match_operator = exclusion.value.selector_match_operator
        selector                = exclusion.value.selector
      }
    }
  }

  tags = var.tags
}
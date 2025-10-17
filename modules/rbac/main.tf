terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  # build a cartesian map: one resource per (principal_id, role_name)
  combos = {
    for idx, c in setproduct(var.principal_object_ids, var.role_definition_names) :
    "${c[0]}|${c[1]}" => { principal_id = c[0], role_name = c[1] }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each             = local.combos
  scope                = var.scope_id
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role_name
}

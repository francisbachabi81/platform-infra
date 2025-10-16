variable "scope_id" {
  description = "Scope for the role assignment (subscription, RG, or resource ID)."
  type        = string
}

variable "principal_object_ids" {
  description = "Object IDs for users, groups, or service principals."
  type        = list(string)
}

variable "role_definition_names" {
  description = "Built-in role names to assign at the given scope."
  type        = list(string)
}

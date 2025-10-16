variable "resource_group_name" {
  type = string
}

variable "namespace_name" {
  type = string
}

variable "eventhub_name" {
  type = string
}

variable "consumer_group_names" {
  description = "List of consumer group names to create."
  type        = list(string)
}

variable "consumer_group_metadata" {
  description = "Optional map of { cg_name => user_metadata }."
  type        = map(string)
  default     = {}
}

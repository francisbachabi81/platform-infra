variable "name" {
  description = "Resource Group name."
  type        = string
}

variable "location" {
  description = "Azure region (e.g., eastus, centralus)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the Resource Group."
  type        = map(string)
  default     = {}
}

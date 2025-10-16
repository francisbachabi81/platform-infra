variable "resource_group_name" {
  type        = string
  description = "Resource group for the Front Door profile."
}

variable "profile_name" {
  type        = string
  description = "Front Door profile name."
}

variable "endpoint_name" {
  type        = string
  description = "Front Door endpoint name."
}

variable "sku_name" {
  type        = string
  description = "Front Door SKU."
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "sku_name must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}

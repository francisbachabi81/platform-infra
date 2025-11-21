variable "resource_group_name" {
  description = "Core resource group where ACS + Email live"
  type        = string
}

variable "acs_name" {
  description = "Azure Communication Service name (e.g. acs-hrz-np-usaz-01)"
  type        = string
}

variable "email_service_name" {
  description = "Email Communication Service name (e.g. email-hrz-np-usaz-01)"
  type        = string
}

variable "email_domain_name" {
  description = "Email Communication Service domain name. Use 'AzureManagedDomain' for Azure-managed."
  type        = string
  default     = "AzureManagedDomain"
}

variable "data_location" {
  description = "ACS data location (e.g. 'United States' for pub, 'usgov' for hrz)"
  type        = string
}

variable "email_data_location" {
  description = "Email service data location"
  type        = string
}

variable "tags" {
  description = "Tags to apply to ACS + Email resources"
  type        = map(string)
  default     = {}
}
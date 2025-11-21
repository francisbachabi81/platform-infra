variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "acs_name" {
  type = string
}

variable "email_service_name" {
  type = string
}

variable "data_location" {
  description = "ACS/Email data location (e.g. 'United States')"
  type        = string
}

variable "enable_custom_domain" {
  description = "Create a customer-managed email domain resource"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Customer-managed email domain (e.g. 'mail.example.com')"
  type        = string
  default     = null
}

variable "associate_custom_domain" {
  description = "Associate ACS with the custom domain (only after DNS verification)"
  type        = bool
  default     = false
}
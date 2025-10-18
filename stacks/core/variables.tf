# plane/product/env
variable "plane" {
  type = string
  validation {
    condition     = contains(["np","pr","nonprod","prod"], lower(var.plane))
    error_message = "plane must be one of: np, pr, nonprod, prod."
  }
}

variable "product" { type = string }  # hrz | pub
variable "region"  { type = string }  # e.g., usaz, cus
variable "location"{ type = string }

# provider
variable "subscription_id" { type = string }
variable "tenant_id"       { type = string }

# rg in hub subscription scoped to plane
variable "rg_plane_name" { type = string }

# tags
variable "tags" {
  type    = map(string)
  default = {}
}

# observability knobs
variable "law_sku" {
  type    = string
  default = "PerGB2018"
}
variable "law_retention_days" {
  type    = number
  default = 30
}
variable "appi_internet_ingestion_enabled" {
  type    = bool
  default = true
}
variable "appi_internet_query_enabled" {
  type    = bool
  default = true
}

# shared-network remote state read (optional)
variable "shared_state_enabled" {
  type    = bool
  default = true
}
variable "state_rg_name"        { type = string }
variable "state_sa_name"        { type = string }
variable "state_container_name" { type = string }

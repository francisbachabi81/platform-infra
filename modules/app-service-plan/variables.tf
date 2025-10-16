variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "os_type" {
  type    = string
  default = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "sku_name" {
  # examples: F1/D1, B1-3, S1-3, P1-3, P*v2, P*v3, P*mv3, I* v2, EP1-3, Y1 --- B1/B2/B3, S1/S2/S3, P1/P2/P3, P1v2/P2v2/P3v2, P0v3/P1v3/P2v3/P3v3, P1mv3/P2mv3/P3mv3, I1/I2/I3, I1v2/I2v2/I3v2, EP1/EP2/EP3, Y1
  type    = string
  default = "S1"
}

variable "worker_count" {
  # dedicated tiers; null for serverless
  type    = number
  default = null
}

variable "maximum_elastic_worker_count" {
  # elastic premium burst ceiling
  type    = number
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "display_name" { type = string }

variable "sign_in_audience" {
  type    = string
  default = "AzureADMyOrg" # or AzureADMultipleOrgs
}

variable "spa_redirect_uris" {
  type    = list(string)
  default = []
}

variable "create_secret" {
  type    = bool
  default = true
}

variable "secret_hours_valid" {
  type    = number
  default = 8760 # 1 year
}

variable "owners" {
  type    = list(string)
  default = []
}

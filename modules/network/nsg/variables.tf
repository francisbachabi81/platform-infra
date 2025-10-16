variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_nsgs" {
  type = map(object({
    name      = string
    subnet_id = string
  }))
}
variable "tags" { 
  type = map(string) 
  default = {} 
}
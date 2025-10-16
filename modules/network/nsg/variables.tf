variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_nsgs" {
  description = "Map: key => { name, subnet_id }"
  type = map(object({
    name      = string
    subnet_id = string   # may be unknown at plan (that’s ok)
  }))
}
variable "tags" { 
  type = map(string) 
  default = {} 
}
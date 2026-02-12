output "profile_id" {
  value = azapi_resource.profile.id
}

output "profile_name" {
  value = var.profile_name
}

output "endpoint_id" {
  value = azapi_resource.endpoint.id
}

output "endpoint_name" {
  value = var.endpoint_name
}

output "sku_name" {
  value = var.sku_name
}

output "endpoint_hostname" {
  value = try(data.azapi_resource.endpoint_read.output.properties.hostName, null)
}
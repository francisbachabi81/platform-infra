output "client_id" {
  value = azuread_application.app.client_id
}

output "sp_object_id" {
  value = azuread_service_principal.sp.object_id
}

output "secret_value" {
  value     = try(azuread_service_principal_password.secret[0].value, null)
  sensitive = true
}

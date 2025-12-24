output "application_gateway" {
  value = {
    id   = local.agw_id
    name = local.agw_name
  }
}

output "ssl" {
  value = {
    key_vault_id        = local.kv_id
    key_vault_uri       = local.kv_uri
    ssl_key_vault_secret_id = local.ssl_secret_id
    ssl_certificate_name     = var.ssl_certificate_name
  }
}

output "application_gateway" {
  value = {
    id   = local.agw_id
    name = local.agw_name
  }
}

output "ssl" {
  value = {
    key_vault_id  = local.kv_id
    key_vault_uri = local.kv_uri

    ssl_key_vault_secret_ids_requested = local.ssl_cert_secret_ids

    ssl_certificates_payload = local._ssl_certs

    ssl_secret_to_cert_name = try(local.ssl_secret_to_cert_name, {})
  }
}

output "debug_appgw_config" {
  value = {
    kv_id             = local.kv_id
    kv_uri            = local.kv_uri
    uami_principal_id = local.uami_principal_id
    agw_id            = local.agw_id
    agw_name          = local.agw_name
    shared_uami       = local.shared_uami

    agw_ready    = local.agw_ready
    wants_config = local.wants_config

    requested_ssl_cert_count = length(local.ssl_cert_secret_ids)
    applied_ssl_cert_count   = length(local._ssl_certs)

    unresolved_ssl_certs = [
      for name, sid in local.ssl_cert_secret_ids :
      name if sid == null || trimspace(sid) == ""
    ]

    duplicate_ssl_cert_names = [
      for name, sid in local.ssl_cert_secret_ids :
      name
      if sid != null && trimspace(sid) != "" &&
         can(local.ssl_secret_to_cert_name[sid]) &&
         local.ssl_secret_to_cert_name[sid] != name
    ]
  }
}

# output "application_gateway" {
#   value = {
#     id   = local.agw_id
#     name = local.agw_name
#   }
# }

# output "ssl" {
#   value = {
#     key_vault_id  = local.kv_id
#     key_vault_uri = local.kv_uri
#     ssl_key_vault_secret_ids = local.ssl_cert_secret_ids
#     ssl_certificates_payload = local._ssl_certs
#   }
# }

# output "debug_appgw_config" {
#   value = {
#     kv_id             = local.kv_id
#     kv_uri            = local.kv_uri
#     uami_principal_id = local.uami_principal_id
#     agw_id            = local.agw_id
#     agw_name          = local.agw_name
#     shared_uami       = local.shared_uami

#     agw_ready               = local.agw_ready
#     wants_config            = local.wants_config
#     resolved_ssl_cert_count = length(local._ssl_certs)
#     unresolved_ssl_certs    = [
#       for name, sid in local.ssl_cert_secret_ids :
#       name if sid == null || trimspace(sid) == ""
#     ]
#   }
# }


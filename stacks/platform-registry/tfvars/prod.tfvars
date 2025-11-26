region   = "usaz"
location = "USGov Arizona"

registry_name = "acrprusaz01"
# registry_name = "intterra"

acr_sku = "Premium"

role_assignments = [
  # { principal_id = "spn-object-id-here", role_definition_name = "AcrPull" },
  # { principal_id = "spn-object-id-here", role_definition_name = "AcrPush" }
]

tags = {
  cost_center         = "shared-global"
  data_classification = "internal"
}

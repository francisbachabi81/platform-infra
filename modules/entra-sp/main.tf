resource "azuread_application" "app" {
  display_name     = var.display_name
  sign_in_audience = var.sign_in_audience
  owners           = var.owners

  dynamic "single_page_application" {
    for_each = length(var.spa_redirect_uris) > 0 ? [1] : []
    content {
      redirect_uris = var.spa_redirect_uris
    }
  }
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
  owners    = var.owners
}

resource "azuread_service_principal_password" "secret" {
  count                = var.create_secret ? 1 : 0
  service_principal_id = azuread_service_principal.sp.object_id
  display_name         = "${var.display_name}-secret"
  end_date             = timeadd(timestamp(), "${var.secret_hours_valid}h")
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# locals
locals {
  app_name_clean           = replace(lower(trimspace(var.name)), "-", "")
  pdns_site_id             = lookup(var.private_dns_zone_ids, "privatelink.azurewebsites.net", null)
  pdns_scm_id              = lookup(var.private_dns_zone_ids, "privatelink.scm.azurewebsites.net", null)
  pe_site_name_effective   = coalesce(var.pe_site_name,  "pep-${local.app_name_clean}-site")
  psc_site_name_effective  = coalesce(var.psc_site_name, "psc-${local.app_name_clean}-site")
  site_zone_group_effect   = coalesce(var.site_zone_group_name, "pdns-${local.app_name_clean}-site")
  pe_scm_name_effective    = coalesce(var.pe_scm_name,  "pep-${local.app_name_clean}-scm")
  psc_scm_name_effective   = coalesce(var.psc_scm_name, "psc-${local.app_name_clean}-scm")
  scm_zone_group_effect    = coalesce(var.scm_zone_group_name, "pdns-${local.app_name_clean}-scm")
  scm_pe_supported         = can(regex("^(P\\dv2|P\\dv3|I\\dv2)$", upper(var.plan_sku_name)))
  enable_scm_pe_effective  = var.enable_scm_private_endpoint && local.scm_pe_supported
}

# linux function app
resource "azurerm_linux_function_app" "func_linux" {
  count                         = lower(var.os_type) == "linux" ? 1 : 0
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = var.service_plan_id
  functions_extension_version   = var.functions_extension_version
  https_only                    = true
  public_network_access_enabled = false
  storage_account_name          = var.storage_account_name
  storage_account_access_key    = var.storage_account_access_key

  identity { type = "SystemAssigned" }

  site_config {
    always_on = var.always_on

    application_stack {
      node_version            = try(var.stack.node_version, null)
      python_version          = try(var.stack.python_version, null)
      dotnet_version          = try(var.stack.dotnet_version, null)
      java_version            = try(var.stack.java_version, null)
      powershell_core_version = try(var.stack.powershell_core_version, null)
    }

    application_insights_connection_string = var.application_insights_connection_string
    ftps_state    = "Disabled"
    http2_enabled = true
  }

  app_settings = merge(
    {
      WEBSITE_RUN_FROM_PACKAGE       = var.website_run_from_package
      FUNCTIONS_WORKER_PROCESS_COUNT = tostring(var.functions_worker_process_count)
    },
    var.app_settings
  )

  lifecycle {
    ignore_changes = [
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      virtual_network_subnet_id
    ]
  }

  tags = var.tags
}

# windows function app
resource "azurerm_windows_function_app" "func_windows" {
  count                         = lower(var.os_type) == "windows" ? 1 : 0
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = var.service_plan_id
  functions_extension_version   = var.functions_extension_version
  https_only                    = true
  public_network_access_enabled = false
  storage_account_name          = var.storage_account_name
  storage_account_access_key    = var.storage_account_access_key

  identity { type = "SystemAssigned" }

  site_config {
    always_on = var.always_on

    application_stack {
      node_version            = try(var.stack.node_version, null)
      dotnet_version          = try(var.stack.dotnet_version, null)
      java_version            = try(var.stack.java_version, null)
      powershell_core_version = try(var.stack.powershell_core_version, null)
    }

    application_insights_connection_string = var.application_insights_connection_string
    ftps_state    = "Disabled"
    http2_enabled = true
  }

  app_settings = merge(
    {
      WEBSITE_RUN_FROM_PACKAGE       = var.website_run_from_package
      FUNCTIONS_WORKER_PROCESS_COUNT = tostring(var.functions_worker_process_count)
    },
    var.app_settings
  )

  lifecycle {
    ignore_changes = [
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      virtual_network_subnet_id
    ]
  }

  tags = var.tags
}

# common
locals {
  func_id = coalesce(
    try(azurerm_linux_function_app.func_linux[0].id, null),
    try(azurerm_windows_function_app.func_windows[0].id, null)
  )
}

# vnet integration
resource "azurerm_app_service_virtual_network_swift_connection" "vnet" {
  count          = var.vnet_integration_subnet_id == null ? 0 : 1
  app_service_id = local.func_id
  subnet_id      = var.vnet_integration_subnet_id
}

# sites pe
resource "azurerm_private_endpoint" "sites" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = local.pe_site_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_site_name_effective
    private_connection_resource_id = local.func_id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.pdns_site_id == null ? [] : [1]
    content {
      name                 = local.site_zone_group_effect
      private_dns_zone_ids = [local.pdns_site_id]
    }
  }

  tags = var.tags
}

# scm pe
resource "azurerm_private_endpoint" "scm" {
  count               = var.enable_private_endpoint && local.enable_scm_pe_effective ? 1 : 0
  name                = local.pe_scm_name_effective
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = local.psc_scm_name_effective
    private_connection_resource_id = local.func_id
    subresource_names              = ["scm"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.pdns_scm_id == null ? [] : [1]
    content {
      name                 = local.scm_zone_group_effect
      private_dns_zone_ids = [local.pdns_scm_id]
    }
  }

  tags = var.tags
}
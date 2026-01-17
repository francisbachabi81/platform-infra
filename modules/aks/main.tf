terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  use_managed_outbound = var.outbound_public_ip_id == null && length(var.outbound_public_ip_prefix_ids) == 0
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = "${var.name}-dns"
  private_cluster_enabled = true
  kubernetes_version      = var.kubernetes_version
  sku_tier                = var.sku_tier

  # oidc_issuer_enabled       = var.oidc_issuer_enabled
  # workload_identity_enabled = var.workload_identity_enabled

  # Only legal when AAD is enabled
  local_account_disabled  = var.enable_aad && var.disable_local_accounts
  azure_policy_enabled    = true

  node_resource_group = var.node_resource_group
  

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    vnet_subnet_id       = var.default_nodepool_subnet_id
    orchestrator_version = var.kubernetes_version
    type                 = "VirtualMachineScaleSets"
    temporary_name_for_rotation = var.temporary_name_for_rotation

    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? [var.user_assigned_identity_id] : null
  }

  private_dns_zone_id = var.private_dns_zone_id

  # --- AAD integration (managed) ---
  # azurerm v4.x
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled      = var.enable_azure_rbac
    admin_group_object_ids  = var.aad_admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"

    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    pod_cidr          = var.pod_cidr

    outbound_type     = "loadBalancer"
    load_balancer_sku = "standard"

    load_balancer_profile {
      managed_outbound_ip_count = local.use_managed_outbound ? var.managed_outbound_ip_count : null
      outbound_ip_address_ids   = local.use_managed_outbound ? null : (
        var.outbound_public_ip_id == null ? null : [var.outbound_public_ip_id]
      )
      outbound_ip_prefix_ids    = local.use_managed_outbound ? null : (
        length(var.outbound_public_ip_prefix_ids) == 0 ? null : var.outbound_public_ip_prefix_ids
      )
    }
  }

  dynamic "oms_agent" {
    for_each = var.law_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.law_workspace_id
    }
  }

  lifecycle {
    ignore_changes = [
      # oms_agent,
      microsoft_defender,
    ]
  }

  tags = var.tags
}
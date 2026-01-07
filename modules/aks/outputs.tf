output "id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "principal_id" {
  description = "System-assigned identity principal ID of the AKS control plane."
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# output "oidc_issuer_url" {
#   description = "AKS OIDC issuer URL (used for workload identity federation)."
#   value       = try(azurerm_kubernetes_cluster.aks.oidc_issuer_url, null)
# }
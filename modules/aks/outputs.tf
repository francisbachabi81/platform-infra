output "id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "principal_id" {
  description = "System-assigned identity principal ID of the AKS control plane."
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
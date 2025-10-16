output "id" {
  value = coalesce(
    try(azurerm_linux_function_app.func_linux[0].id, null),
    try(azurerm_windows_function_app.func_windows[0].id, null)
  )
}

output "name" {
  value = coalesce(
    try(azurerm_linux_function_app.func_linux[0].name, null),
    try(azurerm_windows_function_app.func_windows[0].name, null)
  )
}

output "hostname" {
  value = coalesce(
    try(azurerm_linux_function_app.func_linux[0].default_hostname, null),
    try(azurerm_windows_function_app.func_windows[0].default_hostname, null)
  )
}

output "principal_id" {
  value = coalesce(
    try(azurerm_linux_function_app.func_linux[0].identity[0].principal_id, null),
    try(azurerm_windows_function_app.func_windows[0].identity[0].principal_id, null)
  )
}

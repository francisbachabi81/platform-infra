output "id" {
  description = "Resource ID of the Redis cache."
  value       = azurerm_redis_cache.redis.id
}

output "hostname" {
  description = "Redis cache hostname (non-secret)."
  value       = azurerm_redis_cache.redis.hostname
}

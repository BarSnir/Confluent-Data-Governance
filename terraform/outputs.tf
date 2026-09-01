output "confluent_environment_id" {
  description = "Confluent Cloud environment id."
  value       = confluent_environment.main.id
}

output "confluent_cluster_id" {
  description = "Kafka cluster id."
  value       = confluent_kafka_cluster.main.id
}

output "confluent_bootstrap_servers" {
  description = "Bootstrap server endpoint for client applications."
  value       = confluent_kafka_cluster.main.bootstrap_endpoint
}

output "kafka_api_key" {
  description = "Kafka API key for service clients."
  value       = confluent_api_key.kafka_platform.id
}

output "kafka_api_secret" {
  description = "Kafka API secret for service clients."
  value       = confluent_api_key.kafka_platform.secret
  sensitive   = true
}

output "schema_registry_url" {
  description = "Schema Registry REST endpoint."
  value       = data.confluent_schema_registry_cluster.main.rest_endpoint
}

output "schema_registry_api_key" {
  description = "Schema Registry API key for service clients."
  value       = confluent_api_key.schema_registry_platform.id
}

output "schema_registry_api_secret" {
  description = "Schema Registry API secret for service clients."
  value       = confluent_api_key.schema_registry_platform.secret
  sensitive   = true
}

output "flink_compute_pool_id" {
  description = "Flink compute pool id if enabled."
  value       = var.enable_flink_compute_pool ? confluent_flink_compute_pool.main[0].id : null
}

output "tableflow_table_path" {
  description = "Confluent-managed object-storage path for the Iceberg Tableflow table."
  value       = confluent_tableflow_topic.security_findings.table_path
}

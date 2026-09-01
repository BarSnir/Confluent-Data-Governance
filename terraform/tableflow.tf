resource "confluent_tableflow_topic" "security_findings" {
  display_name  = "security_findings"
  table_formats = ["ICEBERG"]
  retention_ms  = "604800000"

  managed_storage {}

  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  environment {
    id = confluent_environment.main.id
  }

  credentials {
    key    = confluent_api_key.tableflow.id
    secret = confluent_api_key.tableflow.secret
  }

  depends_on = [confluent_flink_statement.risk_prediction]
}
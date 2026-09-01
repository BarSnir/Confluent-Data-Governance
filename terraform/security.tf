resource "confluent_service_account" "platform" {
  display_name = "sa-cyberdemo-platform"
  description  = "Platform service account for Terraform-managed CDC/demo resources."
}

resource "confluent_role_binding" "platform_cluster_admin" {
  principal   = "User:${confluent_service_account.platform.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.main.rbac_crn
}

resource "confluent_role_binding" "platform_environment_admin" {
  principal   = "User:${confluent_service_account.platform.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.main.resource_name
}

resource "confluent_role_binding" "platform_flink_developer" {
  principal   = "User:${confluent_service_account.platform.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_flink_compute_pool.main[0].resource_name
}

resource "confluent_role_binding" "platform_schema_registry_writer" {
  principal   = "User:${confluent_service_account.platform.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.main.resource_name}/subject=*"
}

resource "confluent_role_binding" "platform_catalog_data_steward" {
  principal   = "User:${confluent_service_account.platform.id}"
  role_name   = "DataSteward"
  crn_pattern = confluent_environment.main.resource_name
}

resource "confluent_api_key" "kafka_platform" {
  display_name = "sa-cyberdemo-kafka-key"
  description  = "Kafka API key for Debezium/consumer apps."

  owner {
    id          = confluent_service_account.platform.id
    api_version = confluent_service_account.platform.api_version
    kind        = confluent_service_account.platform.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [confluent_role_binding.platform_cluster_admin]
}

resource "confluent_api_key" "tableflow" {
  display_name = "sa-cyberdemo-tableflow-api-key"
  description  = "Tableflow API key owned by the cyberdemo platform service account."

  owner {
    id          = confluent_service_account.platform.id
    api_version = confluent_service_account.platform.api_version
    kind        = confluent_service_account.platform.kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"
  }

  depends_on = [confluent_role_binding.platform_environment_admin]
}

resource "confluent_api_key" "flink_platform" {
  display_name = "sa-cyberdemo-flink-key"
  description  = "Flink API key for the Terraform-managed security prediction pipeline."

  owner {
    id          = confluent_service_account.platform.id
    api_version = confluent_service_account.platform.api_version
    kind        = confluent_service_account.platform.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.main.id
    api_version = data.confluent_flink_region.main.api_version
    kind        = data.confluent_flink_region.main.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [confluent_role_binding.platform_flink_developer]
}

resource "confluent_api_key" "schema_registry_platform" {
  display_name = "sa-cyberdemo-sr-key"
  description  = "Schema Registry API key for schema management and clients."

  owner {
    id          = confluent_service_account.platform.id
    api_version = confluent_service_account.platform.api_version
    kind        = confluent_service_account.platform.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.main.id
    api_version = data.confluent_schema_registry_cluster.main.api_version
    kind        = data.confluent_schema_registry_cluster.main.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [confluent_role_binding.platform_schema_registry_writer]
}

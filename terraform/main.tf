provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

resource "confluent_environment" "main" {
  display_name = var.environment_name

  stream_governance {
    package = "ADVANCED"
  }
}

resource "confluent_kafka_cluster" "main" {
  display_name = var.kafka_cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  dynamic "basic" {
    for_each = var.kafka_cluster_type == "basic" ? [1] : []
    content {}
  }

  dynamic "standard" {
    for_each = var.kafka_cluster_type == "standard" ? [1] : []
    content {}
  }

  dynamic "dedicated" {
    for_each = var.kafka_cluster_type == "dedicated" ? [1] : []
    content {
      cku = var.dedicated_cku
    }
  }

  environment {
    id = confluent_environment.main.id
  }
}

data "confluent_schema_registry_cluster" "main" {
  environment {
    id = confluent_environment.main.id
  }
}

resource "confluent_flink_compute_pool" "main" {
  count = var.enable_flink_compute_pool ? 1 : 0

  display_name = var.flink_compute_pool_name
  cloud        = var.cloud
  region       = var.region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.main.id
  }
}

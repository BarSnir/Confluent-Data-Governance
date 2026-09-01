variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (Cloud scope)."
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (Cloud scope)."
  type        = string
  sensitive   = true
}

variable "environment_name" {
  description = "Confluent Cloud environment display name."
  type        = string
  default     = "Cybersecurity-Demo"
}

variable "kafka_cluster_name" {
  description = "Kafka cluster display name."
  type        = string
  default     = "cyberdemo-cluster"
}

variable "kafka_cluster_type" {
  description = "Kafka cluster type: basic, standard, dedicated."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["basic", "standard", "dedicated"], var.kafka_cluster_type)
    error_message = "kafka_cluster_type must be one of: basic, standard, dedicated."
  }
}

variable "cloud" {
  description = "Cloud provider for Kafka/Flink resources."
  type        = string
  default     = "AWS"
}

variable "region" {
  description = "Region for Kafka/Flink resources (example: us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "availability" {
  description = "Cluster availability setting."
  type        = string
  default     = "SINGLE_ZONE"
}

variable "dedicated_cku" {
  description = "CKU count when cluster type is dedicated."
  type        = number
  default     = 1
}

variable "enable_flink_compute_pool" {
  description = "Create Flink compute pool resource."
  type        = bool
  default     = true
}

variable "flink_compute_pool_name" {
  description = "Flink compute pool display name."
  type        = string
  default     = "cyberdemo-flink-pool"
}

variable "flink_max_cfu" {
  description = "Max CFU for Flink compute pool."
  type        = number
  default     = 10
}

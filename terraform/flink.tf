data "confluent_organization" "main" {}

data "confluent_flink_region" "main" {
  cloud  = var.cloud
  region = var.region
}

locals {
  flink_rest_endpoint = data.confluent_flink_region.main.rest_endpoint
  flink_catalog       = confluent_environment.main.id
  flink_database      = confluent_kafka_cluster.main.id

  flink_statement_credentials = {
    key    = confluent_api_key.flink_platform.id
    secret = confluent_api_key.flink_platform.secret
  }
}

resource "confluent_flink_statement" "risk_prediction" {
  statement_name = "cyberdemo-ml-risk-prediction"
  rest_endpoint  = local.flink_rest_endpoint
  statement      = <<-SQL
    INSERT INTO `${local.flink_catalog}`.`${local.flink_database}`.security_findings (
      key, tenant_id, asset_id, device_type, ip_address, cve_id, cvss_score, severity,
      anomaly_score, finding_type, predicted_risk, model_version, event_time
    )
    WITH risk_features AS (
      SELECT
        a.tenant_id, a.asset_id, a.device_type, a.is_quarantined, n.ip_address,
        c.cve_id, c.cvss_score, c.severity, c.discovered_at,
        ML_DETECT_ANOMALIES(
          c.cvss_score,
          CAST(c.discovered_at AS TIMESTAMP(3)),
          JSON_OBJECT(
            'minTrainingSize' VALUE 10,
            'maxTrainingSize' VALUE 100,
            'enableStl' VALUE FALSE
          )
        ) OVER (
          PARTITION BY a.tenant_id
          ORDER BY CAST(c.discovered_at AS TIMESTAMP(3))
          RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS anomaly
      FROM `${local.flink_catalog}`.`${local.flink_database}`.assets AS a
      JOIN `${local.flink_catalog}`.`${local.flink_database}`.network_interfaces AS n ON a.tenant_id = n.tenant_id AND a.asset_id = n.asset_id
      JOIN `${local.flink_catalog}`.`${local.flink_database}`.asset_cves AS c ON a.tenant_id = c.tenant_id AND a.asset_id = c.asset_id
      WHERE n.is_active = TRUE
    )
    SELECT
      CAST(CONCAT(tenant_id, '|', asset_id, '|', cve_id) AS BYTES),
      tenant_id, asset_id, device_type, ip_address, cve_id, cvss_score, severity,
      CAST(CASE
        WHEN COALESCE(anomaly.is_anomaly, FALSE) THEN 0.99
        ELSE cvss_score / 10.0
      END AS DOUBLE),
      'ML_ANOMALY_RISK_PREDICTION',
      CASE
        WHEN COALESCE(anomaly.is_anomaly, FALSE) AND cvss_score >= 7.0 THEN 'CRITICAL'
        WHEN COALESCE(anomaly.is_anomaly, FALSE) OR cvss_score >= 7.0 THEN 'HIGH'
        WHEN cvss_score >= 4.0 THEN 'MEDIUM'
        ELSE 'LOW'
      END,
      'arima-anomaly-v1',
      CAST(discovered_at AS STRING)
    FROM risk_features
  SQL

  organization { id = data.confluent_organization.main.id }
  environment { id = confluent_environment.main.id }
  compute_pool { id = confluent_flink_compute_pool.main[0].id }
  principal { id = confluent_service_account.platform.id }
  credentials {
    key    = local.flink_statement_credentials.key
    secret = local.flink_statement_credentials.secret
  }

  depends_on = [
    confluent_flink_statement.assets_latest_offset,
    confluent_flink_statement.network_interfaces_latest_offset,
    confluent_flink_statement.asset_cves_latest_offset,
    confluent_flink_statement.security_findings_upsert,
  ]
}

resource "confluent_flink_statement" "assets_latest_offset" {
  statement_name = "cyberdemo-assets-earliest-offset"
  rest_endpoint  = local.flink_rest_endpoint
  statement      = "ALTER TABLE `${local.flink_catalog}`.`${local.flink_database}`.assets SET ('scan.startup.mode' = 'earliest-offset', 'error-handling.mode' = 'ignore')"

  organization { id = data.confluent_organization.main.id }
  environment { id = confluent_environment.main.id }
  compute_pool { id = confluent_flink_compute_pool.main[0].id }
  principal { id = confluent_service_account.platform.id }
  credentials {
    key    = local.flink_statement_credentials.key
    secret = local.flink_statement_credentials.secret
  }

  depends_on = [confluent_role_binding.platform_flink_developer]
}

resource "confluent_flink_statement" "network_interfaces_latest_offset" {
  statement_name = "cyberdemo-network-interfaces-earliest-offset"
  rest_endpoint  = local.flink_rest_endpoint
  statement      = "ALTER TABLE `${local.flink_catalog}`.`${local.flink_database}`.network_interfaces SET ('scan.startup.mode' = 'earliest-offset', 'error-handling.mode' = 'ignore')"

  organization { id = data.confluent_organization.main.id }
  environment { id = confluent_environment.main.id }
  compute_pool { id = confluent_flink_compute_pool.main[0].id }
  principal { id = confluent_service_account.platform.id }
  credentials {
    key    = local.flink_statement_credentials.key
    secret = local.flink_statement_credentials.secret
  }

  depends_on = [confluent_role_binding.platform_flink_developer]
}

resource "confluent_flink_statement" "asset_cves_latest_offset" {
  statement_name = "cyberdemo-asset-cves-earliest-offset"
  rest_endpoint  = local.flink_rest_endpoint
  statement      = "ALTER TABLE `${local.flink_catalog}`.`${local.flink_database}`.asset_cves SET ('scan.startup.mode' = 'earliest-offset', 'error-handling.mode' = 'ignore')"

  organization { id = data.confluent_organization.main.id }
  environment { id = confluent_environment.main.id }
  compute_pool { id = confluent_flink_compute_pool.main[0].id }
  principal { id = confluent_service_account.platform.id }
  credentials {
    key    = local.flink_statement_credentials.key
    secret = local.flink_statement_credentials.secret
  }

  depends_on = [confluent_role_binding.platform_flink_developer]
}

resource "confluent_flink_statement" "security_findings_upsert" {
  statement_name = "cyberdemo-security-findings-upsert-mode"
  rest_endpoint  = local.flink_rest_endpoint
  statement      = "ALTER TABLE `${local.flink_catalog}`.`${local.flink_database}`.security_findings SET ('changelog.mode' = 'upsert')"

  organization { id = data.confluent_organization.main.id }
  environment { id = confluent_environment.main.id }
  compute_pool { id = confluent_flink_compute_pool.main[0].id }
  principal { id = confluent_service_account.platform.id }
  credentials {
    key    = local.flink_statement_credentials.key
    secret = local.flink_statement_credentials.secret
  }

  depends_on = [confluent_role_binding.platform_flink_developer]
}
-- Built-in ARIMA ML anomaly detection; no external AI provider or model is required.
-- Apply flink/ddl/topics.sql before this persistent INSERT statement.
INSERT INTO security_findings (
  key,
  tenant_id,
  asset_id,
  device_type,
  ip_address,
  cve_id,
  cvss_score,
  severity,
  anomaly_score,
  finding_type,
  predicted_risk,
  model_version,
  event_time
)
WITH risk_features AS (
  SELECT
    a.tenant_id, a.asset_id, a.device_type, n.ip_address,
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
  FROM assets AS a
  JOIN network_interfaces AS n
    ON a.tenant_id = n.tenant_id
   AND a.asset_id = n.asset_id
  JOIN asset_cves AS c
    ON a.tenant_id = c.tenant_id
   AND a.asset_id = c.asset_id
  WHERE n.is_active = TRUE
)
SELECT
  CAST(CONCAT(tenant_id, '|', asset_id, '|', cve_id) AS BYTES) AS key,
  tenant_id, asset_id, device_type, ip_address, cve_id, cvss_score, severity,
  CAST(CASE WHEN COALESCE(anomaly.is_anomaly, FALSE) THEN 0.99 ELSE cvss_score / 10.0 END AS DOUBLE) AS anomaly_score,
  'ML_ANOMALY_RISK_PREDICTION' AS finding_type,
  CASE
    WHEN COALESCE(anomaly.is_anomaly, FALSE) AND cvss_score >= 7.0 THEN 'CRITICAL'
    WHEN COALESCE(anomaly.is_anomaly, FALSE) OR cvss_score >= 7.0 THEN 'HIGH'
    WHEN cvss_score >= 4.0 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS predicted_risk,
  'arima-anomaly-v1' AS model_version,
  CAST(discovered_at AS STRING) AS event_time
FROM risk_features;

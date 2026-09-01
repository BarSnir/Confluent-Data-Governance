-- Deterministic detection rule for demo reliability.
SELECT
  a.tenant_id,
  a.asset_id,
  a.device_type,
  n.ip_address,
  c.cve_id,
  c.cvss_score,
  c.severity,
  0.94 AS anomaly_score,
  'VULNERABLE_ACTIVE_DEVICE' AS finding_type,
  'CRITICAL' AS predicted_risk,
  'demo-ml-v1' AS model_version,
  CURRENT_TIMESTAMP AS event_time
FROM assets a
JOIN network_interfaces n
  ON a.tenant_id = n.tenant_id
 AND a.asset_id = n.asset_id
JOIN asset_cves c
  ON a.tenant_id = c.tenant_id
 AND a.asset_id = c.asset_id
WHERE a.risk_level = 'HIGH'
  AND n.is_active = TRUE
  AND c.cvss_score >= 9.0
  AND c.severity = 'CRITICAL';

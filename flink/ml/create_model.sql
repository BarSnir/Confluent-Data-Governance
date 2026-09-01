

-- Feature engineering for the deterministic security-risk prediction demo.
-- No external AI provider, connection, or API key is required.
-- Apply flink/ddl/topics.sql before creating this view.
CREATE VIEW risk_prediction_features AS
SELECT
  a.tenant_id,
  a.asset_id,
  a.device_type,
  a.risk_level AS asset_risk_level,
  a.is_quarantined,
  n.ip_address,
  n.is_active,
  c.cve_id,
  c.cvss_score,
  c.severity,
  CASE
    WHEN c.cvss_score >= 9.0 AND n.is_active AND NOT a.is_quarantined THEN 'CRITICAL'
    WHEN c.cvss_score >= 7.0 OR UPPER(c.severity) = 'HIGH' THEN 'HIGH'
    WHEN c.cvss_score >= 4.0 OR UPPER(c.severity) = 'MEDIUM' THEN 'MEDIUM'
    ELSE 'LOW'
  END AS predicted_risk
FROM assets AS a
JOIN network_interfaces AS n
  ON a.tenant_id = n.tenant_id
 AND a.asset_id = n.asset_id
JOIN asset_cves AS c
  ON a.tenant_id = c.tenant_id
 AND a.asset_id = c.asset_id
WHERE n.is_active = TRUE;

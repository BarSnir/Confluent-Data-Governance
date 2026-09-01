-- Enrichment join example.
SELECT
  a.tenant_id,
  a.asset_id,
  a.device_type,
  n.ip_address,
  c.cve_id,
  c.cvss_score,
  c.severity,
  CASE
    WHEN c.cvss_score >= 9.0 THEN 0.94
    WHEN c.cvss_score >= 7.0 THEN 0.82
    ELSE 0.31
  END AS anomaly_score,
  CURRENT_TIMESTAMP AS event_time
FROM assets a
JOIN network_interfaces n
  ON a.tenant_id = n.tenant_id
 AND a.asset_id = n.asset_id
JOIN asset_cves c
  ON a.tenant_id = c.tenant_id
 AND a.asset_id = c.asset_id;

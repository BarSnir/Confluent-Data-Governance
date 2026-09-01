-- Demo aggregations.
SELECT tenant_id, COUNT(*) AS critical_cves
FROM asset_cves
WHERE severity = 'CRITICAL'
GROUP BY tenant_id;

SELECT tenant_id, COUNT(*) AS high_risk_assets
FROM assets
WHERE risk_level = 'HIGH'
GROUP BY tenant_id;

SELECT tenant_id, AVG(cvss_score) AS avg_cvss
FROM asset_cves
GROUP BY tenant_id;

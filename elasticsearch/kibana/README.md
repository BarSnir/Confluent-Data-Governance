# Kibana Dashboard

Load dashboard assets from `security-dashboard.ndjson`.

## Import

Run the following after Kibana is available:

```bash
jq -s . elasticsearch/kibana/security-dashboard.ndjson | \
	curl -fsS -X POST \
		-H 'kbn-xsrf: true' \
		-H 'Content-Type: application/json' \
		'http://localhost:5601/api/saved_objects/_bulk_create?overwrite=true' \
		--data-binary @-
```

Open the dashboard at http://localhost:5601/app/dashboards#/view/security-findings-dashboard.

## BI Dashboard

After running the Spark job, load `security-bi-dashboard.ndjson` with the same command above and replace the file name. Open the BI dashboard at http://localhost:5601/app/dashboards#/view/security-findings-bi-dashboard.

The BI dashboard reads `security-findings-bi*`, which is produced by `spark/read_tableflow.py` from 10-minute Tableflow aggregates.

## Expected Visuals

- Total Security Findings
- Critical Findings
- Findings by Tenant
- Findings by Severity
- Top CVEs
- Average CVSS
- Average Anomaly Score
- Findings Over Time
- Most Vulnerable Device Types

The current dashboard includes total findings, critical findings, severity distribution, and predicted-risk distribution. Its time range is the last 24 hours and it refreshes every 10 seconds.

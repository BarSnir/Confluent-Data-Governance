# Confluent Cybersecurity Data Governance Demo
PostgreSQL CDC flows through Debezium and Confluent Cloud Kafka, then Flink ML anomaly detection, Elasticsearch/Kibana, and Tableflow Iceberg for Spark BI. All data is synthetic.

## Start

Requires Docker Desktop, Terraform, `jq`, `curl`, and Confluent Cloud management credentials.

```bash
cp .env.example .env
./scripts/up.sh "<cloud-api-key>" "<cloud-api-secret>"
```
`up.sh` provisions Confluent resources, enables Tableflow, applies catalog tags/data contracts, starts CDC, and loads both Kibana dashboards.

## Architecture
```text
PostgreSQL -> Debezium Protobuf -> Confluent Kafka -> Flink ML -> security_findings
                                                            |-> Elasticsearch -> Kibana
                                                            |-> Elasticsearch BI aggregator -> Kibana BI
                                                            |-> Tableflow Iceberg -> Spark analysis
```

## Dashboards
- Security findings: http://localhost:5601/app/dashboards#/view/security-findings-dashboard
- BI 10-minute aggregates: http://localhost:5601/app/dashboards#/view/security-findings-bi-dashboard

## Spark BI
Set `TABLEFLOW_TABLE_NAME` to the fully-qualified Iceberg table shown by Tableflow, then run:

```bash
source .env
spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:<iceberg-version> spark/read_tableflow.py
```

`up.sh` keeps `security-findings-bi` populated every 30 seconds; the Spark job remains available for direct Tableflow analysis.

## Verify
```bash
docker compose ps
curl -fsS http://localhost:9200/security-findings/_count | jq
curl -fsS http://localhost:8083/connectors/pg-cyber-cdc/status | jq
```

## Teardown
```bash
./scripts/teardown.sh "<cloud-api-key>" "<cloud-api-secret>"
# Non-interactive: ./scripts/teardown.sh --yes "<cloud-api-key>" "<cloud-api-secret>"
```

This removes Docker containers and volumes, then destroys all Terraform-managed Confluent resources, including API keys and Tableflow storage.

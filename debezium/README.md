# Debezium Connector

This folder contains a reproducible PostgreSQL Debezium connector configuration for Confluent Cloud.

## Start Connect

The Kafka Connect worker runs in Docker via [docker-compose.yml](../docker-compose.yml).

## Register Connector

After Connect is healthy:

```bash
./debezium/register_connector.sh
```

The script loads variables from `.env`, renders `debezium/connector.json` via `envsubst`, and then creates or updates connector `pg-cyber-cdc`.

## Verify Connector Status

```bash
curl -s http://localhost:8083/connectors/pg-cyber-cdc/status | jq
```

## Notes

- The worker is configured to use Confluent Cloud Kafka and Schema Registry from environment variables.
- Topic routing maps Debezium default names to: `assets`, `network_interfaces`, `asset_cves`.
- Protobuf converters are installed in the custom Debezium image.
- Required local tools for the script: `jq`, `curl`, `perl`.
- `envsubst` is optional; if missing, the script uses a built-in `perl` fallback to render env vars.

#!/usr/bin/env bash
set -euo pipefail

# Script to create Kafka topics in Confluent Cloud via REST API

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

# Extract host from CONFLUENT_BOOTSTRAP_SERVERS
BOOTSTRAP_SERVERS="${CONFLUENT_BOOTSTRAP_SERVERS#SASL_SSL://}"
BOOTSTRAP_HOST="${BOOTSTRAP_SERVERS%:*}"
REST_ENDPOINT="https://${BOOTSTRAP_HOST}:443"

# Topics to create
TOPICS=("assets" "network_interfaces" "asset_cves" "security_findings")

echo "Creating topics in Confluent Cloud..."
echo "REST Endpoint: $REST_ENDPOINT"
echo ""

for topic in "${TOPICS[@]}"; do
  echo "Creating topic: $topic"

  TOPIC_JSON=$(cat <<EOF
{
  "topic_name": "$topic",
  "partitions_count": 6,
  "replication_factor": 3
}
EOF
)

  curl -s -X POST \
    -u "${CONFLUENT_KAFKA_API_KEY}:${CONFLUENT_KAFKA_API_SECRET}" \
    "${REST_ENDPOINT}/kafka/v3/clusters/${CONFLUENT_CLUSTER_ID}/topics" \
    -H "Content-Type: application/json" \
    -d "$TOPIC_JSON" \
    -w "\nHTTP Status: %{http_code}\n" || echo "Warning: Failed to create $topic (may already exist)"

  echo ""
done

echo "Topic creation complete."

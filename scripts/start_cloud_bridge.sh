#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env file. Create one from .env.example first."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_cloud_vars=(
  CONFLUENT_BOOTSTRAP_SERVERS
  CONFLUENT_KAFKA_API_KEY
  CONFLUENT_KAFKA_API_SECRET
)

for var_name in "${required_cloud_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required Confluent Cloud variable: $var_name"
    echo "Fill it in .env and run again."
    exit 1
  fi
done

if [[ -n "${TF_VAR_confluent_cloud_api_key:-}" && -n "${TF_VAR_confluent_cloud_api_secret:-}" ]]; then
  echo "Terraform cloud credentials detected in .env."
fi

if [[ -z "${SCHEMA_REGISTRY_URL:-}" ]]; then
  echo "Warning: SCHEMA_REGISTRY_URL is empty."
  echo "This is acceptable for local JSON CDC profile, but required for strict Protobuf profile."
fi

echo "Starting Debezium and consumer containers..."
( cd "$ROOT_DIR" && docker compose up -d debezium consumer )

echo "Waiting for Debezium REST API..."
until curl -fsS http://localhost:8083/connectors >/dev/null 2>&1; do
  sleep 2
done

echo "Registering connector..."
"$ROOT_DIR/debezium/register_connector.sh"

echo "Cloud bridge started successfully."

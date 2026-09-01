#!/usr/bin/env bash
set -euo pipefail

# Registers the Flink output schema. Debezium auto-registers its CDC schemas.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

echo "Registering security_findings Protobuf schema..."

# Function to register a schema
register_schema() {
  local subject=$1
  local schema_file=$2

  echo "Registering subject: $subject"

  # Read schema and convert to JSON string
  local schema_content=$(cat "$schema_file")

  # Create JSON payload with escaped schema
  local json_payload=$(cat <<EOF
{
  "schema": $(echo "$schema_content" | jq -Rs '.'),
  "schemaType": "PROTOBUF"
}
EOF
)

  # Register schema
  curl -fsS -X POST \
    -u "${SCHEMA_REGISTRY_API_KEY}:${SCHEMA_REGISTRY_API_SECRET}" \
    "${SCHEMA_REGISTRY_URL}/subjects/${subject}/versions" \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    -d "$json_payload" | jq
}

# This topic is produced by Flink, so it needs a schema before the first INSERT.
register_schema "security_findings-value" "$ROOT_DIR/schemas/security_findings.proto"

echo "security_findings schema registration complete."

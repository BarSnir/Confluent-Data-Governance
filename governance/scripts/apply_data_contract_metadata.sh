#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
METADATA_DIR="$ROOT_DIR/governance/metadata"
SCHEMAS_DIR="$ROOT_DIR/schemas"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env file. Create one from .env.example first."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

for command in curl jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command"
    exit 1
  fi
done

for variable in SCHEMA_REGISTRY_URL SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Required variable is empty: $variable"
    exit 1
  fi
done

auth=(--user "$SCHEMA_REGISTRY_API_KEY:$SCHEMA_REGISTRY_API_SECRET")

latest_schema() {
  local subject="$1"
  curl --fail --silent --show-error "${auth[@]}" \
    "$SCHEMA_REGISTRY_URL/subjects/$subject/versions/latest"
}

apply_data_contract_metadata() {
  local metadata_file="$1"
  local topic subject schema_response schema schema_type references properties payload

  topic="$(jq -r '.topic' "$metadata_file")"
  subject="${topic}-value"
  properties="$(jq -c '{owner, description, company, domain, environment, data_type, classification, source_system: .labels.source, retention_policy: .labels.retention}' "$metadata_file")"

  if schema_response="$(latest_schema "$subject" 2>/dev/null)"; then
    schema="$(jq -r '.schema' <<<"$schema_response")"
    schema_type="$(jq -r '.schemaType // "PROTOBUF"' <<<"$schema_response")"
    references="$(jq -c '.references // []' <<<"$schema_response")"
  else
    schema="$SCHEMAS_DIR/${topic}.proto"
    if [[ ! -f "$schema" ]]; then
      echo "No registered schema or local Protobuf file for $topic."
      exit 1
    fi
    schema="$(cat "$schema")"
    schema_type="PROTOBUF"
    references="[]"
  fi

  payload="$(jq -n \
    --arg schema "$schema" \
    --arg schema_type "$schema_type" \
    --argjson references "$references" \
    --argjson properties "$properties" \
    '{schema: $schema, schemaType: $schema_type, references: $references, metadata: {properties: $properties}}')"

  curl --fail-with-body --silent --show-error --request POST "${auth[@]}" \
    --header "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "$payload" "$SCHEMA_REGISTRY_URL/subjects/$subject/versions" \
    | jq '{subject, version, id, metadata}'
  echo "Applied data-contract metadata: $subject"
}

for metadata_file in "$METADATA_DIR"/*.metadata.json; do
  apply_data_contract_metadata "$metadata_file"
done
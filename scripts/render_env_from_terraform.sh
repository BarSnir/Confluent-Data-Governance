#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -d "$TF_DIR" ]]; then
  echo "Terraform directory not found: $TF_DIR"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
fi

set_env() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for parsing terraform outputs. Install jq and retry."
    exit 1
  fi
}

get_required_output() {
  local json="$1"
  local name="$2"
  local value
  value="$(jq -r --arg n "$name" '.[$n].value // empty' <<< "$json")"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "Missing required terraform output: $name"
    echo "Run: cd terraform && terraform apply"
    exit 1
  fi
  printf '%s' "$value"
}

get_optional_output() {
  local json="$1"
  local name="$2"
  jq -r --arg n "$name" '.[$n].value // empty' <<< "$json"
}

pushd "$TF_DIR" >/dev/null

require_jq
outputs_json="$(terraform output -json)"

bootstrap_servers="$(get_required_output "$outputs_json" "confluent_bootstrap_servers")"
kafka_key="$(get_required_output "$outputs_json" "kafka_api_key")"
kafka_secret="$(get_required_output "$outputs_json" "kafka_api_secret")"
env_id="$(get_required_output "$outputs_json" "confluent_environment_id")"
cluster_id="$(get_required_output "$outputs_json" "confluent_cluster_id")"

sr_url="$(get_optional_output "$outputs_json" "schema_registry_url")"
sr_key="$(get_optional_output "$outputs_json" "schema_registry_api_key")"
sr_secret="$(get_optional_output "$outputs_json" "schema_registry_api_secret")"
tableflow_path="$(get_optional_output "$outputs_json" "tableflow_table_path")"

popd >/dev/null

set_env "CONFLUENT_BOOTSTRAP_SERVERS" "$bootstrap_servers"
set_env "CONFLUENT_KAFKA_API_KEY" "$kafka_key"
set_env "CONFLUENT_KAFKA_API_SECRET" "$kafka_secret"
if [[ -n "$sr_url" && -n "$sr_key" && -n "$sr_secret" ]]; then
  set_env "SCHEMA_REGISTRY_URL" "$sr_url"
  set_env "SCHEMA_REGISTRY_API_KEY" "$sr_key"
  set_env "SCHEMA_REGISTRY_API_SECRET" "$sr_secret"
else
  echo "Warning: Schema Registry outputs are missing in terraform state."
  echo "If you recently added outputs/resources, run: cd terraform && terraform apply"
fi
set_env "CONFLUENT_ENVIRONMENT_ID" "$env_id"
set_env "CONFLUENT_CLUSTER_ID" "$cluster_id"
set_env "TABLEFLOW_BUCKET_URI" "$tableflow_path"

rm -f "$ENV_FILE.bak"

echo "Updated $ENV_FILE from Terraform outputs."

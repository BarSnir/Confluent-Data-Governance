#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

require_command docker
require_command jq
require_command terraform

if (( $# != 2 )); then
  echo "Usage: $0 <confluent-cloud-api-key> <confluent-cloud-api-secret>"
  exit 1
fi

export TF_VAR_confluent_cloud_api_key="$1"
export TF_VAR_confluent_cloud_api_secret="$2"

wait_for_cdc_schemas() {
  local attempts=0
  local subject
  local cloud_api_key="$TF_VAR_confluent_cloud_api_key"
  local cloud_api_secret="$TF_VAR_confluent_cloud_api_secret"
  local -a subjects=(assets-value network_interfaces-value asset_cves-value)

  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
  export TF_VAR_confluent_cloud_api_key="$cloud_api_key"
  export TF_VAR_confluent_cloud_api_secret="$cloud_api_secret"

  while (( attempts < 45 )); do
    local all_ready=true
    for subject in "${subjects[@]}"; do
      if ! curl -fsS -u "$SCHEMA_REGISTRY_API_KEY:$SCHEMA_REGISTRY_API_SECRET" \
        "$SCHEMA_REGISTRY_URL/subjects/$subject/versions/latest" >/dev/null 2>&1; then
        all_ready=false
        break
      fi
    done
    if [[ "$all_ready" == true ]]; then
      return
    fi
    attempts=$((attempts + 1))
    sleep 2
  done

  echo "CDC schemas were not registered within 90 seconds. Check: docker compose logs debezium"
  exit 1
}

wait_for_kibana() {
  local attempts=0

  while (( attempts < 45 )); do
    if curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; then
      return
    fi
    attempts=$((attempts + 1))
    sleep 2
  done

  echo "Kibana did not become ready within 90 seconds. Check: docker compose logs kibana"
  exit 1
}

cd "$ROOT_DIR"
./scripts/terraform_clean.sh init
./scripts/terraform_clean.sh apply -auto-approve \
  -target=confluent_api_key.kafka_platform \
  -target=confluent_api_key.flink_platform \
  -target=confluent_api_key.schema_registry_platform \
  -target=confluent_api_key.tableflow
./scripts/render_env_from_terraform.sh
./scripts/register_schemas.sh
./scripts/create_topics.sh

docker compose up -d --build
./debezium/register_connector.sh
wait_for_cdc_schemas

./scripts/terraform_clean.sh apply -auto-approve
./scripts/render_env_from_terraform.sh
./governance/scripts/apply_stream_catalog.sh
./governance/scripts/apply_data_contract_metadata.sh
wait_for_kibana

for dashboard in elasticsearch/kibana/security-dashboard.ndjson elasticsearch/kibana/security-bi-dashboard.ndjson; do
  jq -s . "$dashboard" | curl -fsS -X POST \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' \
    'http://localhost:5601/api/saved_objects/_bulk_create?overwrite=true' \
    --data-binary @- >/dev/null
done

docker compose ps
echo "Kibana: http://localhost:5601/app/dashboards#/view/security-findings-dashboard"
echo "BI:     http://localhost:5601/app/dashboards#/view/security-findings-bi-dashboard"
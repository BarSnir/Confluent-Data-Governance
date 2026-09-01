#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECT_WAIT_SECONDS="${CONNECT_WAIT_SECONDS:-90}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

render_template() {
  local input_file="$1"
  local output_file="$2"

  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$input_file" > "$output_file"
    return
  fi

  # Fallback for systems without envsubst (for example macOS without gettext).
  perl -pe 's/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/$ENV{$1}/ge' "$input_file" > "$output_file"
}

wait_for_connect() {
  local elapsed=0
  local step=2

  echo "Waiting for Kafka Connect at $CONNECT_URL ..."
  until curl -fsS "$CONNECT_URL/connectors" >/dev/null 2>&1; do
    sleep "$step"
    elapsed=$((elapsed + step))
    if (( elapsed >= CONNECT_WAIT_SECONDS )); then
      echo "Kafka Connect did not become ready within ${CONNECT_WAIT_SECONDS}s"
      exit 1
    fi
  done
}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env file. Create one from .env.example first."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_cmd curl
require_cmd jq
require_cmd perl

required_vars=(
  POSTGRES_HOST
  POSTGRES_PORT
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  DEBEZIUM_SLOT_NAME
  DEBEZIUM_PUBLICATION_NAME
  DEBEZIUM_TOPIC_PREFIX
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Required variable is empty: $var_name"
    exit 1
  fi
done

tmp_file="$(mktemp)"
render_template "$ROOT_DIR/debezium/connector.json" "$tmp_file"

wait_for_connect

if curl -fsS "$CONNECT_URL/connectors/pg-cyber-cdc" >/dev/null 2>&1; then
  echo "Updating existing connector pg-cyber-cdc"
  curl -fsS -X PUT "$CONNECT_URL/connectors/pg-cyber-cdc/config" \
    -H "Content-Type: application/json" \
    -d "$(jq -c '.config' "$tmp_file")" | jq
else
  echo "Creating connector pg-cyber-cdc"
  curl -fsS -X POST "$CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d @"$tmp_file" | jq
fi

rm -f "$tmp_file"

echo "Connector registration complete."

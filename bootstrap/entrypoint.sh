#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/workspace"

echo "[BOOTSTRAP] starting post-compose bootstrap"

if [[ -n "${TF_VAR_confluent_cloud_api_key:-}" && -n "${TF_VAR_confluent_cloud_api_secret:-}" ]]; then
  echo "[BOOTSTRAP] Terraform credentials found, applying Confluent resources"
  terraform -chdir="$ROOT_DIR/terraform" init
  terraform -chdir="$ROOT_DIR/terraform" apply -auto-approve

  echo "[BOOTSTRAP] Rendering Terraform outputs into .env"
  "$ROOT_DIR/scripts/render_env_from_terraform.sh"
else
  echo "[BOOTSTRAP] Terraform credentials are missing. Skipping terraform apply."
  echo "[BOOTSTRAP] Set TF_VAR_confluent_cloud_api_key and TF_VAR_confluent_cloud_api_secret in .env to enable auto apply."
fi

echo "[BOOTSTRAP] Registering Debezium connector"
"$ROOT_DIR/debezium/register_connector.sh"

echo "[BOOTSTRAP] done"

#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_confluent_cloud_api_key:?Set TF_VAR_confluent_cloud_api_key before running Terraform.}"
: "${TF_VAR_confluent_cloud_api_secret:?Set TF_VAR_confluent_cloud_api_secret before running Terraform.}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec env -i \
  PATH="$PATH" \
  HOME="$HOME" \
  TF_VAR_confluent_cloud_api_key="$TF_VAR_confluent_cloud_api_key" \
  TF_VAR_confluent_cloud_api_secret="$TF_VAR_confluent_cloud_api_secret" \
  terraform -chdir="$ROOT_DIR/terraform" "$@"
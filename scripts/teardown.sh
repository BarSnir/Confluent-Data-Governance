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
require_command terraform

skip_confirmation=false
if [[ "${1:-}" == "--yes" ]]; then
  skip_confirmation=true
  shift
fi

if (( $# != 2 )); then
  echo "Usage: $0 [--yes] <confluent-cloud-api-key> <confluent-cloud-api-secret>"
  exit 1
fi

export TF_VAR_confluent_cloud_api_key="$1"
export TF_VAR_confluent_cloud_api_secret="$2"

if [[ "$skip_confirmation" == false ]]; then
  echo "This destroys local Docker data and all Terraform-managed Confluent resources."
  read -r -p "Type DESTROY to continue: " confirmation
  if [[ "$confirmation" != "DESTROY" ]]; then
    echo "Teardown cancelled."
    exit 0
  fi
fi

cd "$ROOT_DIR"
./scripts/terraform_clean.sh plan -destroy -refresh=false -input=false >/dev/null
docker compose down --volumes --remove-orphans
./scripts/terraform_clean.sh destroy -auto-approve
echo "Teardown complete."
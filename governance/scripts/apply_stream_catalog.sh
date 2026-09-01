#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
TAG_DEFINITIONS_FILE="$ROOT_DIR/governance/tags/tag-definitions.json"
BUSINESS_METADATA_FILE="$ROOT_DIR/governance/business-metadata-definition.json"
METADATA_DIR="$ROOT_DIR/governance/metadata"

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

catalog_url="$SCHEMA_REGISTRY_URL/catalog/v1"
catalog_api_key="${CATALOG_API_KEY:-$SCHEMA_REGISTRY_API_KEY}"
catalog_api_secret="${CATALOG_API_SECRET:-$SCHEMA_REGISTRY_API_SECRET}"
auth=(--user "$catalog_api_key:$catalog_api_secret")

request() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  if [[ -n "$data" ]]; then
    curl --fail-with-body --silent --show-error --request "$method" "$url" \
      "${auth[@]}" --header "Content-Type: application/json" --data "$data" || {
        echo "Catalog API request failed. Use an API key for a principal with Stream Catalog write access."
        exit 1
      }
  else
    curl --fail-with-body --silent --show-error --request "$method" "$url" "${auth[@]}" || {
      echo "Catalog API request failed. Use an API key for a principal with Stream Catalog read access."
      exit 1
    }
  fi
}

ensure_tag_definitions() {
  local current_tags tag_definition tag_name
  current_tags="$(request GET "$catalog_url/types/tagdefs")"

  while IFS= read -r tag_definition; do
    tag_name="$(jq -r '.name' <<<"$tag_definition")"
    if jq -e --arg name "$tag_name" '.[] | select(.name == $name)' <<<"$current_tags" >/dev/null; then
      echo "Tag definition exists: $tag_name"
    else
      request POST "$catalog_url/types/tagdefs" "[$tag_definition]" >/dev/null
      echo "Created tag definition: $tag_name"
    fi
  done < <(jq -c '.[]' "$TAG_DEFINITIONS_FILE")
}

ensure_business_metadata_definition() {
  local definitions metadata_name
  definitions="$(request GET "$catalog_url/types/businessmetadatadefs")"
  metadata_name="$(jq -r '.[0].name' "$BUSINESS_METADATA_FILE")"

  if jq -e --arg name "$metadata_name" '.[] | select(.name == $name)' <<<"$definitions" >/dev/null; then
    echo "Business metadata definition exists: $metadata_name"
  else
    request POST "$catalog_url/types/businessmetadatadefs" "$(cat "$BUSINESS_METADATA_FILE")" >/dev/null
    echo "Created business metadata definition: $metadata_name"
  fi
}

qualified_topic_name() {
  local topic="$1"
  local result
  result="$(request GET "$catalog_url/search/basic?types=kafka_topic&query=$topic")"
  jq -er --arg topic "$topic" '.entities[] | select(.attributes.name == $topic) | .attributes.qualifiedName' <<<"$result" | head -n 1
}

apply_topic_metadata() {
  local metadata_file="$1"
  local topic qualified_name description owner tags existing_tags business_metadata existing_metadata method
  topic="$(jq -r '.topic' "$metadata_file")"
  qualified_name="$(qualified_topic_name "$topic")"
  description="$(jq -r '.description' "$metadata_file")"
  owner="$(jq -r '.owner' "$metadata_file")"

  request PUT "$catalog_url/entity" "$(jq -n \
    --arg qualified_name "$qualified_name" \
    --arg description "$description" \
    --arg owner "$owner" \
    '{entity: {typeName: "kafka_topic", attributes: {qualifiedName: $qualified_name, description: $description, owner: $owner}}}')" >/dev/null

  tags="$(jq -c --arg classification "$(jq -r '.classification' "$metadata_file")" \
    '["CDC", $classification] + (.tags | map(gsub("[^A-Za-z0-9_]"; ""))) | unique' "$metadata_file")"
  existing_tags="$(request GET "$catalog_url/entity/type/kafka_topic/name/$qualified_name/tags")"
  while IFS= read -r tag_name; do
    if jq -e --arg tag_name "$tag_name" '.. | objects | select(.typeName? == $tag_name)' <<<"$existing_tags" >/dev/null; then
      echo "Tag already applied: $topic/$tag_name"
    else
      request POST "$catalog_url/entity/tags" "$(jq -n \
        --arg qualified_name "$qualified_name" \
        --arg tag_name "$tag_name" \
        '[{entityType: "kafka_topic", entityName: $qualified_name, typeName: $tag_name}]')" >/dev/null
    fi
  done < <(jq -r '.[]' <<<"$tags")

  business_metadata="$(jq -c '{entityType: "kafka_topic", typeName: "CybersecurityDataProduct", attributes: {company, domain, environment, data_type, classification, source_system: .labels.source, retention_policy: .labels.retention}}' "$metadata_file" | jq --arg qualified_name "$qualified_name" '. + {entityName: $qualified_name}')"
  existing_metadata="$(request GET "$catalog_url/entity/type/kafka_topic/name/$qualified_name/businessmetadata")"
  method="POST"
  if jq -e 'type == "object" or (type == "array" and length > 0)' <<<"$existing_metadata" >/dev/null; then
    method="PUT"
  fi
  request "$method" "$catalog_url/entity/businessmetadata" "[$business_metadata]" >/dev/null

  echo "Applied Stream Catalog metadata: $topic"
}

ensure_tag_definitions
ensure_business_metadata_definition

for metadata_file in "$METADATA_DIR"/*.metadata.json; do
  apply_topic_metadata "$metadata_file"
done

echo "Stream Catalog metadata applied successfully."

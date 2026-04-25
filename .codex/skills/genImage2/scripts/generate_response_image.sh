#!/usr/bin/env bash

set -euo pipefail

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="${CODEX_CONFIG_FILE:-$CODEX_HOME_DIR/config.toml}"
AUTH_FILE="${CODEX_AUTH_FILE:-$CODEX_HOME_DIR/auth.json}"
TIMEOUT_SECONDS="${RESPONSE_IMAGE_MAX_TIME:-360}"

usage() {
  cat <<'EOF'
Usage:
  generate_response_image.sh --prompt "..." [--model MODEL] [--output PATH]

Options:
  --prompt   Required. Image prompt sent to the Responses API.
  --model    Optional. Overrides the current model from the active Codex config.
  --output   Optional. Output PNG path. Defaults to ./response_image_<timestamp>.png
  --help     Show this message.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

prompt=""
model=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      prompt="${2:-}"
      shift 2
      ;;
    --model)
      model="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$prompt" ]]; then
  echo "--prompt is required." >&2
  usage >&2
  exit 1
fi

require_command curl
require_command jq
require_command openssl
require_command sed

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "Auth file not found: $AUTH_FILE" >&2
  exit 1
fi

base_url="$(sed -n 's/^base_url = "\(.*\)"$/\1/p' "$CONFIG_FILE" | head -n 1)"
current_model="$(sed -n 's/^model = "\(.*\)"$/\1/p' "$CONFIG_FILE" | head -n 1)"
api_key="$(jq -r '.OPENAI_API_KEY // empty' "$AUTH_FILE")"

if [[ -z "$base_url" ]]; then
  echo "Could not read base_url from $CONFIG_FILE" >&2
  exit 1
fi

if [[ -z "$current_model" && -z "$model" ]]; then
  echo "Could not read default model from $CONFIG_FILE" >&2
  exit 1
fi

if [[ -z "$api_key" ]]; then
  echo "Could not read OPENAI_API_KEY from $AUTH_FILE" >&2
  exit 1
fi

if [[ -z "$model" ]]; then
  model="$current_model"
fi

if [[ -z "$output" ]]; then
  output="$PWD/response_image_$(date +%Y%m%d_%H%M%S).png"
fi

mkdir -p "$(dirname "$output")"

tmp_json="$(mktemp /tmp/response-image-response.XXXXXX.json)"
tmp_payload="$(mktemp /tmp/response-image-payload.XXXXXX.json)"

cleanup() {
  rm -f "$tmp_json" "$tmp_payload"
}

trap cleanup EXIT

jq -n \
  --arg model "$model" \
  --arg prompt "$prompt" \
  '{
    model: $model,
    input: $prompt,
    tools: [{type: "image_generation"}],
    store: false
  }' > "$tmp_payload"

curl -sS --fail-with-body --max-time "$TIMEOUT_SECONDS" --location \
  "$base_url/responses" \
  --header "Authorization: Bearer $api_key" \
  --header "Content-Type: application/json" \
  --data "@$tmp_payload" \
  -o "$tmp_json"

response_error="$(jq -r '.error.message // empty' "$tmp_json" 2>/dev/null || true)"
if [[ -n "$response_error" ]]; then
  echo "Gateway returned an error: $response_error" >&2
  exit 1
fi

image_base64="$(jq -r '.output[] | select(.type=="image_generation_call") | .result // empty' "$tmp_json")"
if [[ -z "$image_base64" ]]; then
  echo "No image_generation result found in response." >&2
  jq '{id,status,error,output_types:[.output[]?.type]}' "$tmp_json" >&2 || true
  exit 1
fi

printf '%s' "$image_base64" | openssl base64 -d -A > "$output"

echo "Saved image: $output"
file "$output" 2>/dev/null || true

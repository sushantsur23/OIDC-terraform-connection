#!/usr/bin/env bash
# Reads the required keys from AWS Secrets Manager and prints proof they
# arrived: length and SHA-256 hash. Values are masked in GitHub logs.
#
# Settings: SECRET_ID (default sushant-app/prod/ci-test-keys), AWS_REGION.
# Requires: aws CLI v2, jq.

set -euo pipefail

SECRET_ID="${SECRET_ID:-sushant-app/prod/ci-test-keys}"
KEYS=(AWS_ACCESS_KEY AWS_SECRET_KEY)

secret_json=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" \
  --query SecretString --output text)

for key in "${KEYS[@]}"; do
  value=$(jq -r --arg k "$key" '.[$k] // empty' <<<"$secret_json")
  if [ -z "$value" ]; then
    echo "::error::$key not found in $SECRET_ID"
    exit 1
  fi
  echo "::add-mask::$value"
  echo "$key length: ${#value}"
  echo "$key sha256: $(printf '%s' "$value" | sha256sum | cut -d' ' -f1)"
done

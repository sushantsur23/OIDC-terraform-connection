#!/usr/bin/env bash
# Runs a Terraform stage for the environment in WORKDIR.
#
# Usage: terraform.sh plan | apply | destroy
#   plan     fmt check, init, validate, plan saved to tfplan
#   apply    init, apply the saved tfplan
#   destroy  init, destroy (optional wait: DESTROY_DELAY_SECONDS, default 0)
#
# Settings: WORKDIR (default terraform/environments/prod), relative to repo root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${WORKDIR:-terraform/environments/prod}"
cd "$ROOT/$WORKDIR"

stage="${1:-}"
case "$stage" in
  plan)
    terraform fmt -check -recursive "$ROOT/terraform"
    terraform init -input=false
    terraform validate
    terraform plan -input=false -out=tfplan
    ;;
  apply)
    terraform init -input=false
    terraform apply -input=false tfplan
    ;;
  destroy)
    delay="${DESTROY_DELAY_SECONDS:-0}"
    if [ "$delay" -gt 0 ]; then
      echo "Waiting ${delay}s before destroying..."
      sleep "$delay"
    fi
    terraform init -input=false
    terraform destroy -input=false -auto-approve
    ;;
  *)
    echo "Usage: $0 plan|apply|destroy" >&2
    exit 2
    ;;
esac

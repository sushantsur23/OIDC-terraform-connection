#!/usr/bin/env bash
# Deletes the pipeline's CloudWatch log group and every log stream in it.
# This cannot be undone. The next run of run-logged.sh creates the group again.
#
# Settings: LOG_GROUP (default test_group), LOG_REGION (default AWS_REGION).
# Do not run this through run-logged.sh, which would recreate the group.

set -euo pipefail

LOG_GROUP="${LOG_GROUP:-test_group}"
LOG_REGION="${LOG_REGION:-${AWS_REGION:-us-west-2}}"

if err=$(aws logs delete-log-group --region "$LOG_REGION" --log-group-name "$LOG_GROUP" 2>&1); then
  echo "Deleted log group '$LOG_GROUP' in $LOG_REGION."
elif grep -q ResourceNotFoundException <<<"$err"; then
  echo "Log group '$LOG_GROUP' does not exist in $LOG_REGION. Nothing to delete."
else
  echo "::error::Could not delete log group '$LOG_GROUP': $err"
  exit 1
fi

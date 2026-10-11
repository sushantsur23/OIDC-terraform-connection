#!/usr/bin/env bash
# Runs a script from this folder, shows its output as usual, and sends the
# output to CloudWatch Logs, one log stream per process:
#   <LOG_GROUP> / <run id>-<attempt>/<job>/<process>
# e.g. test_group / 1234567-1/plan/terraform-plan
#
# Usage: run-logged.sh <script.sh> [args...]
#
# Settings: LOG_GROUP (default test_group), LOG_REGION (default AWS_REGION).
# The script's exit code is kept. A failed upload only prints a warning.
# Lines starting with ::add-mask:: are never sent, because they hold the raw
# secret value that GitHub masks in its own logs. CloudWatch masks nothing.
#
# Requires: aws CLI v2, jq, bash 5 (for EPOCHREALTIME).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${1:?Usage: run-logged.sh <script.sh> [args...]}"
shift

process="${script%.sh}"
for arg in "$@"; do process+="-$arg"; done

LOG_GROUP="${LOG_GROUP:-test_group}"
LOG_REGION="${LOG_REGION:-${AWS_REGION:-us-west-2}}"
STREAM="${GITHUB_RUN_ID:-local-$(date +%Y%m%d%H%M%S)}-${GITHUB_RUN_ATTEMPT:-1}/${GITHUB_JOB:-local}/${process}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

warn() {
  local msg
  msg=$(printf '%s' "$*" | tr -s '\r\n' '  ' | sed 's/^ *//')
  echo "::warning::CloudWatch upload: $msg"
}

# AWS CLI on Windows (Git Bash) needs a Windows path for file:// arguments.
cli_path() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# Print each line, and save it with a millisecond timestamp for CloudWatch.
stamp_and_show() {
  local line t
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line"
    t=${EPOCHREALTIME//[.,]/}
    printf '%s\t%s\n' "${t:0:13}" "$line" >>"$work/raw.log"
  done
}

upload() {
  local err="$work/err" chunk
  if ! aws logs create-log-stream --region "$LOG_REGION" \
      --log-group-name "$LOG_GROUP" --log-stream-name "$STREAM" 2>"$err"; then
    grep -q ResourceAlreadyExistsException "$err" || { warn "$(cat "$err")"; return; }
  fi

  [ -s "$work/raw.log" ] || { echo "[run-logged] No output to send."; return; }

  # Strip color codes, drop secret mask lines, split into batches.
  sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$work/raw.log" \
    | { grep -v $'\t::add-mask::' || true; } >"$work/clean.log"
  split -l 1000 "$work/clean.log" "$work/chunk."

  for chunk in "$work"/chunk.*; do
    jq -R -s '[split("\n")[] | select(length > 0)
      | index("\t") as $i
      | {timestamp: (.[:$i] | tonumber),
         message: (.[$i + 1:] | if . == "" then " " else .[:32000] end)}]' \
      "$chunk" >"$chunk.json"
    aws logs put-log-events --region "$LOG_REGION" \
      --log-group-name "$LOG_GROUP" --log-stream-name "$STREAM" \
      --log-events "file://$(cli_path "$chunk.json")" >/dev/null 2>"$err" \
      || { warn "$(cat "$err")"; return; }
  done
  echo "[run-logged] Sent logs to $LOG_GROUP / $STREAM ($LOG_REGION)."
}

bash "$SCRIPT_DIR/$script" "$@" 2>&1 | stamp_and_show
status=${PIPESTATUS[0]}

upload
exit "$status"

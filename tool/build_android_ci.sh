#!/usr/bin/env bash
# Flutter has its own short retry. Give a rate-limited Maven host time to recover.
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
for attempt in 1 2 3; do
  if flutter build apk --release 2>&1 | tee "$log"; then
    exit 0
  else
    statuses=("${PIPESTATUS[@]}")
    status=${statuses[0]}
    if [[ $status == 0 ]]; then exit "${statuses[1]}"; fi
  fi
  if ! grep -Eiq '(status code 429|HTTP[^ ]* 429|429 Too Many Requests)' "$log"; then
    exit "$status"
  fi
  if [[ $attempt == 3 ]]; then
    echo "::error::Maven HTTP 429 persisted after three Android build attempts"
    exit "$status"
  fi
  delay=$((30 * 2 ** (attempt - 1)))
  echo "::warning::Maven returned HTTP 429. Retrying in ${delay}s ($attempt/3)"
  sleep "$delay"
done

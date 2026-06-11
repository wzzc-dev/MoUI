#!/usr/bin/env sh
set -u

max_attempts="${MOON_UPDATE_MAX_ATTEMPTS:-3}"
attempt=1

while [ "$attempt" -le "$max_attempts" ]; do
  if moon update; then
    exit 0
  fi

  status="$?"
  if [ "$attempt" -ge "$max_attempts" ]; then
    printf 'moon update failed after %s attempts\n' "$attempt" >&2
    exit "$status"
  fi

  sleep_seconds=$((attempt * 10))
  printf 'moon update failed on attempt %s/%s; retrying in %ss\n' \
    "$attempt" "$max_attempts" "$sleep_seconds" >&2
  sleep "$sleep_seconds"
  attempt=$((attempt + 1))
done

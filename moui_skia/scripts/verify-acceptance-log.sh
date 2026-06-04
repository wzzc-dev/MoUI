#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-acceptance-log.sh LOG_PATH [options]

Checks a real Skia acceptance summary log for the required pass fields:
  smoke_status=0
  native_smoke_marker=passed
  native_pkg_restore=passed

Options:
  --require-commit   Also require skia_commit=<40 hex chars>.
  -h, --help         Show this help.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

log_path="$1"
shift
require_commit=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-commit)
      require_commit=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$log_path" ]]; then
  echo "acceptance log is missing: $log_path" >&2
  exit 1
fi

require_field() {
  local expected="$1"
  if ! grep -Eq "^[[:space:]]*${expected}[[:space:]]*$" "$log_path"; then
    echo "acceptance log is missing required field: $expected" >&2
    exit 1
  fi
}

require_field "smoke_status=0"
require_field "native_smoke_marker=passed"
require_field "native_pkg_restore=passed"

if [[ $require_commit -eq 1 ]]; then
  if ! grep -Eq '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$log_path"; then
    echo "acceptance log is missing a full 40-character skia_commit hash" >&2
    exit 1
  fi
fi

echo "Verified real Skia acceptance log in $log_path."

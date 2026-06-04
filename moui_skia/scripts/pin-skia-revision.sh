#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/pin-skia-revision.sh [acceptance-log]

Verifies a Linux real Skia acceptance log, reads the last skia_commit=<hash>
entry, and writes that commit to skia-revision.txt. The default log path is
logs/linux-real-skia-smoke/linux-real-skia-acceptance.log.

Options:
  -h, --help    Show this help.

The log must have smoke_status=0, native_smoke_marker=passed,
native_pkg_restore=passed, and a full 40-character Git SHA. This avoids pinning
floating names such as main, failed-run placeholders such as unknown, or commits
from failed acceptance runs.
EOF
}

log_path="logs/linux-real-skia-smoke/linux-real-skia-acceptance.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ $# -ne 1 ]]; then
        echo "expected at most one acceptance log path" >&2
        usage >&2
        exit 2
      fi
      log_path="$1"
      shift
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$log_path" in
  /*) resolved_log_path="$log_path" ;;
  *) resolved_log_path="$repo_root/$log_path" ;;
esac

if [[ ! -f "$resolved_log_path" ]]; then
  echo "acceptance log was not found: $resolved_log_path" >&2
  exit 1
fi

bash "$repo_root/scripts/verify-acceptance-log.sh" "$resolved_log_path" --require-commit

skia_commit="$(grep -E '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$resolved_log_path" | tail -n 1 | sed -E 's/^[[:space:]]*skia_commit=([0-9a-fA-F]{40})[[:space:]]*$/\1/' || true)"
if [[ -z "$skia_commit" ]]; then
  echo "no full 40-character skia_commit=<hash> entry was found in $resolved_log_path" >&2
  exit 1
fi

printf '%s\n' "${skia_commit,,}" > "$repo_root/skia-revision.txt"
echo "Pinned skia-revision.txt to ${skia_commit,,}"

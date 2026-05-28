#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-smoke-log.sh LOG_PATH [MARKER]

Checks that a native smoke executable log exists, contains key smoke-stage
markers, and contains the expected success marker. The default marker is
`skia_mbt native smoke test passed`.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

log_path="$1"
marker="${2:-skia_mbt native smoke test passed}"

if [[ ! -f "$log_path" ]]; then
  echo "native smoke executable log is missing: $log_path" >&2
  exit 1
fi

if ! grep -Fq "$marker" "$log_path"; then
  echo "native smoke executable log is missing the success marker: $marker" >&2
  exit 1
fi

for stage_marker in \
  "native smoke readback width" \
  "native smoke bounded readback width" \
  "native smoke bounded snapshot width" \
  "native smoke encoded PNG bytes" \
  "native smoke decoded image width" \
  "native smoke codec encoded format PNG" \
  "native smoke decoded bitmap width"; do
  if ! grep -Fq "$stage_marker" "$log_path"; then
    echo "native smoke executable log is missing required stage marker: $stage_marker" >&2
    exit 1
  fi
done

echo "Verified native smoke stage markers and success marker in $log_path."

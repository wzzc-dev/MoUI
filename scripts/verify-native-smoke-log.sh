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

default_stage_markers=(
  "native smoke surface descriptor backend" \
  "native smoke canvas state restored" \
  "native smoke canvas replay commands" \
  "native smoke render resource plan count" \
  "native smoke render frame resource plan count" \
  "native smoke render frame validation status" \
  "native smoke render resource cache inserts" \
  "native smoke gpu context resource plan count" \
  "native smoke surface target resource plan count" \
  "native smoke window target resource plan count" \
  "native smoke shader draws" \
  "native smoke shader resource plan count" \
  "native smoke filter layer count" \
  "native smoke filter resource plan count" \
  "native smoke path verbs" \
  "native smoke readback width" \
  "native smoke bounded readback width" \
  "native smoke bounded snapshot width" \
  "native smoke encoded PNG bytes" \
  "native smoke decoded image width" \
  "native smoke codec encoded format PNG" \
  "native smoke decoded bitmap width" \
  "native smoke font spacing" \
  "native smoke font resource plan count" \
  "native smoke measured text width" \
  "native smoke text glyph count" \
  "native smoke first glyph id" \
  "native smoke first glyph width" \
  "native smoke second glyph position x" \
  "native smoke second glyph x position" \
  "native smoke first glyph bounds width" \
  "native smoke measured text bounds width" \
  "native smoke font family count" \
  "native smoke first font family bytes" \
  "native smoke typeface family bytes" \
  "native smoke font fallback resource plan count" \
  "native smoke font fallback width"
)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status_file="$repo_root/skia-platform-status.json"
stage_markers=("${default_stage_markers[@]}")
if [[ -f "$status_file" ]]; then
  status_stage_markers="$(
    python3 - "$status_file" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
status = json.loads(status_path.read_text(encoding="utf-8"))
for capability in status.get("native_smoke_capabilities", []):
    marker = str(capability.get("marker", "")).strip()
    if marker:
        print(marker)
PY
  )"
  if [[ -n "$status_stage_markers" ]]; then
    stage_markers=()
    while IFS= read -r status_stage_marker; do
      if [[ -n "$status_stage_marker" ]]; then
        stage_markers+=("$status_stage_marker")
      fi
    done <<< "$status_stage_markers"
  fi
fi

for stage_marker in "${stage_markers[@]}"; do
  if ! grep -Fq "$stage_marker" "$log_path"; then
    echo "native smoke executable log is missing required stage marker: $stage_marker" >&2
    exit 1
  fi
done

echo "Verified native smoke stage markers and success marker in $log_path."

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

has_exact_line() {
  local expected="$1"
  awk -v expected="$expected" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == expected) {
        found = 1
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$log_path"
}

if ! has_exact_line "$marker"; then
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
  "native smoke render target identity validation" \
  "native smoke render target resource binding" \
  "native smoke render frame cache resources" \
  "native smoke render resource cache inserts" \
  "native smoke gpu context resource plan count" \
  "native smoke gpu frame context validation" \
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
  "native smoke text run resource plan count" \
  "native smoke text run range byte size" \
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
  "native smoke font fallback font resource plan count" \
  "native smoke font fallback width"
)

default_expected_stage_values=(
  $'native smoke render resource plan count\t9'
  $'native smoke render frame resource plan count\t9'
  $'native smoke render frame validation status\t1'
  $'native smoke render target identity validation\t1'
  $'native smoke render target resource binding\t1'
  $'native smoke render frame cache resources\t9'
  $'native smoke render resource cache inserts\t9'
  $'native smoke gpu context resource plan count\t2'
  $'native smoke gpu frame context validation\t1'
  $'native smoke surface target resource plan count\t2'
  $'native smoke window target resource plan count\t1'
  $'native smoke shader draws\t3'
  $'native smoke shader resource plan count\t3'
  $'native smoke filter resource plan count\t3'
  $'native smoke text run resource plan count\t3'
  $'native smoke text run range byte size\t4'
  $'native smoke font resource plan count\t1'
  $'native smoke font fallback resource plan count\t1'
  $'native smoke font fallback font resource plan count\t2'
)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status_file="$repo_root/skia-platform-status.json"
stage_markers=("${default_stage_markers[@]}")
expected_stage_values=("${default_expected_stage_values[@]}")
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
  status_expected_stage_values="$(
    python3 - "$status_file" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
status = json.loads(status_path.read_text(encoding="utf-8"))
for expected in status.get("native_smoke_expected_values", []):
    marker = str(expected.get("marker", "")).strip()
    value = str(expected.get("value", "")).strip()
    if marker and value:
        print(marker + "\t" + value)
PY
  )"
  if [[ -n "$status_expected_stage_values" ]]; then
    expected_stage_values=()
    while IFS= read -r status_expected_stage_value; do
      if [[ -n "$status_expected_stage_value" ]]; then
        expected_stage_values+=("$status_expected_stage_value")
      fi
    done <<< "$status_expected_stage_values"
  fi
fi

for stage_marker in "${stage_markers[@]}"; do
  if ! has_exact_line "$stage_marker"; then
    echo "native smoke executable log is missing required stage marker: $stage_marker" >&2
    exit 1
  fi
done

marker_value() {
  local marker="$1"
  python3 - "$log_path" "$marker" <<'PY'
import pathlib
import sys

log_path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
for index, line in enumerate(lines):
    if line.strip() == marker:
        if index + 1 >= len(lines):
            print(f"native smoke executable log marker has no value: {marker}", file=sys.stderr)
            raise SystemExit(1)
        print(lines[index + 1].strip())
        raise SystemExit(0)
print(f"native smoke executable log is missing exact stage marker line: {marker}", file=sys.stderr)
raise SystemExit(1)
PY
}

for expected_stage_value in "${expected_stage_values[@]}"; do
  IFS=$'\t' read -r expected_marker expected_value <<< "$expected_stage_value"
  actual_value="$(marker_value "$expected_marker")"
  if [[ "$actual_value" != "$expected_value" ]]; then
    echo "native smoke executable log has unexpected stage marker value: $expected_marker" >&2
    echo "  expected=$expected_value" >&2
    echo "  actual=$actual_value" >&2
    exit 1
  fi
done

echo "Verified native smoke stage markers and success marker in $log_path."

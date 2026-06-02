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
  "native smoke surface target factory raster" \
  "native smoke surface target factory unsupported" \
  "native smoke surface target support diagnostics" \
  "native smoke canvas state restored" \
  "native smoke canvas clip device width" \
  "native smoke canvas replay commands" \
  "native smoke render frame replay commands" \
  "native smoke render frame replay complete" \
  "native smoke canvas replay status contract" \
  "native smoke render frame replay rejected skipped" \
  "native smoke surface render frame commands" \
  "native smoke surface render frame finalized" \
  "native smoke surface render frame status contract" \
  "native smoke surface render frame finalization frame index" \
  "native smoke surface render frame finalization resource plan count" \
  "native smoke surface render frame finalization cacheable count" \
  "native smoke surface render frame finalization uncacheable count" \
  "native smoke surface render frame cache resources" \
  "native smoke native replay resource stats caches" \
  "native smoke native replay resource stats resources" \
  "native smoke surface render frame mismatch rejected" \
  "native smoke render frame pixmap sample proof" \
  "native smoke render shaped glyph run command replay" \
  "native smoke render shader cache resources" \
  "native smoke render shader cache misses" \
  "native smoke render shader cache hits" \
  "native smoke render path cache resources" \
  "native smoke render path cache misses" \
  "native smoke render path cache hits" \
  "native smoke render text run cache resources" \
  "native smoke render text run cache misses" \
  "native smoke render text run cache hits" \
  "native smoke render font cache resources" \
  "native smoke render font cache misses" \
  "native smoke render font cache hits" \
  "native smoke render typeface cache resources" \
  "native smoke render typeface cache misses" \
  "native smoke render typeface cache hits" \
  "native smoke render color filter cache resources" \
  "native smoke render color filter cache misses" \
  "native smoke render color filter cache hits" \
  "native smoke render image filter cache resources" \
  "native smoke render image filter cache misses" \
  "native smoke render image filter cache hits" \
  "native smoke render mask filter cache resources" \
  "native smoke render mask filter cache misses" \
  "native smoke render mask filter cache hits" \
  "native smoke render resource plan count" \
  "native smoke render frame resource plan count" \
  "native smoke render frame validation status" \
  "native smoke render frame cacheable subplan count" \
  "native smoke render frame uncacheable subplan count" \
  "native smoke render frame unbalanced validation" \
  "native smoke render target identity validation" \
  "native smoke render target resource binding" \
  "native smoke render frame present count" \
  "native smoke render frame present descriptor validation" \
  "native smoke render frame submission resource plan count" \
  "native smoke render frame submission cacheable subplan count" \
  "native smoke render frame submission uncacheable subplan count" \
  "native smoke render frame submission preflight missing count" \
  "native smoke render frame submission preflight cached count" \
  "native smoke render frame submission cache resources" \
  "native smoke render frame finalization resource plan count" \
  "native smoke render frame finalization cacheable subplan count" \
  "native smoke render frame finalization uncacheable subplan count" \
  "native smoke render frame finalization preflight missing count" \
  "native smoke render frame finalization preflight cached count" \
  "native smoke render frame finalization cache resources" \
  "native smoke render frame missing present validation" \
  "native smoke render frame missing finalization validation" \
  "native smoke render frame touched bounds width" \
  "native smoke canvas replay deferred present" \
  "native smoke render frame cache resources" \
  "native smoke render resource cache inserts" \
  "native smoke render resource cache preflight missing count" \
  "native smoke render resource cache preflight cached count" \
  "native smoke render resource cache plan coverage" \
  "native smoke render resource cache evictions" \
  "native smoke render resource cache hits" \
  "native smoke render resource cache misses" \
  "native smoke render resource cache byte size" \
  "native smoke gpu context resource plan count" \
  "native smoke gpu context key variation" \
  "native smoke gpu frame context validation" \
  "native smoke gpu present resource plan count" \
  "native smoke gpu finalization resource plan count" \
  "native smoke gpu frame finalization resource plan count" \
  "native smoke gpu frame finalization gpu resource count" \
  "native smoke gpu frame submission resource plan count" \
  "native smoke gpu frame submission gpu resource count" \
  "native smoke surface target resource plan count" \
  "native smoke surface target cache resources" \
  "native smoke window target resource plan count" \
  "native smoke window physical width" \
  "native smoke window frame pacing" \
  "native smoke window frame pacing key variation" \
  "native smoke window present mode key variation" \
  "native smoke surface finalization resource plan count" \
  "native smoke surface finalization key variation" \
  "native smoke surface present buffer index" \
  "native smoke surface present resource plan count" \
  "native smoke surface flush-and-submit" \
  "native smoke shader draws" \
  "native smoke shader resource plan count" \
  "native smoke filter layer count" \
  "native smoke filter resource plan count" \
  "native smoke path verbs" \
  "native smoke readback width" \
  "native smoke readback height" \
  "native smoke readback row_bytes" \
  "native smoke pixmap readback sample proof" \
  "native smoke bounded readback width" \
  "native smoke bounded readback height" \
  "native smoke bounded snapshot width" \
  "native smoke bounded snapshot height" \
  "native smoke encoded PNG bytes" \
  "native smoke decoded image width" \
  "native smoke decoded image height" \
  "native smoke render image command replay" \
  "native smoke render image command count" \
  "native smoke render image resource plan count" \
  "native smoke render image cache resources" \
  "native smoke render image cache misses" \
  "native smoke render image cache hits" \
  "native smoke codec encoded format PNG" \
  "native smoke codec width" \
  "native smoke codec height" \
  "native smoke decoded bitmap width" \
  "native smoke decoded bitmap height" \
  "native smoke font spacing" \
  "native smoke font resource plan count" \
  "native smoke text run resource plan count" \
  "native smoke text run range byte size" \
  "native smoke text measurement resource plan count" \
  "native smoke measured text resource plan count" \
  "native smoke measured text key variation" \
  "native smoke text measurement key variation" \
  "native smoke text shaping resource plan count" \
  "native smoke shaped text resource plan count" \
  "native smoke shaped glyph run resource plan count" \
  "native smoke shaped glyph run key variation" \
  "native smoke measured text width" \
  "native smoke text glyph count" \
  "native smoke first glyph id" \
  "native smoke first glyph width" \
  "native smoke second glyph position x" \
  "native smoke second glyph x position" \
  "native smoke first glyph bounds width" \
  "native smoke measured text bounds width" \
  "native smoke shaper availability" \
  "native smoke default typeface availability" \
  "native smoke font family count" \
  "native smoke first font family bytes" \
  "native smoke typeface family bytes" \
  "native smoke font fallback key variation" \
  "native smoke font fallback family bytes" \
  "native smoke font fallback match key variation" \
  "native smoke font fallback match resource plan count" \
  "native smoke font fallback resolution key variation" \
  "native smoke font fallback resolution resource plan count" \
  "native smoke font fallback resolution bridge" \
  "native smoke font fallback resolution bridge cache resources" \
  "native smoke font fallback resource plan count" \
  "native smoke font fallback font resource plan count" \
  "native smoke font fallback width"
)

default_expected_stage_values=(
  $'native smoke surface target support diagnostics\t2'
  $'native smoke canvas clip device width\t4'
  $'native smoke canvas state restored\t1'
  $'native smoke canvas replay commands\t23'
  $'native smoke render frame replay commands\t23'
  $'native smoke render frame replay complete\t1'
  $'native smoke canvas replay status contract\t3'
  $'native smoke render frame replay rejected skipped\t20'
  $'native smoke surface render frame commands\t23'
  $'native smoke surface render frame finalized\t1'
  $'native smoke surface render frame status contract\t2'
  $'native smoke surface render frame finalization frame index\t7'
  $'native smoke surface render frame finalization resource plan count\t16'
  $'native smoke surface render frame finalization cacheable count\t15'
  $'native smoke surface render frame finalization uncacheable count\t1'
  $'native smoke surface render frame cache resources\t9'
  $'native smoke native replay resource stats caches\t9'
  $'native smoke native replay resource stats resources\t9'
  $'native smoke surface render frame mismatch rejected\t1'
  $'native smoke render frame pixmap sample proof\t1'
  $'native smoke render shaped glyph run command replay\t1'
  $'native smoke render shader cache resources\t1'
  $'native smoke render shader cache misses\t1'
  $'native smoke render shader cache hits\t2'
  $'native smoke render path cache resources\t2'
  $'native smoke render path cache misses\t2'
  $'native smoke render path cache hits\t0'
  $'native smoke render text run cache resources\t1'
  $'native smoke render text run cache misses\t1'
  $'native smoke render text run cache hits\t0'
  $'native smoke render font cache resources\t1'
  $'native smoke render font cache misses\t1'
  $'native smoke render font cache hits\t0'
  $'native smoke render typeface cache resources\t1'
  $'native smoke render typeface cache misses\t1'
  $'native smoke render typeface cache hits\t0'
  $'native smoke render color filter cache resources\t1'
  $'native smoke render color filter cache misses\t1'
  $'native smoke render color filter cache hits\t0'
  $'native smoke render image filter cache resources\t1'
  $'native smoke render image filter cache misses\t1'
  $'native smoke render image filter cache hits\t0'
  $'native smoke render mask filter cache resources\t1'
  $'native smoke render mask filter cache misses\t1'
  $'native smoke render mask filter cache hits\t0'
  $'native smoke render resource plan count\t15'
  $'native smoke render frame resource plan count\t15'
  $'native smoke render frame validation status\t1'
  $'native smoke render frame cacheable subplan count\t15'
  $'native smoke render frame uncacheable subplan count\t0'
  $'native smoke render frame unbalanced validation\t1'
  $'native smoke render target identity validation\t1'
  $'native smoke render target resource binding\t1'
  $'native smoke render frame present count\t1'
  $'native smoke render frame present descriptor validation\t1'
  $'native smoke render frame submission resource plan count\t2'
  $'native smoke render frame submission cacheable subplan count\t1'
  $'native smoke render frame submission uncacheable subplan count\t1'
  $'native smoke render frame submission preflight missing count\t1'
  $'native smoke render frame submission preflight cached count\t1'
  $'native smoke render frame submission cache resources\t1'
  $'native smoke render frame finalization resource plan count\t2'
  $'native smoke render frame finalization cacheable subplan count\t1'
  $'native smoke render frame finalization uncacheable subplan count\t1'
  $'native smoke render frame finalization preflight missing count\t1'
  $'native smoke render frame finalization preflight cached count\t1'
  $'native smoke render frame finalization cache resources\t1'
  $'native smoke render frame missing present validation\t1'
  $'native smoke render frame missing finalization validation\t1'
  $'native smoke render frame touched bounds width\t4'
  $'native smoke canvas replay deferred present\t1'
  $'native smoke render frame cache resources\t15'
  $'native smoke render resource cache inserts\t15'
  $'native smoke render resource cache preflight missing count\t15'
  $'native smoke render resource cache preflight cached count\t15'
  $'native smoke render resource cache plan coverage\t1'
  $'native smoke render resource cache evictions\t1'
  $'native smoke render resource cache hits\t1'
  $'native smoke render resource cache misses\t0'
  $'native smoke render resource cache byte size\t8'
  $'native smoke gpu context resource plan count\t2'
  $'native smoke gpu context key variation\t1'
  $'native smoke gpu frame context validation\t1'
  $'native smoke gpu present resource plan count\t3'
  $'native smoke gpu finalization resource plan count\t3'
  $'native smoke gpu frame finalization resource plan count\t3'
  $'native smoke gpu frame finalization gpu resource count\t3'
  $'native smoke gpu frame submission resource plan count\t3'
  $'native smoke gpu frame submission gpu resource count\t3'
  $'native smoke surface target resource plan count\t2'
  $'native smoke surface target cache resources\t2'
  $'native smoke window target resource plan count\t1'
  $'native smoke window physical width\t16'
  $'native smoke window frame pacing\t2'
  $'native smoke window frame pacing key variation\t1'
  $'native smoke window present mode key variation\t1'
  $'native smoke surface finalization resource plan count\t2'
  $'native smoke surface finalization key variation\t1'
  $'native smoke surface present buffer index\t1'
  $'native smoke surface present resource plan count\t2'
  $'native smoke surface flush-and-submit\t1'
  $'native smoke readback width\t32'
  $'native smoke readback height\t32'
  $'native smoke readback row_bytes\t128'
  $'native smoke pixmap readback sample proof\t1'
  $'native smoke bounded readback width\t4'
  $'native smoke bounded readback height\t4'
  $'native smoke bounded snapshot width\t4'
  $'native smoke bounded snapshot height\t4'
  $'native smoke filter layer count\t1'
  $'native smoke path verbs\t9'
  $'native smoke decoded image width\t32'
  $'native smoke decoded image height\t32'
  $'native smoke render image command replay\t1'
  $'native smoke render image command count\t3'
  $'native smoke render image resource plan count\t2'
  $'native smoke render image cache resources\t1'
  $'native smoke render image cache misses\t1'
  $'native smoke render image cache hits\t1'
  $'native smoke codec width\t32'
  $'native smoke codec height\t32'
  $'native smoke decoded bitmap width\t32'
  $'native smoke decoded bitmap height\t32'
  $'native smoke shader draws\t3'
  $'native smoke shader resource plan count\t3'
  $'native smoke filter resource plan count\t3'
  $'native smoke text run resource plan count\t3'
  $'native smoke text run range byte size\t4'
  $'native smoke text measurement resource plan count\t4'
  $'native smoke measured text resource plan count\t5'
  $'native smoke measured text key variation\t1'
  $'native smoke text measurement key variation\t1'
  $'native smoke text shaping resource plan count\t4'
  $'native smoke shaped text resource plan count\t5'
  $'native smoke shaped glyph run resource plan count\t6'
  $'native smoke shaped glyph run key variation\t1'
  $'native smoke font resource plan count\t1'
  $'native smoke font fallback key variation\t1'
  $'native smoke font fallback match key variation\t1'
  $'native smoke font fallback match resource plan count\t2'
  $'native smoke font fallback resolution key variation\t1'
  $'native smoke font fallback resolution resource plan count\t4'
  $'native smoke font fallback resolution bridge\t1'
  $'native smoke font fallback resolution bridge cache resources\t4'
  $'native smoke font fallback resource plan count\t1'
  $'native smoke font fallback font resource plan count\t2'
)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status_file="$repo_root/skia-platform-status.json"
stage_markers=("${default_stage_markers[@]}")
expected_stage_values=("${default_expected_stage_values[@]}")
default_conditional_stage_markers=(
  $'native smoke shaped glyph count\tnative smoke shaper availability\t1'
  $'native smoke shaped text native resource plan count\tnative smoke shaper availability\t1'
  $'native smoke shaped glyph run native resource plan count\tnative smoke shaper availability\t1'
  $'native smoke shaped glyph descriptor bridge\tnative smoke shaper availability\t1'
  $'native smoke shaped glyph descriptor bridge cache resources\tnative smoke shaper availability\t1'
)
conditional_stage_markers=("${default_conditional_stage_markers[@]}")
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
  status_conditional_stage_markers="$(
    python3 - "$status_file" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
status = json.loads(status_path.read_text(encoding="utf-8"))
for conditional in status.get("native_smoke_conditional_capabilities", []):
    marker = str(conditional.get("marker", "")).strip()
    when_marker = str(conditional.get("when_marker", "")).strip()
    when_value = str(conditional.get("when_value", "")).strip()
    if marker and when_marker and when_value:
        print(marker + "\t" + when_marker + "\t" + when_value)
PY
  )"
  if [[ -n "$status_conditional_stage_markers" ]]; then
    conditional_stage_markers=()
    while IFS= read -r status_conditional_stage_marker; do
      if [[ -n "$status_conditional_stage_marker" ]]; then
        conditional_stage_markers+=("$status_conditional_stage_marker")
      fi
    done <<< "$status_conditional_stage_markers"
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

for conditional_stage_marker in "${conditional_stage_markers[@]}"; do
  IFS=$'\t' read -r marker when_marker when_value <<< "$conditional_stage_marker"
  actual_when_value="$(marker_value "$when_marker")"
  if [[ "$actual_when_value" == "$when_value" ]]; then
    if ! has_exact_line "$marker"; then
      echo "native smoke executable log is missing conditional stage marker: $marker" >&2
      echo "  when_marker=$when_marker" >&2
      echo "  when_value=$when_value" >&2
      exit 1
    fi
    marker_value "$marker" >/dev/null
  fi
done

echo "Verified native smoke stage markers and success marker in $log_path."

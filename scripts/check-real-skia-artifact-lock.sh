#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/skia-mbt-artifact-lock.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

assert_fails_with() {
  local expected="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    echo "command unexpectedly succeeded: $*" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "command failed without expected message: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

native_log_for() {
  local path="$1"
  python3 - "$repo_root/skia-platform-status.json" "$path" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
status = json.loads(status_path.read_text(encoding="utf-8"))
expected_values = {
    entry["marker"].strip(): str(entry["value"]).strip()
    for entry in status.get("native_smoke_expected_values", [])
    if entry.get("marker", "").strip() and str(entry.get("value", "")).strip()
}
marker_values = {}
lines = []
for capability in status["native_smoke_capabilities"]:
    marker = capability["marker"].strip()
    if marker:
        value = expected_values.get(marker, "1")
        marker_values[marker] = value
        lines.append(marker)
        lines.append(value)
for conditional in status.get("native_smoke_conditional_capabilities", []):
    marker = conditional.get("marker", "").strip()
    when_marker = conditional.get("when_marker", "").strip()
    when_value = str(conditional.get("when_value", "")).strip()
    if marker and marker_values.get(when_marker) == when_value:
        lines.append(marker)
        lines.append("1")
lines.append("skia_mbt native smoke test passed")
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

provider_info="$(
  python3 - "$repo_root/skia-provider-lock.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
provider = manifest["providers"]["jetbrains"]
asset = provider["assets"]["linux"]["Release"]["x64"]
print(provider["tag"])
print(provider["commit"])
print(asset["name"])
print(asset["sha256"])
PY
)"
jetbrains_tag="$(printf '%s\n' "$provider_info" | sed -n '1p')"
jetbrains_commit="$(printf '%s\n' "$provider_info" | sed -n '2p')"
jetbrains_package="$(printf '%s\n' "$provider_info" | sed -n '3p')"
jetbrains_sha256="$(printf '%s\n' "$provider_info" | sed -n '4p')"

write_jetbrains_artifact() {
  local dir="$1"
  local tag="${2:-$jetbrains_tag}"
  local commit="${3:-$jetbrains_commit}"
  local package="${4:-$jetbrains_package}"
  local sha256="${5:-$jetbrains_sha256}"
  local acceptance_tag="${6:-$tag}"
  local acceptance_commit="${7:-$commit}"
  local acceptance_package="${8:-$package}"
  local acceptance_sha256="${9:-$sha256}"

  mkdir -p "$dir"
  printf '%s\n' "Linux JetBrains Skia dry-run preflight" \
    > "$dir/linux-real-skia-smoke-preflight.log"
  printf '%s\n' \
    "Linux Skia smoke environment:" \
    "  skia_include=/tmp/fake/skia" \
    "  skia_lib_dir=/tmp/fake/skia/out/Release-x64" \
    "  skia_lib=skia" \
    "  skia_provider=jetbrains" \
    "  jetbrains_tag=$tag" \
    "  skia_commit=$commit" \
    "  skia_package=$package" \
    "  skia_package_sha256=$sha256" \
    "  library=libskia.so 123 bytes" \
    "  stub_cc_flags=-DSKIA_MBT_HAS_SKIA -I/tmp/fake/skia" \
    "  cc_link_flags=-L/tmp/fake/skia/out/Release-x64 -lskia -lpthread -ldl -lm" \
    > "$dir/linux-real-skia-smoke.log"
  native_log_for "$dir/linux-native-smoke-output.log"
  printf '%s\n' \
    "Linux real Skia acceptance result:" \
    "  smoke_status=0" \
    "  native_smoke_marker=passed" \
    "  native_pkg_restore=passed" \
    "  skia_provider=jetbrains" \
    "  jetbrains_tag=$acceptance_tag" \
    "  skia_commit=$acceptance_commit" \
    "  skia_package=$acceptance_package" \
    "  skia_package_sha256=$acceptance_sha256" \
    "  preflight_log=$dir/linux-real-skia-smoke-preflight.log" \
    "  wrapper_log=$dir/linux-real-skia-smoke.log" \
    "  native_log=$dir/linux-native-smoke-output.log" \
    "  acceptance_log=$dir/linux-real-skia-acceptance.log" \
    > "$dir/linux-real-skia-acceptance.log"
}

good_dir="$tmp_root/good"
write_jetbrains_artifact "$good_dir"
bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$good_dir"

bad_tag_dir="$tmp_root/bad-tag"
write_jetbrains_artifact "$bad_tag_dir" "m000-0000000000"
assert_fails_with \
  "JetBrains tag mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_tag_dir"

bad_commit_dir="$tmp_root/bad-commit"
write_jetbrains_artifact "$bad_commit_dir" \
  "$jetbrains_tag" \
  "0123456789abcdef0123456789abcdef01234567"
assert_fails_with \
  "JetBrains commit mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_commit_dir"

bad_package_dir="$tmp_root/bad-package"
write_jetbrains_artifact "$bad_package_dir" \
  "$jetbrains_tag" \
  "$jetbrains_commit" \
  "Skia-m148-8967a2e80c-linux-Release-ppc64.zip"
assert_fails_with \
  "JetBrains package is not locked" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_package_dir"

bad_sha_dir="$tmp_root/bad-sha"
write_jetbrains_artifact "$bad_sha_dir" \
  "$jetbrains_tag" \
  "$jetbrains_commit" \
  "$jetbrains_package" \
  "0000000000000000000000000000000000000000000000000000000000000000"
assert_fails_with \
  "JetBrains package SHA256 mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_sha_dir"

mismatched_acceptance_dir="$tmp_root/mismatched-acceptance"
write_jetbrains_artifact "$mismatched_acceptance_dir" \
  "$jetbrains_tag" \
  "$jetbrains_commit" \
  "$jetbrains_package" \
  "$jetbrains_sha256" \
  "m000-0000000000"
assert_fails_with \
  "wrapper and acceptance logs disagree on JetBrains jetbrains_tag" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$mismatched_acceptance_dir"

echo "Verified JetBrains real Skia artifact lock rejection paths."

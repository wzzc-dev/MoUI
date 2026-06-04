#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/moui-skia-artifact-lock.XXXXXX")"
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
lines.append("moui_skia native smoke test passed")
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

provider_info="$(
  python3 - "$repo_root/skia-provider-lock.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
provider = manifest["providers"]["release"]
asset = provider["assets"]["linux"]["Release"]["x64"]["static"]
dynamic_asset = provider["assets"]["linux"]["Release"]["x64"]["dynamic"]
print(provider["owner"])
print(provider["repo"])
print(provider["tag"])
print(provider["release_url"])
print(provider["commit"])
print(asset["name"])
print(asset["sha256"])
print(dynamic_asset["name"])
print(dynamic_asset["sha256"])
PY
)"
release_owner="$(printf '%s\n' "$provider_info" | sed -n '1p')"
release_repo="$(printf '%s\n' "$provider_info" | sed -n '2p')"
release_tag="$(printf '%s\n' "$provider_info" | sed -n '3p')"
release_url="$(printf '%s\n' "$provider_info" | sed -n '4p')"
release_commit="$(printf '%s\n' "$provider_info" | sed -n '5p')"
release_package="$(printf '%s\n' "$provider_info" | sed -n '6p')"
release_sha256="$(printf '%s\n' "$provider_info" | sed -n '7p')"
release_dynamic_package="$(printf '%s\n' "$provider_info" | sed -n '8p')"
release_dynamic_sha256="$(printf '%s\n' "$provider_info" | sed -n '9p')"

write_release_artifact() {
  local dir="$1"
  local owner="${2:-$release_owner}"
  local repo="${3:-$release_repo}"
  local tag="${4:-$release_tag}"
  local url="${5:-$release_url}"
  local commit="${6:-$release_commit}"
  local package="${7:-$release_package}"
  local sha256="${8:-$release_sha256}"
  local link_mode="${9:-static}"
  local acceptance_owner="${10:-$owner}"
  local acceptance_repo="${11:-$repo}"
  local acceptance_tag="${12:-$tag}"
  local acceptance_url="${13:-$url}"
  local acceptance_commit="${14:-$commit}"
  local acceptance_package="${15:-$package}"
  local acceptance_sha256="${16:-$sha256}"
  local acceptance_link_mode="${17:-$link_mode}"
  local library_name="libskia.a"
  local skia_link_flags="/tmp/fake/skia/out/Release-x64/$library_name"
  if [[ "$link_mode" == "dynamic" ]]; then
    library_name="libskia.so"
    skia_link_flags="-L/tmp/fake/skia/out/Release-x64 -lskia -Wl,-rpath,/tmp/fake/skia/out/Release-x64"
  fi

  mkdir -p "$dir"
  printf '%s\n' "Linux release Skia preflight" \
    > "$dir/linux-real-skia-smoke-preflight.log"
  printf '%s\n' \
    "Linux Skia smoke environment:" \
    "  skia_include=/tmp/fake/skia" \
    "  skia_lib_dir=/tmp/fake/skia/out/Release-x64" \
    "  skia_lib=skia" \
    "  skia_link_mode=$link_mode" \
    "  skia_provider=release" \
    "  release_owner=$owner" \
    "  release_repo=$repo" \
    "  release_tag=$tag" \
    "  release_url=$url" \
    "  skia_commit=$commit" \
    "  skia_package=$package" \
    "  skia_package_sha256=$sha256" \
    "  library=$library_name 123 bytes" \
    "  stub_cc_flags=-DMOUI_SKIA_HAS_SKIA -I/tmp/fake/skia" \
    "  cc_link_flags=$skia_link_flags -lstdc++ -lpthread -ldl -lm" \
    > "$dir/linux-real-skia-smoke.log"
  native_log_for "$dir/linux-native-smoke-output.log"
  printf '%s\n' \
    "Linux real Skia acceptance result:" \
    "  smoke_status=0" \
    "  native_smoke_marker=passed" \
    "  native_pkg_restore=passed" \
    "  skia_provider=release" \
    "  skia_link_mode=$acceptance_link_mode" \
    "  release_owner=$acceptance_owner" \
    "  release_repo=$acceptance_repo" \
    "  release_tag=$acceptance_tag" \
    "  release_url=$acceptance_url" \
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
write_release_artifact "$good_dir"
bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$good_dir"

good_dynamic_dir="$tmp_root/good-dynamic"
write_release_artifact "$good_dynamic_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "$release_commit" \
  "$release_dynamic_package" \
  "$release_dynamic_sha256" \
  "dynamic"
bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$good_dynamic_dir"

bad_dry_run_dir="$tmp_root/bad-dry-run"
write_release_artifact "$bad_dry_run_dir"
printf '%s\n' "dry_run_config=true; real Linux smoke was not run" \
  >> "$bad_dry_run_dir/linux-real-skia-smoke.log"
assert_fails_with \
  "artifact wrapper log is from a dry-run configuration" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_dry_run_dir"

bad_native_dry_run_dir="$tmp_root/bad-native-dry-run"
write_release_artifact "$bad_native_dry_run_dir"
printf '%s\n' "Dry run complete; no build was run." \
  >> "$bad_native_dry_run_dir/linux-native-smoke-output.log"
assert_fails_with \
  "artifact native smoke log is from a dry-run configuration" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_native_dry_run_dir"

bad_acceptance_dry_run_dir="$tmp_root/bad-acceptance-dry-run"
write_release_artifact "$bad_acceptance_dry_run_dir"
printf '%s\n' "dry-run=true" \
  >> "$bad_acceptance_dry_run_dir/linux-real-skia-acceptance.log"
assert_fails_with \
  "artifact acceptance log is from a dry-run configuration" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_acceptance_dry_run_dir"

bad_tag_dir="$tmp_root/bad-tag"
write_release_artifact "$bad_tag_dir" "$release_owner" "$release_repo" "dev-bad"
assert_fails_with \
  "release tag mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_tag_dir"

bad_commit_dir="$tmp_root/bad-commit"
write_release_artifact "$bad_commit_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "0123456789abcdef0123456789abcdef01234567"
assert_fails_with \
  "release commit mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_commit_dir"

bad_package_dir="$tmp_root/bad-package"
write_release_artifact "$bad_package_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "$release_commit" \
  "Skia-dev-6d73578a36-linux-Release-ppc64.zip"
assert_fails_with \
  "release package is not locked" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_package_dir"

bad_sha_dir="$tmp_root/bad-sha"
write_release_artifact "$bad_sha_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "$release_commit" \
  "$release_package" \
  "0000000000000000000000000000000000000000000000000000000000000000"
assert_fails_with \
  "release package SHA256 mismatch" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_sha_dir"

mismatched_acceptance_dir="$tmp_root/mismatched-acceptance"
write_release_artifact "$mismatched_acceptance_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "$release_commit" \
  "$release_package" \
  "$release_sha256" \
  "static" \
  "$release_owner" \
  "$release_repo" \
  "dev-bad"
assert_fails_with \
  "wrapper and acceptance logs disagree on release release_tag" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$mismatched_acceptance_dir"

bad_link_mode_dir="$tmp_root/bad-link-mode"
write_release_artifact "$bad_link_mode_dir" \
  "$release_owner" \
  "$release_repo" \
  "$release_tag" \
  "$release_url" \
  "$release_commit" \
  "$release_package" \
  "$release_sha256" \
  "dynamic"
assert_fails_with \
  "release package is not locked" \
  bash "$repo_root/scripts/verify-real-skia-artifact.sh" --platform linux --log-dir "$bad_link_mode_dir"

echo "Verified release real Skia artifact lock rejection paths."

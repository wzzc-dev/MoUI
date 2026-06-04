#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-capability-contract.sh [options]

Checks native/capabilities.json against native MoonBit implementation files,
fallback twins, ownership metadata, and smoke capability markers. This is the
release gate for adding a Canvas, Path, Text, Shader, Filter, GPU, or other
native capability.

Options:
  --manifest PATH       Native capability manifest. Defaults to native/capabilities.json.
  --native-dir PATH     Native package directory. Defaults to native.
  --pkg PATH            Native moon.pkg path. Defaults to native/moon.pkg.
  --ownership PATH      Native ownership manifest. Defaults to native/ownership.json.
  --status-file PATH    Platform status JSON. Defaults to skia-platform-status.json.
  --smoke-source PATH   Native smoke source file or directory. Defaults to scripts/native_smoke.
  -h, --help            Show this help.
EOF
}

manifest="native/capabilities.json"
native_dir="native"
pkg_path="native/moon.pkg"
ownership="native/ownership.json"
status_file="skia-platform-status.json"
smoke_source="scripts/native_smoke"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest="${2:-}"
      shift 2
      ;;
    --native-dir)
      native_dir="${2:-}"
      shift 2
      ;;
    --pkg)
      pkg_path="${2:-}"
      shift 2
      ;;
    --ownership)
      ownership="${2:-}"
      shift 2
      ;;
    --status-file)
      status_file="${2:-}"
      shift 2
      ;;
    --smoke-source)
      smoke_source="${2:-}"
      shift 2
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_repo_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolved_manifest="$(resolve_repo_path "$manifest")"
resolved_native_dir="$(resolve_repo_path "$native_dir")"
resolved_pkg_path="$(resolve_repo_path "$pkg_path")"
resolved_ownership="$(resolve_repo_path "$ownership")"
resolved_status_file="$(resolve_repo_path "$status_file")"
resolved_smoke_source="$(resolve_repo_path "$smoke_source")"

bash "$repo_root/scripts/verify-native-fallback-parity.sh" \
  --native-dir "$resolved_native_dir" \
  --pkg "$resolved_pkg_path"
bash "$repo_root/scripts/verify-native-ownership.sh" --manifest "$resolved_ownership"
bash "$repo_root/scripts/verify-native-ffi-borrows.sh" --native-dir "$resolved_native_dir"
bash "$repo_root/scripts/verify-native-smoke-capabilities.sh" \
  --status-file "$resolved_status_file" \
  --smoke-source "$resolved_smoke_source"

python3 - "$resolved_manifest" "$resolved_native_dir" "$resolved_pkg_path" "$resolved_ownership" "$resolved_status_file" "$resolved_smoke_source" <<'PY'
import json
import pathlib
import re
import sys

manifest_path = pathlib.Path(sys.argv[1])
native_dir = pathlib.Path(sys.argv[2])
pkg_path = pathlib.Path(sys.argv[3])
ownership_path = pathlib.Path(sys.argv[4])
status_path = pathlib.Path(sys.argv[5])
smoke_source_path = pathlib.Path(sys.argv[6])


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def read_json(path: pathlib.Path, label: str) -> dict:
    if not path.is_file():
        fail(f"{label} is missing: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{label} JSON is invalid: {error}")


def parse_target_entries(text: str) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    for match in re.finditer(r'"([^"]+\.mbt)"\s*:\s*\[([^\]]*)\]', text, re.S):
        file_name = match.group(1)
        targets = re.findall(r'"([^"]+)"', match.group(2))
        if file_name in entries:
            fail(f"duplicate target entry in native moon.pkg: {file_name}")
        entries[file_name] = targets
    return entries


def public_functions(text: str) -> set[str]:
    pattern = re.compile(
        r'\bpub(?:\([^)]*\))?\s+(?:extern\s+"[Cc]"\s+)?fn\s+'
        r'((?:[A-Za-z_][A-Za-z0-9_]*::)?[A-Za-z_][A-Za-z0-9_]*)\s*\('
    )
    return set(pattern.findall(text))


manifest = read_json(manifest_path, "native capability manifest")
ownership = read_json(ownership_path, "native ownership manifest")
status = read_json(status_path, "Skia platform status")

if manifest.get("schema_version") != 1:
    fail(f"unsupported native capability schema_version: {manifest.get('schema_version')}")

capabilities = manifest.get("capabilities")
if not isinstance(capabilities, list) or not capabilities:
    fail("native capability manifest is missing capabilities")

if not native_dir.is_dir():
    fail(f"native package directory is missing: {native_dir}")
if not pkg_path.is_file():
    fail(f"native moon.pkg is missing: {pkg_path}")
if smoke_source_path.is_file():
    smoke_source_files = [smoke_source_path]
elif smoke_source_path.is_dir():
    smoke_source_files = sorted(smoke_source_path.glob("*.mbt"))
    if not smoke_source_files:
        fail(f"native smoke source directory has no .mbt files: {smoke_source_path}")
else:
    fail(f"native smoke source is missing: {smoke_source_path}")

target_entries = parse_target_entries(pkg_path.read_text(encoding="utf-8"))
smoke_source = "\n".join(
    path.read_text(encoding="utf-8") for path in smoke_source_files
)

owned_names = {
    str(entry.get("name", "")).strip()
    for section in ("external_wrappers", "regular_objects")
    for entry in ownership.get(section, [])
}
owned_names.discard("")

status_markers = set()
for key in ("native_smoke_capabilities", "native_smoke_conditional_capabilities"):
    entries = status.get(key, [])
    if entries is None:
        entries = []
    if not isinstance(entries, list):
        fail(f"platform status {key} must be a list")
    for entry in entries:
        marker = str(entry.get("marker", "")).strip()
        if marker:
            status_markers.add(marker)

native_files = {path.name for path in native_dir.glob("*_native.mbt")}
fallback_files = {path.name for path in native_dir.glob("*_unavailable.mbt")}
covered_native_files: set[str] = set()
covered_fallback_files: set[str] = set()
seen_ids: set[str] = set()
seen_markers: set[str] = set()

for capability in capabilities:
    if not isinstance(capability, dict):
        fail("native capability entries must be objects")
    capability_id = str(capability.get("id", "")).strip()
    area = str(capability.get("area", "")).strip()
    native_file = str(capability.get("native_file", "")).strip()
    unavailable_file = str(capability.get("unavailable_file", "")).strip()
    rationale = str(capability.get("non_smoke_rationale", "")).strip()
    handles = capability.get("handles", [])
    markers = capability.get("smoke_markers", [])

    if not capability_id:
        fail("native capability is missing id")
    if capability_id in seen_ids:
        fail(f"duplicate native capability id: {capability_id}")
    seen_ids.add(capability_id)
    if not area:
        fail(f"native capability is missing area: {capability_id}")
    if not native_file.endswith("_native.mbt"):
        fail(f"native capability native_file must end with _native.mbt: {capability_id}")
    if not unavailable_file.endswith("_unavailable.mbt"):
        fail(f"native capability unavailable_file must end with _unavailable.mbt: {capability_id}")

    native_path = native_dir / native_file
    unavailable_path = native_dir / unavailable_file
    if not native_path.is_file():
        fail(f"native capability references missing native file: {capability_id}: {native_file}")
    if not unavailable_path.is_file():
        fail(f"native capability references missing fallback file: {capability_id}: {unavailable_file}")

    covered_native_files.add(native_file)
    covered_fallback_files.add(unavailable_file)

    if target_entries.get(native_file) != ["native", "llvm"]:
        fail(f"native capability has wrong native targets in moon.pkg: {capability_id}: {native_file}")
    if target_entries.get(unavailable_file) != ["wasm", "wasm-gc", "js"]:
        fail(f"native capability has wrong fallback targets in moon.pkg: {capability_id}: {unavailable_file}")

    native_exports = public_functions(native_path.read_text(encoding="utf-8"))
    fallback_exports = public_functions(unavailable_path.read_text(encoding="utf-8"))
    missing_fallback_exports = sorted(native_exports - fallback_exports)
    extra_fallback_exports = sorted(fallback_exports - native_exports)
    if missing_fallback_exports:
        fail(
            f"native capability fallback is missing public APIs: {capability_id}: "
            + ", ".join(missing_fallback_exports)
        )
    if extra_fallback_exports:
        fail(
            f"native capability fallback has public APIs absent from native side: {capability_id}: "
            + ", ".join(extra_fallback_exports)
        )

    if not isinstance(handles, list):
        fail(f"native capability handles must be a list: {capability_id}")
    for handle in handles:
        handle_name = str(handle).strip()
        if not handle_name:
            fail(f"native capability has an empty handle entry: {capability_id}")
        if handle_name not in owned_names:
            fail(f"native capability handle is missing from ownership manifest: {capability_id}: {handle_name}")

    if not isinstance(markers, list):
        fail(f"native capability smoke_markers must be a list: {capability_id}")
    if not markers and not rationale:
        fail(f"native capability must list smoke_markers or non_smoke_rationale: {capability_id}")
    for marker in markers:
        marker_text = str(marker).strip()
        if not marker_text:
            fail(f"native capability has an empty smoke marker: {capability_id}")
        if marker_text not in status_markers:
            fail(f"native capability smoke marker is missing from platform status: {capability_id}: {marker_text}")
        if marker_text not in smoke_source:
            fail(f"native capability smoke marker is not emitted by native smoke source: {capability_id}: {marker_text}")
        seen_markers.add(marker_text)

missing_manifest_native = sorted(native_files - covered_native_files)
missing_manifest_fallback = sorted(fallback_files - covered_fallback_files)
if missing_manifest_native:
    fail("native capability manifest does not cover native files: " + ", ".join(missing_manifest_native))
if missing_manifest_fallback:
    fail("native capability manifest does not cover fallback files: " + ", ".join(missing_manifest_fallback))

if not seen_markers:
    fail("native capability manifest does not bind any runtime smoke marker")

print(f"Verified native capability contract in {manifest_path}")
PY

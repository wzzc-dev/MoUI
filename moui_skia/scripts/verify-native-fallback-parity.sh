#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-fallback-parity.sh [options]

Checks that every native-only MoonBit implementation file in the native package
has an unavailable fallback twin and that native/moon.pkg maps each side to the
expected target family.

Options:
  --native-dir PATH     Native package directory. Defaults to native.
  --pkg PATH            Native moon.pkg path. Defaults to <native-dir>/moon.pkg.
  -h, --help            Show this help.
EOF
}

native_dir="native"
pkg_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --native-dir)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --native-dir" >&2
        usage >&2
        exit 2
      fi
      native_dir="$2"
      shift 2
      ;;
    --pkg)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --pkg" >&2
        usage >&2
        exit 2
      fi
      pkg_path="$2"
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

resolved_native_dir="$(resolve_repo_path "$native_dir")"
if [[ -z "$pkg_path" ]]; then
  resolved_pkg_path="$resolved_native_dir/moon.pkg"
else
  resolved_pkg_path="$(resolve_repo_path "$pkg_path")"
fi

python3 - "$resolved_native_dir" "$resolved_pkg_path" <<'PY'
import pathlib
import re
import sys

native_dir = pathlib.Path(sys.argv[1])
pkg_path = pathlib.Path(sys.argv[2])
native_targets = ["native", "llvm"]
fallback_targets = ["wasm", "wasm-gc", "js"]


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def base_name(name: str, suffix: str) -> str:
    return name[: -len(suffix)]


def parse_target_entries(text: str) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    for match in re.finditer(r'"([^"]+\.mbt)"\s*:\s*\[([^\]]*)\]', text, re.S):
      file_name = match.group(1)
      targets = re.findall(r'"([^"]+)"', match.group(2))
      if file_name in entries:
        fail(f"duplicate target entry in native moon.pkg: {file_name}")
      entries[file_name] = targets
    return entries


if not native_dir.is_dir():
    fail(f"native package directory is missing: {native_dir}")
if not pkg_path.is_file():
    fail(f"native package moon.pkg is missing: {pkg_path}")

pkg_text = pkg_path.read_text(encoding="utf-8")
target_entries = parse_target_entries(pkg_text)
if not target_entries:
    fail(f"native package moon.pkg has no target entries: {pkg_path}")

native_files = {path.name for path in native_dir.glob("*_native.mbt")}
fallback_files = {path.name for path in native_dir.glob("*_unavailable.mbt")}
if not native_files:
    fail(f"native package has no *_native.mbt files: {native_dir}")
if not fallback_files:
    fail(f"native package has no *_unavailable.mbt files: {native_dir}")

native_bases = {base_name(name, "_native.mbt") for name in native_files}
fallback_bases = {base_name(name, "_unavailable.mbt") for name in fallback_files}

missing_fallbacks = sorted(native_bases - fallback_bases)
if missing_fallbacks:
    fail("native implementation files are missing unavailable fallbacks: " + ", ".join(missing_fallbacks))

missing_native = sorted(fallback_bases - native_bases)
if missing_native:
    fail("unavailable fallback files are missing native implementations: " + ", ".join(missing_native))

def require_targets(file_name: str, expected: list[str]) -> None:
    actual = target_entries.get(file_name)
    if actual is None:
        fail(f"native moon.pkg is missing target mapping for {file_name}")
    if actual != expected:
        fail(
            f"native moon.pkg has wrong targets for {file_name}: "
            f"expected={expected} actual={actual}"
        )


for base in sorted(native_bases):
    require_targets(f"{base}_native.mbt", native_targets)
    require_targets(f"{base}_unavailable.mbt", fallback_targets)

target_specific_entries = {
    name for name in target_entries if name.endswith("_native.mbt") or name.endswith("_unavailable.mbt")
}
missing_files = sorted(
    name for name in target_specific_entries if not (native_dir / name).is_file()
)
if missing_files:
    fail("native moon.pkg target entries reference missing files: " + ", ".join(missing_files))

unpaired_entries = sorted(target_specific_entries - native_files - fallback_files)
if unpaired_entries:
    fail("native moon.pkg target entries are not native/fallback implementation files: " + ", ".join(unpaired_entries))

print(f"Verified native fallback parity in {native_dir}")
PY

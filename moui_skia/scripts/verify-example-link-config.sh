#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-example-link-config.sh [options]

Checks that checked-in example moon.pkg files use build-script link variables
instead of hardcoded Skia provider cache paths.

Options:
  --build-script PATH   Build script path. Defaults to build.js.
  --examples-dir PATH   Examples directory. Defaults to examples.
  -h, --help            Show this help.
EOF
}

build_script="build.js"
examples_dir="examples"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-script)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --build-script" >&2
        usage >&2
        exit 2
      fi
      build_script="$2"
      shift 2
      ;;
    --examples-dir)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --examples-dir" >&2
        usage >&2
        exit 2
      fi
      examples_dir="$2"
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

resolved_build_script="$(resolve_repo_path "$build_script")"
resolved_examples_dir="$(resolve_repo_path "$examples_dir")"

python3 - "$resolved_build_script" "$resolved_examples_dir" <<'PY'
import pathlib
import re
import sys

build_script = pathlib.Path(sys.argv[1])
examples_dir = pathlib.Path(sys.argv[2])

required_example_vars = {
    "triangle_window_macos/moon.pkg": "MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS",
    "macos_hello_triangle/moon.pkg": "MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS",
}
forbidden_example_patterns = [
    re.compile(r"\.skia-cache"),
    re.compile(r"\bm\d+-[0-9a-f]{8,}\b"),
    re.compile(r"package/out"),
]


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


if not build_script.is_file():
    fail(f"build script is missing: {build_script}")
if not examples_dir.is_dir():
    fail(f"examples directory is missing: {examples_dir}")

build_text = build_script.read_text(encoding="utf-8")
for variable in required_example_vars.values():
    if build_text.count(variable) < 2:
        fail(f"build script does not emit {variable} in both fallback and configured paths")
if "macosExampleLinkFlags" not in build_text:
    fail("build script is missing macOS example link flag helper")
for framework in (
    "QuartzCore",
    "AppKit",
    "Metal",
    "CoreVideo",
    "IOSurface",
):
    if framework not in build_text:
        fail(f"build script is missing macOS example framework: {framework}")

for relative_pkg, variable in required_example_vars.items():
    pkg_path = examples_dir / relative_pkg
    if not pkg_path.is_file():
        fail(f"example moon.pkg is missing: {pkg_path}")
    expected = f'"cc-link-flags": "${{build.{variable}}}"'
    pkg_text = pkg_path.read_text(encoding="utf-8")
    compact_text = re.sub(r"\s+", "", pkg_text)
    compact_expected = re.sub(r"\s+", "", expected)
    if compact_expected not in compact_text:
        fail(f"example moon.pkg does not use build variable {variable}: {pkg_path}")

for pkg_path in sorted(examples_dir.glob("*/moon.pkg")):
    pkg_text = pkg_path.read_text(encoding="utf-8")
    for pattern in forbidden_example_patterns:
        if pattern.search(pkg_text):
            fail(f"example moon.pkg contains hardcoded Skia provider path text: {pkg_path}")

print(f"Verified example link configuration in {examples_dir}")
PY

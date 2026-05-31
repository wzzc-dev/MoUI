#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-smoke-capabilities.sh [options]

Checks that every native_smoke_capabilities marker in skia-platform-status.json
is emitted by scripts/native_smoke/main.mbt and remains listed by both native
smoke log verifier fallback marker tables.

Options:
  --status-file PATH                 Platform status JSON file. Defaults to skia-platform-status.json.
  --smoke-source PATH                Native smoke MoonBit source. Defaults to scripts/native_smoke/main.mbt.
  --unix-log-verifier PATH           Unix log verifier. Defaults to scripts/verify-native-smoke-log.sh.
  --powershell-log-verifier PATH     PowerShell log verifier. Defaults to scripts/verify-native-smoke-log.ps1.
  -h, --help                         Show this help.
EOF
}

status_file="skia-platform-status.json"
smoke_source="scripts/native_smoke/main.mbt"
unix_log_verifier="scripts/verify-native-smoke-log.sh"
powershell_log_verifier="scripts/verify-native-smoke-log.ps1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status-file)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --status-file" >&2
        usage >&2
        exit 2
      fi
      status_file="$2"
      shift 2
      ;;
    --smoke-source)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --smoke-source" >&2
        usage >&2
        exit 2
      fi
      smoke_source="$2"
      shift 2
      ;;
    --unix-log-verifier)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --unix-log-verifier" >&2
        usage >&2
        exit 2
      fi
      unix_log_verifier="$2"
      shift 2
      ;;
    --powershell-log-verifier)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --powershell-log-verifier" >&2
        usage >&2
        exit 2
      fi
      powershell_log_verifier="$2"
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

resolved_status_file="$(resolve_repo_path "$status_file")"
resolved_smoke_source="$(resolve_repo_path "$smoke_source")"
resolved_unix_log_verifier="$(resolve_repo_path "$unix_log_verifier")"
resolved_powershell_log_verifier="$(resolve_repo_path "$powershell_log_verifier")"

python3 - "$resolved_status_file" "$resolved_smoke_source" "$resolved_unix_log_verifier" "$resolved_powershell_log_verifier" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
smoke_source_path = pathlib.Path(sys.argv[2])
unix_log_verifier_path = pathlib.Path(sys.argv[3])
powershell_log_verifier_path = pathlib.Path(sys.argv[4])

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

for path in (
    status_path,
    smoke_source_path,
    unix_log_verifier_path,
    powershell_log_verifier_path,
):
    if not path.is_file():
        fail(f"required capability proof input is missing: {path}")

try:
    status = json.loads(status_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as error:
    fail(f"Skia platform status JSON is invalid: {error}")

capabilities = status.get("native_smoke_capabilities")
if not isinstance(capabilities, list) or not capabilities:
    fail("platform status is missing native_smoke_capabilities")

smoke_source = smoke_source_path.read_text(encoding="utf-8")
unix_log_verifier = unix_log_verifier_path.read_text(encoding="utf-8")
powershell_log_verifier = powershell_log_verifier_path.read_text(encoding="utf-8")

seen_markers: set[str] = set()
missing_from_source: list[str] = []
missing_from_unix_log_verifier: list[str] = []
missing_from_powershell_log_verifier: list[str] = []

for capability in capabilities:
    if not isinstance(capability, dict):
        fail("native_smoke_capabilities entries must be objects")
    marker = str(capability.get("marker", "")).strip()
    capability_id = str(capability.get("id", "")).strip()
    if not marker:
        fail(f"native smoke capability is missing marker: {capability_id}")
    if marker in seen_markers:
        fail(f"duplicate native smoke capability marker: {marker}")
    seen_markers.add(marker)
    if marker not in smoke_source:
        missing_from_source.append(marker)
    if marker not in unix_log_verifier:
        missing_from_unix_log_verifier.append(marker)
    if marker not in powershell_log_verifier:
        missing_from_powershell_log_verifier.append(marker)

if missing_from_source:
    fail(
        "native smoke capabilities are not emitted by "
        f"{smoke_source_path}: " + ", ".join(missing_from_source)
    )
if missing_from_unix_log_verifier:
    fail(
        "native smoke capabilities are missing from Unix log verifier fallback markers: "
        + ", ".join(missing_from_unix_log_verifier)
    )
if missing_from_powershell_log_verifier:
    fail(
        "native smoke capabilities are missing from PowerShell log verifier fallback markers: "
        + ", ".join(missing_from_powershell_log_verifier)
    )

print(
    "Verified native smoke capability markers across "
    f"{status_path}, {smoke_source_path}, {unix_log_verifier_path}, "
    f"and {powershell_log_verifier_path}."
)
PY

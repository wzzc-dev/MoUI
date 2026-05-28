#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/accept-platform-status.sh --platform NAME --log-dir PATH [options]

Marks a platform accepted in skia-platform-status.json only after the real-Skia
artifact bundle verifies and skia-revision.txt matches the acceptance log. This
is the Unix shell equivalent of scripts/accept-platform-status.ps1.

Options:
  --platform NAME       linux, macos, or windows.
  --log-dir PATH        Directory containing platform real-smoke logs.
  --status-file PATH    Status JSON to update. Defaults to skia-platform-status.json.
  --revision-file PATH  Revision file to verify. Defaults to skia-revision.txt.
  --artifact-label TEXT Label/path to record as accepted_artifact.
                        Defaults to --log-dir.
  --require-commit      Require a full skia_commit in artifact logs.
                        Linux always requires this.
  -h, --help            Show this help.
EOF
}

platform=""
log_dir=""
status_file="skia-platform-status.json"
revision_file="skia-revision.txt"
artifact_label=""
require_commit=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    --log-dir)
      log_dir="${2:-}"
      shift 2
      ;;
    --status-file)
      status_file="${2:-}"
      shift 2
      ;;
    --revision-file)
      revision_file="${2:-}"
      shift 2
      ;;
    --artifact-label)
      artifact_label="${2:-}"
      shift 2
      ;;
    --require-commit)
      require_commit=1
      shift
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

case "$platform" in
  linux|macos|windows) ;;
  "")
    echo "--platform is required" >&2
    usage >&2
    exit 2
    ;;
  *)
    echo "unsupported platform: $platform" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$log_dir" ]]; then
  echo "--log-dir is required" >&2
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_repo_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolved_log_dir="$(resolve_repo_path "$log_dir")"
resolved_status_file="$(resolve_repo_path "$status_file")"
resolved_revision_file="$(resolve_repo_path "$revision_file")"
acceptance_log="$resolved_log_dir/$platform-real-skia-acceptance.log"

if [[ ! -f "$resolved_status_file" ]]; then
  echo "Skia platform status file is missing: $resolved_status_file" >&2
  exit 1
fi

artifact_args=(--platform "$platform" --log-dir "$resolved_log_dir")
if [[ "$platform" == "linux" || $require_commit -eq 1 ]]; then
  artifact_args+=(--require-commit)
fi
bash "$repo_root/scripts/verify-real-skia-artifact.sh" "${artifact_args[@]}"

if [[ ! -f "$acceptance_log" ]]; then
  echo "platform acceptance log is missing after artifact verification: $acceptance_log" >&2
  exit 1
fi

bash "$repo_root/scripts/verify-skia-revision-pin.sh" \
  "$acceptance_log" \
  --revision-file "$resolved_revision_file"

if [[ -z "$artifact_label" ]]; then
  artifact_label="$log_dir"
fi

python3 - \
  "$resolved_status_file" \
  "$platform" \
  "$acceptance_log" \
  "$artifact_label" <<'PY'
import json
import pathlib
import re
import sys

status_path = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
acceptance_log = pathlib.Path(sys.argv[3])
artifact_label = sys.argv[4]

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

try:
    status = json.loads(status_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as error:
    fail(f"Skia platform status JSON is invalid: {error}")

if status.get("schema_version") != 1:
    fail(f"unsupported Skia platform status schema_version: {status.get('schema_version')}")

platforms = status.get("platforms")
if not isinstance(platforms, dict) or platform not in platforms:
    fail(f"platform status is missing required platform: {platform}")

accepted_commit = ""
for line in acceptance_log.read_text(encoding="utf-8").splitlines():
    match = re.fullmatch(r"\s*skia_commit=([0-9a-fA-F]{40})\s*", line)
    if match:
        accepted_commit = match.group(1).lower()

if not accepted_commit:
    fail(f"platform acceptance log is missing a full 40-character skia_commit hash: {acceptance_log}")

entry = platforms[platform]
entry["accepted"] = True
entry["state"] = "accepted"
entry["accepted_artifact"] = artifact_label
entry["accepted_commit"] = accepted_commit
entry["next_step"] = (
    "Keep running real Skia smoke for this platform and verify each run "
    f"against the pinned Skia revision {accepted_commit}."
)

status_path.write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
PY

bash "$repo_root/scripts/verify-platform-status.sh" \
  --status-file "$resolved_status_file" \
  --revision-file "$resolved_revision_file"

echo "Marked $platform accepted in $resolved_status_file using artifact $artifact_label."

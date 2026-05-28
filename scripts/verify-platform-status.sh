#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-platform-status.sh [options]

Checks skia-platform-status.json against skia-revision.txt so the repository
does not claim accepted real-Skia platforms without a pinned revision and
recorded artifact evidence.

Options:
  --status-file PATH    Platform status JSON file. Defaults to skia-platform-status.json.
  --revision-file PATH  Skia revision file. Defaults to skia-revision.txt.
  -h, --help            Show this help.
EOF
}

status_file="skia-platform-status.json"
revision_file="skia-revision.txt"

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
    --revision-file)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --revision-file" >&2
        usage >&2
        exit 2
      fi
      revision_file="$2"
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
resolved_revision_file="$(resolve_repo_path "$revision_file")"

python3 - "$resolved_status_file" "$resolved_revision_file" <<'PY'
import json
import pathlib
import re
import sys

status_path = pathlib.Path(sys.argv[1])
revision_path = pathlib.Path(sys.argv[2])

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

if not status_path.is_file():
    fail(f"Skia platform status file is missing: {status_path}")

if not revision_path.is_file():
    fail(f"Skia revision file is missing: {revision_path}")

try:
    status = json.loads(status_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as error:
    fail(f"Skia platform status JSON is invalid: {error}")

revision = ""
for line in revision_path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if stripped and not stripped.startswith("#"):
        revision = stripped
        break

if status.get("schema_version") != 1:
    fail(f"unsupported Skia platform status schema_version: {status.get('schema_version')}")

if status.get("revision_file") != revision_path.name:
    fail(
        "status revision_file does not match requested revision file: "
        f"status={status.get('revision_file')} revision={revision_path.name}"
    )

if not revision:
    fail("Skia revision file does not contain a revision")

platforms = ("linux", "macos", "windows")
platform_entries = status.get("platforms")
if not isinstance(platform_entries, dict):
    fail("platform status is missing platforms object")

for platform in platforms:
    if platform not in platform_entries:
        fail(f"platform status is missing required platform: {platform}")

accepted_platforms = []
for platform in platforms:
    entry = platform_entries[platform]
    if not isinstance(entry, dict):
        fail(f"platform status entry is not an object: {platform}")
    if "accepted" not in entry:
        fail(f"platform status is missing accepted flag: {platform}")
    if not isinstance(entry["accepted"], bool):
        fail(f"platform accepted flag must be boolean: {platform}")
    if not entry.get("state"):
        fail(f"platform status is missing state: {platform}")
    if len(entry.get("required_artifact_logs") or []) < 3:
        fail(f"platform status does not list enough artifact logs: {platform}")
    if not entry.get("required_verifier"):
        fail(f"platform status is missing required verifier: {platform}")
    if not entry.get("next_step"):
        fail(f"platform status is missing next step: {platform}")

    if entry["accepted"]:
        accepted_platforms.append(platform)
        if not entry.get("accepted_artifact"):
            fail(f"accepted platform is missing accepted_artifact: {platform}")
        if not re.fullmatch(r"[0-9a-fA-F]{40}", str(entry.get("accepted_commit") or "")):
            fail(f"accepted platform is missing accepted_commit: {platform}")
    elif entry.get("accepted_artifact") is not None:
        fail(f"unaccepted platform must not record accepted_artifact: {platform}")
    elif entry.get("accepted_commit") is not None:
        fail(f"unaccepted platform must not record accepted_commit: {platform}")

if revision == "main" and accepted_platforms:
    fail(
        "platforms cannot be accepted while skia-revision.txt is still main: "
        + ", ".join(accepted_platforms)
    )

if revision != "main" and not re.fullmatch(r"[0-9a-fA-F]{40}", revision):
    fail(f"Skia revision must be main or a full 40-character commit: {revision}")

for platform in accepted_platforms:
    accepted_commit = platform_entries[platform]["accepted_commit"].lower()
    if accepted_commit != revision.lower():
        fail(
            "accepted platform commit does not match pinned revision: "
            f"platform={platform} accepted_commit={accepted_commit} revision={revision}"
        )

linux = platform_entries["linux"]
windows = platform_entries["windows"]

if not linux.get("first_acceptance_platform"):
    fail("Linux must remain the first acceptance platform until the initial source-built pin is established")

if not linux.get("source_build"):
    fail("Linux status must keep source_build=true for first acceptance")

if windows.get("source_build"):
    fail("Windows status must not claim source_build=true until a repeatable Windows Skia build path exists")

print(f"Verified Skia platform status in {status_path} with revision {revision}.")
PY

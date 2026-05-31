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
  --provider-lock PATH   Skia provider lock JSON. Defaults to skia-provider-lock.json.
  -h, --help            Show this help.
EOF
}

status_file="skia-platform-status.json"
revision_file="skia-revision.txt"
provider_lock="skia-provider-lock.json"

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
    --provider-lock)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --provider-lock" >&2
        usage >&2
        exit 2
      fi
      provider_lock="$2"
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
resolved_provider_lock="$(resolve_repo_path "$provider_lock")"

python3 - "$resolved_status_file" "$resolved_revision_file" "$resolved_provider_lock" "$repo_root" <<'PY'
import json
import pathlib
import re
import sys

status_path = pathlib.Path(sys.argv[1])
revision_path = pathlib.Path(sys.argv[2])
provider_lock_path = pathlib.Path(sys.argv[3])
repo_root = pathlib.Path(sys.argv[4])

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

try:
    provider_lock = json.loads(provider_lock_path.read_text(encoding="utf-8"))
except FileNotFoundError:
    provider_lock = {}
except json.JSONDecodeError as error:
    fail(f"Skia provider lock JSON is invalid: {error}")

jetbrains = provider_lock.get("providers", {}).get("jetbrains", {})
jetbrains_commit = str(jetbrains.get("commit", "")).lower()
jetbrains_tag = str(jetbrains.get("tag", ""))

revision = ""
for line in revision_path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if stripped and not stripped.startswith("#"):
        revision = stripped
        break

schema_version = status.get("schema_version")
if schema_version not in (1, 2, 3, 4):
    fail(f"unsupported Skia platform status schema_version: {status.get('schema_version')}")

if schema_version >= 4:
    gates = status.get("ci_gates")
    if not isinstance(gates, list):
        fail("schema v4 platform status is missing ci_gates list")
    required_gate_ids = {
        "moonbit.fmt-check",
        "moonbit.check-test",
        "native.smoke-build",
        "native.ownership",
        "native.ffi-borrows",
        "platform.status",
        "artifact.native-smoke-log",
        "artifact.real-skia",
    }
    seen_gate_ids = set()
    seen_gate_commands = set()
    seen_gate_areas = set()

    def ci_gate_script_paths(command):
        normalized = command.replace("\\", "/")
        for token in re.split(r"[\s;&|]+", normalized):
            token = token.strip().strip("'\"")
            while token.startswith("./"):
                token = token[2:]
            if token.startswith("scripts/") and token.endswith((".sh", ".ps1")):
                yield token

    for gate in gates:
        if not isinstance(gate, dict):
            fail("ci_gates entries must be objects")
        gate_id = str(gate.get("id", "")).strip()
        area = str(gate.get("area", "")).strip()
        unix_command = str(gate.get("unix_command", "")).strip()
        powershell_command = str(gate.get("powershell_command", "")).strip()
        if not gate_id:
            fail("CI gate is missing id")
        if not area:
            fail(f"CI gate is missing area: {gate_id}")
        if not unix_command and not powershell_command:
            fail(f"CI gate is missing verifier command: {gate_id}")
        if gate_id in seen_gate_ids:
            fail(f"duplicate CI gate id: {gate_id}")
        for command in (unix_command, powershell_command):
            if command:
                command_key = (area, command)
                if command_key in seen_gate_commands:
                    fail(f"duplicate CI gate command: {command}")
                seen_gate_commands.add(command_key)
                for script_path in ci_gate_script_paths(command):
                    if not (repo_root / script_path).is_file():
                        fail(
                            "CI gate references missing verifier script: "
                            f"{gate_id}: {script_path}"
                        )
        seen_gate_ids.add(gate_id)
        seen_gate_areas.add(area)
    missing_gate_ids = sorted(required_gate_ids - seen_gate_ids)
    if missing_gate_ids:
        fail("CI gate coverage is missing ids: " + ", ".join(missing_gate_ids))
    missing_gate_areas = sorted({"MoonBit", "NativeSmoke", "FFI", "PlatformStatus", "Artifact"} - seen_gate_areas)
    if missing_gate_areas:
        fail("CI gate coverage is missing areas: " + ", ".join(missing_gate_areas))

if schema_version >= 3:
    capabilities = status.get("native_smoke_capabilities")
    if not isinstance(capabilities, list):
        fail("schema v3 platform status is missing native_smoke_capabilities list")
    required_capability_ids = {
        "surface.descriptor",
        "canvas.state",
        "canvas.command-replay",
        "shader.draw",
        "filter.layer",
        "path.geometry",
        "surface.readback",
        "surface.bounded-readback",
        "surface.bounded-snapshot",
        "image.encode-png",
        "image.decode",
        "codec.metadata",
        "bitmap.decode-readback",
        "text.font-spacing",
        "text.measure",
        "text.glyph-count",
        "text.glyph-id",
        "text.glyph-width",
        "text.glyph-position",
        "text.glyph-x-position",
        "text.glyph-bounds",
        "text.bounds",
        "fontmgr.family-count",
        "fontmgr.family-name",
        "fontmgr.typeface-family",
        "fontmgr.character-fallback",
    }
    seen_ids = set()
    seen_markers = set()
    seen_areas = set()
    for capability in capabilities:
        if not isinstance(capability, dict):
            fail("native_smoke_capabilities entries must be objects")
        capability_id = str(capability.get("id", "")).strip()
        area = str(capability.get("area", "")).strip()
        marker = str(capability.get("marker", "")).strip()
        if not capability_id:
            fail("native smoke capability is missing id")
        if not area:
            fail(f"native smoke capability is missing area: {capability_id}")
        if not marker:
            fail(f"native smoke capability is missing marker: {capability_id}")
        if capability_id in seen_ids:
            fail(f"duplicate native smoke capability id: {capability_id}")
        if marker in seen_markers:
            fail(f"duplicate native smoke capability marker: {marker}")
        seen_ids.add(capability_id)
        seen_markers.add(marker)
        seen_areas.add(area)
    missing_ids = sorted(required_capability_ids - seen_ids)
    if missing_ids:
        fail("native smoke capability coverage is missing ids: " + ", ".join(missing_ids))
    missing_areas = sorted({"Surface", "Canvas", "Shader", "Filter", "Path", "Image", "Text", "FontMgr"} - seen_areas)
    if missing_areas:
        fail("native smoke capability coverage is missing areas: " + ", ".join(missing_areas))

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
        accepted_provider = entry.get("accepted_provider") if schema_version >= 2 else "source"
        accepted_version = entry.get("accepted_version") if schema_version >= 2 else revision
        if accepted_provider not in ("source", "jetbrains"):
            fail(f"accepted platform has unsupported accepted_provider: {platform}")
        if not accepted_version:
            fail(f"accepted platform is missing accepted_version: {platform}")
        entry["__accepted_provider"] = accepted_provider
        entry["__accepted_version"] = accepted_version
    elif entry.get("accepted_artifact") is not None:
        fail(f"unaccepted platform must not record accepted_artifact: {platform}")
    elif entry.get("accepted_commit") is not None:
        fail(f"unaccepted platform must not record accepted_commit: {platform}")
    if not entry["accepted"] and schema_version >= 2 and entry.get("accepted_provider") is not None:
        fail(f"unaccepted platform must not record accepted_provider: {platform}")
    if not entry["accepted"] and schema_version >= 2 and entry.get("accepted_version") is not None:
        fail(f"unaccepted platform must not record accepted_version: {platform}")

source_accepted = [p for p in accepted_platforms if platform_entries[p].get("__accepted_provider") == "source"]
if revision == "main" and source_accepted:
    fail(
        "source platforms cannot be accepted while skia-revision.txt is still main: "
        + ", ".join(source_accepted)
    )

if revision != "main" and not re.fullmatch(r"[0-9a-fA-F]{40}", revision):
    fail(f"Skia revision must be main or a full 40-character commit: {revision}")

for platform in accepted_platforms:
    accepted_commit = platform_entries[platform]["accepted_commit"].lower()
    accepted_provider = platform_entries[platform]["__accepted_provider"]
    accepted_version = str(platform_entries[platform]["__accepted_version"])
    if accepted_provider == "source" and accepted_commit != revision.lower():
        fail(
            "accepted platform commit does not match pinned revision: "
            f"platform={platform} accepted_commit={accepted_commit} revision={revision}"
        )
    if accepted_provider == "source" and accepted_version != revision:
        fail(
            "accepted source platform version does not match pinned revision: "
            f"platform={platform} accepted_version={accepted_version} revision={revision}"
        )
    if accepted_provider == "jetbrains":
        if not jetbrains_commit or not jetbrains_tag:
            fail("JetBrains provider lock is missing tag or commit")
        if accepted_commit != jetbrains_commit:
            fail(
                "accepted JetBrains platform commit does not match provider lock: "
                f"platform={platform} accepted_commit={accepted_commit} jetbrains_commit={jetbrains_commit}"
            )
        if accepted_version != jetbrains_tag:
            fail(
                "accepted JetBrains platform version does not match provider lock tag: "
                f"platform={platform} accepted_version={accepted_version} jetbrains_tag={jetbrains_tag}"
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

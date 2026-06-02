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
  --status-doc PATH     Platform status Markdown file. Defaults to SKIA_PLATFORM_STATUS.md.
  -h, --help            Show this help.
EOF
}

status_file="skia-platform-status.json"
revision_file="skia-revision.txt"
provider_lock="skia-provider-lock.json"
status_doc="SKIA_PLATFORM_STATUS.md"
status_doc_explicit=0

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
    --status-doc)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --status-doc" >&2
        usage >&2
        exit 2
      fi
      status_doc="$2"
      status_doc_explicit=1
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
resolved_status_doc="$(resolve_repo_path "$status_doc")"

python3 - "$resolved_status_file" "$resolved_revision_file" "$resolved_provider_lock" "$repo_root" "$resolved_status_doc" "$status_doc_explicit" <<'PY'
import json
import pathlib
import re
import sys

status_path = pathlib.Path(sys.argv[1])
revision_path = pathlib.Path(sys.argv[2])
provider_lock_path = pathlib.Path(sys.argv[3])
repo_root = pathlib.Path(sys.argv[4])
status_doc_path = pathlib.Path(sys.argv[5])
status_doc_explicit = sys.argv[6] == "1"

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
        "moonbit.all-target-check",
        "native.smoke-build",
        "native.smoke-capability-sync",
        "native.capability-contract",
        "native.ownership",
        "native.ffi-borrows",
        "native.fallback-parity",
        "platform.status",
        "artifact.native-smoke-log",
        "artifact.real-skia",
    }
    seen_gate_ids = set()
    seen_gate_commands = set()
    seen_gate_areas = set()

    evidence_files = status.get("ci_gate_evidence_files")
    if not isinstance(evidence_files, list) or not evidence_files:
        fail("schema v4 platform status is missing ci_gate_evidence_files list")
    required_evidence_files = {
        ".github/workflows/fallback.yml",
        ".github/workflows/linux-real-skia-smoke.yml",
        ".github/workflows/macos-real-skia-smoke.yml",
        ".github/workflows/windows-real-skia-smoke.yml",
        ".github/workflows/real-skia-acceptance.yml",
        "scripts/check-fallback.ps1",
    }
    seen_evidence_files = set()
    evidence_parts = []

    def normalize_repo_relative_path(path):
        normalized = str(path).strip().replace("\\", "/")
        while normalized.startswith("./"):
            normalized = normalized[2:]
        if not normalized:
            fail("CI gate evidence file is missing path")
        if normalized.startswith("/") or ".." in pathlib.PurePosixPath(normalized).parts:
            fail(f"CI gate evidence file must be repo-relative: {path}")
        return normalized

    for evidence_file in evidence_files:
        evidence_path = normalize_repo_relative_path(evidence_file)
        if evidence_path in seen_evidence_files:
            fail(f"duplicate CI gate evidence file: {evidence_path}")
        resolved_evidence_path = repo_root / evidence_path
        if not resolved_evidence_path.is_file():
            fail(f"CI gate evidence file is missing: {evidence_path}")
        seen_evidence_files.add(evidence_path)
        evidence_parts.append(resolved_evidence_path.read_text(encoding="utf-8"))

    missing_evidence_files = sorted(required_evidence_files - seen_evidence_files)
    if missing_evidence_files:
        fail("CI gate evidence is missing files: " + ", ".join(missing_evidence_files))

    evidence_corpus = "\n".join(evidence_parts).replace("\\", "/")
    evidence_compact = re.sub(r"\s+", " ", evidence_corpus)

    def ci_gate_script_paths(command):
        normalized = command.replace("\\", "/")
        for token in re.split(r"[\s;&|]+", normalized):
            token = token.strip().strip("'\"")
            while token.startswith("./"):
                token = token[2:]
            if token.startswith("scripts/") and token.endswith((".sh", ".ps1")):
                yield token

    def ci_gate_evidence_terms(command):
        script_paths = list(ci_gate_script_paths(command))
        if script_paths:
            normalized = command.replace("\\", "/")
            option_terms = []
            for token in re.split(r"[\s;&|]+", normalized):
                token = token.strip().strip("'\"")
                if token.startswith("-") and token not in {"-n"}:
                    option_terms.append(token)
            return script_paths + option_terms
        normalized = command.replace("\\", "/")
        terms = []
        for part in re.split(r"\s*(?:&&|;|\|\|?|\n)\s*", normalized):
            term = re.sub(r"\s+", " ", part.strip())
            if term:
                terms.append(term)
        return terms

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
                for evidence_term in ci_gate_evidence_terms(command):
                    if (
                        evidence_term not in evidence_corpus
                        and evidence_term not in evidence_compact
                    ):
                        fail(
                            "CI gate evidence is missing command wiring: "
                            f"{gate_id}: {evidence_term}"
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
        "surface.target-factory-raster",
        "surface.target-factory-unsupported",
        "canvas.state",
        "canvas.clip",
        "canvas.command-replay",
        "pipeline.shaped-glyph-run-command",
        "pipeline.shader-cache-resources",
        "pipeline.shader-cache-misses",
        "pipeline.shader-cache-hits",
        "pipeline.path-cache-resources",
        "pipeline.path-cache-misses",
        "pipeline.path-cache-hits",
        "pipeline.text-run-cache-resources",
        "pipeline.text-run-cache-misses",
        "pipeline.text-run-cache-hits",
        "pipeline.font-cache-resources",
        "pipeline.font-cache-misses",
        "pipeline.font-cache-hits",
        "pipeline.color-filter-cache-resources",
        "pipeline.color-filter-cache-misses",
        "pipeline.color-filter-cache-hits",
        "pipeline.image-filter-cache-resources",
        "pipeline.image-filter-cache-misses",
        "pipeline.image-filter-cache-hits",
        "pipeline.mask-filter-cache-resources",
        "pipeline.mask-filter-cache-misses",
        "pipeline.mask-filter-cache-hits",
        "pipeline.resource-plan",
        "pipeline.frame-resource-plan",
        "pipeline.frame-validation",
        "pipeline.frame-cacheable-subplan",
        "pipeline.frame-uncacheable-subplan",
        "pipeline.frame-unbalanced-validation",
        "pipeline.target-identity-validation",
        "pipeline.target-resource-binding",
        "pipeline.frame-present",
        "pipeline.frame-submission-resource-plan",
        "pipeline.frame-submission-cacheable-subplan",
        "pipeline.frame-submission-uncacheable-subplan",
        "pipeline.frame-submission-preflight-missing",
        "pipeline.frame-submission-preflight-cached",
        "pipeline.frame-submission-cache-resources",
        "pipeline.frame-finalization-resource-plan",
        "pipeline.frame-finalization-cacheable-subplan",
        "pipeline.frame-finalization-uncacheable-subplan",
        "pipeline.frame-finalization-preflight-missing",
        "pipeline.frame-finalization-preflight-cached",
        "pipeline.frame-finalization-cache-resources",
        "pipeline.frame-missing-present-validation",
        "pipeline.frame-missing-finalization-validation",
        "pipeline.frame-touched-bounds",
        "pipeline.frame-cache-resources",
        "pipeline.native-replay-resource-stats-caches",
        "pipeline.native-replay-resource-stats-resources",
        "pipeline.resource-cache",
        "pipeline.resource-cache-preflight-missing",
        "pipeline.resource-cache-preflight-cached",
        "pipeline.resource-cache-plan-coverage",
        "pipeline.resource-cache-eviction",
        "pipeline.resource-cache-hits",
        "pipeline.resource-cache-misses",
        "pipeline.resource-cache-byte-size",
        "gpu.context-resource-plan",
        "gpu.context-key-variation",
        "gpu.frame-context-validation",
        "gpu.present-resource-plan",
        "gpu.finalization-resource-plan",
        "gpu.frame-finalization-resource-plan",
        "gpu.frame-finalization-gpu-resources",
        "gpu.frame-submission-resource-plan",
        "gpu.frame-submission-gpu-resources",
        "surface.target-resource-plan",
        "surface.target-cache-resources",
        "surface.window-target-resource-plan",
        "surface.window-physical-width",
        "surface.window-frame-pacing",
        "surface.window-present-mode-key",
        "surface.finalization-resource-plan",
        "surface.finalization-key",
        "surface.flush-and-submit",
        "shader.draw",
        "shader.resource-plan",
        "filter.layer",
        "filter.resource-plan",
        "path.geometry",
        "surface.readback",
        "surface.readback-height",
        "surface.readback-row-bytes",
        "surface.bounded-readback",
        "surface.bounded-readback-height",
        "surface.bounded-snapshot",
        "surface.bounded-snapshot-height",
        "image.encode-png",
        "image.decode",
        "image.decode-height",
        "image.render-command-replay",
        "image.render-command-count",
        "image.render-command-resource-plan",
        "image.render-command-cache-resources",
        "image.render-command-cache-misses",
        "image.render-command-cache-hits",
        "codec.metadata",
        "codec.width",
        "codec.height",
        "bitmap.decode-readback",
        "bitmap.decode-readback-height",
        "text.font-spacing",
        "text.font-resource-plan",
        "text.text-run-resource-plan",
        "text.text-run-range",
        "text.measured-run-resource-plan",
        "text.measured-run-key",
        "text.shaped-glyph-run-resource-plan",
        "text.shaped-glyph-run-key",
        "text.measure",
        "text.glyph-count",
        "text.glyph-id",
        "text.glyph-width",
        "text.glyph-position",
        "text.glyph-x-position",
        "text.glyph-bounds",
        "text.bounds",
        "text.shaper-availability",
        "text.default-typeface-availability",
        "fontmgr.family-count",
        "fontmgr.family-name",
        "fontmgr.typeface-family",
        "fontmgr.character-fallback",
        "fontmgr.fallback-key",
        "fontmgr.fallback-family-name",
        "fontmgr.fallback-match-key",
        "fontmgr.fallback-match-resource-plan",
        "fontmgr.fallback-resolution-key",
        "fontmgr.fallback-resolution-resource-plan",
        "fontmgr.fallback-resolution-bridge",
        "fontmgr.fallback-resolution-bridge-cache-resources",
        "fontmgr.fallback-resource-plan",
        "fontmgr.fallback-font-resource-plan",
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
    required_areas = {
        "Surface",
        "Canvas",
        "Pipeline",
        "GPU",
        "Shader",
        "Filter",
        "Path",
        "Image",
        "Codec",
        "Bitmap",
        "Text",
        "FontMgr",
    }
    missing_areas = sorted(required_areas - seen_areas)
    if missing_areas:
        fail("native smoke capability coverage is missing areas: " + ", ".join(missing_areas))
    if schema_version >= 4:
        conditional_capabilities = status.get("native_smoke_conditional_capabilities")
        if not isinstance(conditional_capabilities, list) or not conditional_capabilities:
            fail("schema v4 platform status is missing native_smoke_conditional_capabilities list")
        required_conditionals = {
            "text.shaped-glyph-count": {
                "area": "Text",
                "marker": "native smoke shaped glyph count",
                "when_marker": "native smoke shaper availability",
                "when_value": "1",
            },
            "text.native-shaped-glyph-run-resource-plan": {
                "area": "Text",
                "marker": "native smoke shaped glyph run native resource plan count",
                "when_marker": "native smoke shaper availability",
                "when_value": "1",
            },
            "text.shaped-glyph-descriptor-bridge": {
                "area": "Text",
                "marker": "native smoke shaped glyph descriptor bridge",
                "when_marker": "native smoke shaper availability",
                "when_value": "1",
            },
            "text.shaped-glyph-descriptor-bridge-cache-resources": {
                "area": "Text",
                "marker": "native smoke shaped glyph descriptor bridge cache resources",
                "when_marker": "native smoke shaper availability",
                "when_value": "1",
            },
        }
        seen_conditional_ids = set()
        seen_conditional_markers = set()
        for conditional in conditional_capabilities:
            if not isinstance(conditional, dict):
                fail("native_smoke_conditional_capabilities entries must be objects")
            conditional_id = str(conditional.get("id", "")).strip()
            area = str(conditional.get("area", "")).strip()
            marker = str(conditional.get("marker", "")).strip()
            when_marker = str(conditional.get("when_marker", "")).strip()
            when_value = str(conditional.get("when_value", "")).strip()
            if not conditional_id:
                fail("native smoke conditional capability is missing id")
            if not area:
                fail(f"native smoke conditional capability is missing area: {conditional_id}")
            if not marker:
                fail(f"native smoke conditional capability is missing marker: {conditional_id}")
            if not when_marker:
                fail(f"native smoke conditional capability is missing when_marker: {conditional_id}")
            if not when_value:
                fail(f"native smoke conditional capability is missing when_value: {conditional_id}")
            if conditional_id in seen_conditional_ids:
                fail(f"duplicate native smoke conditional capability id: {conditional_id}")
            if marker in seen_markers or marker in seen_conditional_markers:
                fail(f"duplicate native smoke conditional capability marker: {marker}")
            if when_marker not in seen_markers:
                fail(
                    "native smoke conditional capability references unknown condition marker: "
                    f"{conditional_id}: {when_marker}"
                )
            if conditional_id in required_conditionals:
                required = required_conditionals[conditional_id]
                for field in ("area", "marker", "when_marker", "when_value"):
                    if str(conditional.get(field, "")).strip() != required[field]:
                        fail(
                            "native smoke conditional capability mismatch: "
                            f"{conditional_id}: {field}"
                        )
            seen_conditional_ids.add(conditional_id)
            seen_conditional_markers.add(marker)
        missing_conditional_ids = sorted(set(required_conditionals) - seen_conditional_ids)
        if missing_conditional_ids:
            fail(
                "native smoke conditional capability coverage is missing ids: "
                + ", ".join(missing_conditional_ids)
            )

        expected_values = status.get("native_smoke_expected_values")
        if not isinstance(expected_values, list) or not expected_values:
            fail("schema v4 platform status is missing native_smoke_expected_values list")
        required_expected_values = {
            "native smoke canvas clip device width": "4",
            "native smoke canvas state restored": "1",
            "native smoke canvas replay commands": "23",
            "native smoke render frame replay commands": "23",
            "native smoke render frame replay complete": "1",
            "native smoke render frame replay rejected skipped": "20",
            "native smoke surface render frame commands": "23",
            "native smoke surface render frame finalized": "1",
            "native smoke surface render frame finalization frame index": "7",
            "native smoke surface render frame finalization resource plan count": "16",
            "native smoke surface render frame finalization cacheable count": "15",
            "native smoke surface render frame finalization uncacheable count": "1",
            "native smoke surface render frame cache resources": "9",
            "native smoke native replay resource stats caches": "9",
            "native smoke native replay resource stats resources": "9",
            "native smoke surface render frame mismatch rejected": "1",
            "native smoke render shaped glyph run command replay": "1",
            "native smoke render shader cache resources": "1",
            "native smoke render shader cache misses": "1",
            "native smoke render shader cache hits": "2",
            "native smoke render path cache resources": "2",
            "native smoke render path cache misses": "2",
            "native smoke render path cache hits": "0",
            "native smoke render text run cache resources": "1",
            "native smoke render text run cache misses": "1",
            "native smoke render text run cache hits": "0",
            "native smoke render font cache resources": "1",
            "native smoke render font cache misses": "1",
            "native smoke render font cache hits": "0",
            "native smoke render typeface cache resources": "1",
            "native smoke render typeface cache misses": "1",
            "native smoke render typeface cache hits": "0",
            "native smoke render color filter cache resources": "1",
            "native smoke render color filter cache misses": "1",
            "native smoke render color filter cache hits": "0",
            "native smoke render image filter cache resources": "1",
            "native smoke render image filter cache misses": "1",
            "native smoke render image filter cache hits": "0",
            "native smoke render mask filter cache resources": "1",
            "native smoke render mask filter cache misses": "1",
            "native smoke render mask filter cache hits": "0",
            "native smoke render resource plan count": "15",
            "native smoke render frame resource plan count": "15",
            "native smoke render frame validation status": "1",
            "native smoke render frame cacheable subplan count": "15",
            "native smoke render frame uncacheable subplan count": "0",
            "native smoke render frame unbalanced validation": "1",
            "native smoke render target identity validation": "1",
            "native smoke render target resource binding": "1",
            "native smoke render frame present count": "1",
            "native smoke render frame submission resource plan count": "2",
            "native smoke render frame submission cacheable subplan count": "1",
            "native smoke render frame submission uncacheable subplan count": "1",
            "native smoke render frame submission preflight missing count": "1",
            "native smoke render frame submission preflight cached count": "1",
            "native smoke render frame submission cache resources": "1",
            "native smoke render frame finalization resource plan count": "2",
            "native smoke render frame finalization cacheable subplan count": "1",
            "native smoke render frame finalization uncacheable subplan count": "1",
            "native smoke render frame finalization preflight missing count": "1",
            "native smoke render frame finalization preflight cached count": "1",
            "native smoke render frame finalization cache resources": "1",
            "native smoke render frame missing present validation": "1",
            "native smoke render frame missing finalization validation": "1",
            "native smoke render frame touched bounds width": "4",
            "native smoke render frame cache resources": "15",
            "native smoke render resource cache inserts": "15",
            "native smoke render resource cache preflight missing count": "15",
            "native smoke render resource cache preflight cached count": "15",
            "native smoke render resource cache plan coverage": "1",
            "native smoke render resource cache evictions": "1",
            "native smoke render resource cache hits": "1",
            "native smoke render resource cache misses": "0",
            "native smoke render resource cache byte size": "8",
            "native smoke gpu context resource plan count": "2",
            "native smoke gpu context key variation": "1",
            "native smoke gpu frame context validation": "1",
            "native smoke gpu finalization resource plan count": "3",
            "native smoke gpu frame finalization resource plan count": "3",
            "native smoke gpu frame finalization gpu resource count": "3",
            "native smoke gpu frame submission resource plan count": "3",
            "native smoke gpu frame submission gpu resource count": "3",
            "native smoke surface target resource plan count": "2",
            "native smoke surface target cache resources": "2",
            "native smoke window target resource plan count": "1",
            "native smoke window physical width": "16",
            "native smoke window frame pacing": "2",
            "native smoke window present mode key variation": "1",
            "native smoke surface finalization resource plan count": "2",
            "native smoke surface finalization key variation": "1",
            "native smoke surface flush-and-submit": "1",
            "native smoke readback width": "32",
            "native smoke readback height": "32",
            "native smoke readback row_bytes": "128",
            "native smoke bounded readback width": "4",
            "native smoke bounded readback height": "4",
            "native smoke bounded snapshot width": "4",
            "native smoke bounded snapshot height": "4",
            "native smoke filter layer count": "1",
            "native smoke path verbs": "9",
            "native smoke decoded image width": "32",
            "native smoke decoded image height": "32",
            "native smoke render image command replay": "1",
            "native smoke render image command count": "3",
            "native smoke render image resource plan count": "2",
            "native smoke render image cache resources": "1",
            "native smoke render image cache misses": "1",
            "native smoke render image cache hits": "1",
            "native smoke codec width": "32",
            "native smoke codec height": "32",
            "native smoke decoded bitmap width": "32",
            "native smoke decoded bitmap height": "32",
            "native smoke shader draws": "3",
            "native smoke shader resource plan count": "3",
            "native smoke filter resource plan count": "3",
            "native smoke text run resource plan count": "3",
            "native smoke text run range byte size": "4",
            "native smoke measured text resource plan count": "5",
            "native smoke measured text key variation": "1",
            "native smoke shaped glyph run resource plan count": "6",
            "native smoke shaped glyph run key variation": "1",
            "native smoke font resource plan count": "1",
            "native smoke font fallback key variation": "1",
            "native smoke font fallback match key variation": "1",
            "native smoke font fallback match resource plan count": "2",
            "native smoke font fallback resolution key variation": "1",
            "native smoke font fallback resolution resource plan count": "4",
            "native smoke font fallback resolution bridge": "1",
            "native smoke font fallback resolution bridge cache resources": "4",
            "native smoke font fallback resource plan count": "1",
            "native smoke font fallback font resource plan count": "2",
        }
        seen_expected_markers = set()
        for expected in expected_values:
            if not isinstance(expected, dict):
                fail("native_smoke_expected_values entries must be objects")
            expected_id = str(expected.get("id", "")).strip()
            marker = str(expected.get("marker", "")).strip()
            value = str(expected.get("value", "")).strip()
            if not expected_id:
                fail("native smoke expected value is missing id")
            if expected_id not in seen_ids:
                fail(f"native smoke expected value references unknown capability id: {expected_id}")
            if not marker:
                fail(f"native smoke expected value is missing marker: {expected_id}")
            if marker not in seen_markers:
                fail(f"native smoke expected value references unknown marker: {marker}")
            if not value:
                fail(f"native smoke expected value is missing value: {marker}")
            if marker in seen_expected_markers:
                fail(f"duplicate native smoke expected value marker: {marker}")
            seen_expected_markers.add(marker)
        for marker, value in required_expected_values.items():
            if marker not in seen_expected_markers:
                fail(f"native smoke expected value coverage is missing marker: {marker}")
            expected = next(
                item for item in expected_values
                if str(item.get("marker", "")).strip() == marker
            )
            if str(expected.get("value", "")).strip() != value:
                fail(
                    "native smoke expected value mismatch: "
                    f"{marker}: expected {value}"
                )

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
expected_artifact_logs = {
    "linux": [
        "linux-real-skia-smoke-preflight.log",
        "linux-real-skia-smoke.log",
        "linux-native-smoke-output.log",
        "linux-real-skia-acceptance.log",
    ],
    "macos": [
        "macos-real-skia-smoke-preflight.log",
        "macos-real-skia-smoke.log",
        "macos-native-smoke-output.log",
        "macos-real-skia-acceptance.log",
    ],
    "windows": [
        "windows-real-skia-smoke-preflight.log",
        "windows-real-skia-smoke.log",
        "windows-native-smoke-output.log",
        "windows-real-skia-acceptance.log",
    ],
}
expected_verifiers = {
    "linux": "scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs",
    "macos": "scripts/verify-real-skia-artifact.sh --platform macos --log-dir logs",
    "windows": "scripts/verify-real-skia-artifact.ps1 -Platform windows -LogDir logs",
}
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
    required_artifact_logs = entry.get("required_artifact_logs")
    if not isinstance(required_artifact_logs, list) or required_artifact_logs != expected_artifact_logs[platform]:
        fail(f"platform status required_artifact_logs do not match expected contract: {platform}")
    if entry.get("required_verifier") != expected_verifiers[platform]:
        fail(f"platform status required_verifier does not match expected verifier: {platform}")
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

default_status_path = (repo_root / "skia-platform-status.json").resolve()
should_check_status_doc = status_doc_explicit or status_path.resolve() == default_status_path
if should_check_status_doc:
    if not status_doc_path.is_file():
        fail(f"Skia platform status Markdown file is missing: {status_doc_path}")

    platform_names = {
        "linux": "Linux",
        "macos": "macOS",
        "windows": "Windows",
    }
    rows = {}
    in_current_matrix = False
    for line in status_doc_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped == "## Current Matrix":
            in_current_matrix = True
            continue
        if in_current_matrix and stripped.startswith("## "):
            break
        if not in_current_matrix or not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) >= 4 and cells[0] in platform_names.values():
            key = next(
                platform for platform, name in platform_names.items()
                if name == cells[0]
            )
            rows[key] = cells

    for platform, display_name in platform_names.items():
        if platform not in rows:
            fail(f"platform status Markdown matrix is missing row: {display_name}")
        entry = platform_entries[platform]
        row_text = " ".join(rows[platform][1:]).lower()
        state_cell = rows[platform][1].lower()
        if entry["accepted"]:
            if "accepted" not in state_cell or "not accepted" in state_cell:
                fail(
                    "platform status Markdown matrix does not mark accepted platform: "
                    f"{display_name}"
                )
            accepted_provider = str(entry.get("__accepted_provider", ""))
            accepted_version = str(entry.get("__accepted_version", ""))
            if accepted_provider and accepted_provider.lower() not in row_text:
                fail(
                    "platform status Markdown matrix is missing accepted provider: "
                    f"{display_name}: {accepted_provider}"
                )
            if accepted_version and accepted_version.lower() not in row_text:
                fail(
                    "platform status Markdown matrix is missing accepted version: "
                    f"{display_name}: {accepted_version}"
                )
        elif "not accepted" not in state_cell:
            fail(
                "platform status Markdown matrix does not mark unaccepted platform: "
                f"{display_name}"
            )

print(f"Verified Skia platform status in {status_path} with revision {revision}.")
PY

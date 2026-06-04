#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-accept-artifact-and-pin.sh [options]

Verifies a downloaded Linux source-built real-Skia smoke artifact bundle,
extracts its accepted Skia commit, writes that commit to skia-revision.txt, and
verifies the pin. This is the Unix shell equivalent of
scripts/linux-accept-artifact-and-pin.ps1.

Options:
  --log-dir PATH        Directory containing Linux real-smoke logs.
                        Default: logs.
  --revision-file PATH  File to update with the accepted Skia commit.
                        Default: skia-revision.txt.
  --accept-platform-status
                        Mark Linux accepted in skia-platform-status.json after
                        artifact verification and revision pinning.
  --status-file PATH    Platform status JSON to update when
                        --accept-platform-status is set.
                        Default: skia-platform-status.json.
  --artifact-label TEXT accepted_artifact value for the platform status.
                        Default: linux-real-skia-smoke-log.
  -h, --help            Show this help.

The artifact must pass scripts/verify-real-skia-artifact.sh with
--platform linux --require-commit before the revision file is written.
EOF
}

log_dir="logs"
revision_file="skia-revision.txt"
accept_platform_status=0
status_file="skia-platform-status.json"
artifact_label="linux-real-skia-smoke-log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --log-dir" >&2
        usage >&2
        exit 2
      fi
      log_dir="$2"
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
    --accept-platform-status)
      accept_platform_status=1
      shift
      ;;
    --status-file)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --status-file" >&2
        usage >&2
        exit 2
      fi
      status_file="$2"
      shift 2
      ;;
    --artifact-label)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --artifact-label" >&2
        usage >&2
        exit 2
      fi
      artifact_label="$2"
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

resolved_log_dir="$(resolve_repo_path "$log_dir")"
resolved_revision_file="$(resolve_repo_path "$revision_file")"
resolved_status_file="$(resolve_repo_path "$status_file")"
acceptance_log="$resolved_log_dir/linux-real-skia-acceptance.log"

bash "$repo_root/scripts/verify-real-skia-artifact.sh" \
  --platform linux \
  --log-dir "$resolved_log_dir" \
  --require-commit

if [[ ! -f "$acceptance_log" ]]; then
  echo "Linux acceptance log is missing after artifact verification: $acceptance_log" >&2
  exit 1
fi

accepted_commit="$(grep -E '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$acceptance_log" \
  | tail -n 1 \
  | sed -E 's/^[[:space:]]*skia_commit=([0-9a-fA-F]{40})[[:space:]]*$/\1/' \
  | tr '[:upper:]' '[:lower:]')"

if [[ -z "$accepted_commit" ]]; then
  echo "no full 40-character skia_commit=<hash> entry was found in $acceptance_log" >&2
  exit 1
fi

mkdir -p "$(dirname "$resolved_revision_file")"
printf '%s\n' "$accepted_commit" > "$resolved_revision_file"

bash "$repo_root/scripts/verify-skia-revision-pin.sh" \
  "$acceptance_log" \
  --revision-file "$resolved_revision_file"

if [[ $accept_platform_status -eq 1 ]]; then
  bash "$repo_root/scripts/accept-platform-status.sh" \
    --platform linux \
    --log-dir "$resolved_log_dir" \
    --status-file "$resolved_status_file" \
    --revision-file "$resolved_revision_file" \
    --artifact-label "$artifact_label"

  echo "Linux source-built Skia artifact passed, $resolved_revision_file is pinned, and Linux is marked accepted."
else
  echo "Linux source-built Skia artifact passed and $resolved_revision_file is pinned."
fi

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-accept-and-pin-skia.sh [options]

Runs the Linux source-built real Skia smoke acceptance, verifies the complete
artifact bundle with a required 40-character Skia commit, and pins
skia-revision.txt to that accepted commit. Pass --accept-platform-status to
also mark Linux accepted in skia-platform-status.json after the pin verifies.

Options handled by this wrapper:
  --log-dir PATH             Directory for acceptance logs. Default: logs.
  --install-deps             Install Ubuntu smoke dependencies before acceptance.
  --skip-deps-check          Do not run the dependency preflight check.
  --accept-platform-status   Mark Linux accepted in skia-platform-status.json
                             after artifact verification and revision pinning.
  --status-file PATH         Platform status JSON to update when
                             --accept-platform-status is set.
                             Default: skia-platform-status.json.
  --artifact-label TEXT      accepted_artifact value for the platform status.
                             Default: linux-real-skia-smoke-log.
  -h, --help                 Show this help.

All other options are forwarded to scripts/linux-accept-real-skia-smoke.sh.
This wrapper is intentionally source-build only; it rejects --skia-include and
--skia-lib-dir so an existing-build smoke cannot accidentally become the first
repository pin.
EOF
}

log_dir="logs"
acceptance_args=()
install_deps=0
check_deps=1
accept_platform_status=0
status_file="skia-platform-status.json"
artifact_label="linux-real-skia-smoke-log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir)
      log_dir="${2:-}"
      if [[ -z "$log_dir" ]]; then
        echo "--log-dir requires a non-empty path" >&2
        exit 2
      fi
      shift 2
      ;;
    --install-deps)
      install_deps=1
      shift
      ;;
    --skip-deps-check)
      check_deps=0
      shift
      ;;
    --accept-platform-status)
      accept_platform_status=1
      shift
      ;;
    --status-file)
      status_file="${2:-}"
      if [[ -z "$status_file" ]]; then
        echo "--status-file requires a non-empty path" >&2
        exit 2
      fi
      shift 2
      ;;
    --artifact-label)
      artifact_label="${2:-}"
      if [[ -z "$artifact_label" ]]; then
        echo "--artifact-label requires a non-empty value" >&2
        exit 2
      fi
      shift 2
      ;;
    --skia-include|--skia-lib-dir)
      echo "linux-accept-and-pin-skia.sh is source-build only; use linux-accept-real-skia-smoke.sh for existing Skia builds" >&2
      exit 2
      ;;
    --dry-run-config)
      echo "pinning requires a real source-built smoke run" >&2
      exit 2
      ;;
    --smoke-log)
      echo "scripts/linux-accept-real-skia-smoke.sh owns --smoke-log; use --log-dir instead" >&2
      exit 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      acceptance_args+=("$1")
      shift
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$repo_root/$log_dir" ;;
esac

acceptance_log="$resolved_log_dir/linux-real-skia-acceptance.log"
case "$status_file" in
  /*) resolved_status_file="$status_file" ;;
  *) resolved_status_file="$repo_root/$status_file" ;;
esac

if [[ $install_deps -eq 1 ]]; then
  bash "$repo_root/scripts/install-linux-smoke-deps.sh"
elif [[ $check_deps -eq 1 ]]; then
  bash "$repo_root/scripts/install-linux-smoke-deps.sh" --check
fi

bash "$repo_root/scripts/linux-accept-real-skia-smoke.sh" \
  --log-dir "$resolved_log_dir" \
  --skia-provider source \
  "${acceptance_args[@]}"

bash "$repo_root/scripts/verify-real-skia-artifact.sh" \
  --platform linux \
  --log-dir "$resolved_log_dir" \
  --require-commit

bash "$repo_root/scripts/pin-skia-revision.sh" "$acceptance_log"
bash "$repo_root/scripts/verify-skia-revision-pin.sh" "$acceptance_log"

if [[ $accept_platform_status -eq 1 ]]; then
  bash "$repo_root/scripts/accept-platform-status.sh" \
    --platform linux \
    --log-dir "$resolved_log_dir" \
    --status-file "$resolved_status_file" \
    --revision-file "$repo_root/skia-revision.txt" \
    --artifact-label "$artifact_label"
fi

if [[ $accept_platform_status -eq 1 ]]; then
  echo "Linux source-built Skia acceptance passed, skia-revision.txt is pinned, and Linux is marked accepted."
else
  echo "Linux source-built Skia acceptance passed and skia-revision.txt is pinned."
fi

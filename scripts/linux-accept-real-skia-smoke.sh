#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-accept-real-skia-smoke.sh [--log-dir PATH] [linux-real-skia-smoke options]

Runs the Linux real Skia smoke helper, captures both wrapper and native smoke
executable logs, verifies the native success marker, and checks that
native/moon.pkg was restored after the run.

Options handled by this wrapper:
  --log-dir PATH       Directory for acceptance logs. Default: logs/linux-real-skia-smoke.
                       Relative paths are resolved from the repository root.
  -h, --help           Show this help.

All other options are forwarded to scripts/linux-real-skia-smoke.sh. This
wrapper owns --build-log and --smoke-log so build and native executable logs have
predictable paths.
EOF
}

log_dir="logs/linux-real-skia-smoke"
smoke_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir)
      log_dir="${2:-}"
      shift 2
      ;;
    --smoke-log)
      echo "scripts/linux-accept-real-skia-smoke.sh owns --smoke-log; use --log-dir instead" >&2
      exit 2
      ;;
    --dry-run-config)
      echo "acceptance requires a real smoke run; use scripts/linux-real-skia-smoke.sh --dry-run-config for preflight" >&2
      exit 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      smoke_args+=("$1")
      shift
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$repo_root/$log_dir" ;;
esac

wrapper_log="$resolved_log_dir/linux-real-skia-smoke.log"
build_log="$resolved_log_dir/linux-skia-build.log"
native_log="$resolved_log_dir/linux-native-smoke-output.log"
acceptance_log="$resolved_log_dir/linux-real-skia-acceptance.log"
native_pkg="$repo_root/native/moon.pkg"
backup_pkg="$native_pkg.smoke.bak"

if [[ -f "$backup_pkg" ]]; then
  echo "native/moon.pkg smoke backup already exists: $backup_pkg" >&2
  echo "Resolve the stale backup before running acceptance." >&2
  exit 1
fi

mkdir -p "$resolved_log_dir"

before_pkg_hash="$(sha256sum "$native_pkg" | cut -d ' ' -f 1)"

echo "Linux real Skia acceptance logs:"
echo "  wrapper_log=$wrapper_log"
echo "  build_log=$build_log"
echo "  native_log=$native_log"
echo "  acceptance_log=$acceptance_log"

set +e
set -o pipefail
bash "$repo_root/scripts/linux-real-skia-smoke.sh" \
  --build-log "$build_log" \
  --smoke-log "$native_log" \
  "${smoke_args[@]}" 2>&1 | tee "$wrapper_log"
smoke_status=${PIPESTATUS[0]}
set +o pipefail
set -e

after_pkg_hash="$(sha256sum "$native_pkg" | cut -d ' ' -f 1)"
restore_status="passed"
if [[ -f "$backup_pkg" ]]; then
  echo "native/moon.pkg smoke backup remains after acceptance run" >&2
  restore_status="failed"
fi
if [[ "$before_pkg_hash" != "$after_pkg_hash" ]]; then
  echo "native/moon.pkg hash changed after acceptance run" >&2
  restore_status="failed"
fi

marker_status="not run"
if [[ $smoke_status -eq 0 ]]; then
  if bash "$repo_root/scripts/verify-native-smoke-log.sh" "$native_log"; then
    marker_status="passed"
  else
    marker_status="failed"
  fi
fi

skia_commit=""
skia_provider=""
jetbrains_tag=""
skia_package=""
skia_package_sha256=""
if [[ -f "$wrapper_log" ]]; then
  skia_commit="$(grep -E '^[[:space:]]*skia_commit=' "$wrapper_log" | tail -n 1 | sed 's/^[[:space:]]*skia_commit=//' || true)"
  skia_provider="$(grep -E '^[[:space:]]*skia_provider=' "$wrapper_log" | tail -n 1 | sed 's/^[[:space:]]*skia_provider=//' || true)"
  jetbrains_tag="$(grep -E '^[[:space:]]*jetbrains_tag=' "$wrapper_log" | tail -n 1 | sed 's/^[[:space:]]*jetbrains_tag=//' || true)"
  skia_package="$(grep -E '^[[:space:]]*skia_package=' "$wrapper_log" | tail -n 1 | sed 's/^[[:space:]]*skia_package=//' || true)"
  skia_package_sha256="$(grep -E '^[[:space:]]*skia_package_sha256=' "$wrapper_log" | tail -n 1 | sed 's/^[[:space:]]*skia_package_sha256=//' || true)"
fi

cat <<EOF | tee "$acceptance_log"
Linux real Skia acceptance result:
  smoke_status=$smoke_status
  native_smoke_marker=$marker_status
  native_pkg_restore=$restore_status
  skia_provider=${skia_provider:-unknown}
  jetbrains_tag=${jetbrains_tag:-unknown}
  skia_commit=${skia_commit:-unknown}
  skia_package=${skia_package:-unknown}
  skia_package_sha256=${skia_package_sha256:-unknown}
  wrapper_log=$wrapper_log
  build_log=$build_log
  native_log=$native_log
  acceptance_log=$acceptance_log
EOF

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "native_smoke_marker_status=$marker_status"
    echo "restore_status=$restore_status"
    echo "linux_acceptance_log=$acceptance_log"
    echo "linux_skia_provider=${skia_provider:-unknown}"
    echo "linux_skia_commit=${skia_commit:-unknown}"
  } >> "$GITHUB_ENV"
fi

if [[ "$restore_status" != "passed" ]]; then
  exit 1
fi
if [[ $smoke_status -ne 0 ]]; then
  exit "$smoke_status"
fi
if [[ "$marker_status" != "passed" ]]; then
  exit 1
fi

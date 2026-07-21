#!/usr/bin/env bash
# Thin MoUI wrapper: package-local Android hosted APK build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MBW_WORKSPACE_ROOT="${MBW_WORKSPACE_ROOT:-$ROOT}"
exec bash "$ROOT/window/android/scripts/build-hosted-apk.sh" "$@"

#!/usr/bin/env bash
# Thin MoUI wrapper: package-local iOS hosted sim app build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MBW_WORKSPACE_ROOT="${MBW_WORKSPACE_ROOT:-$ROOT}"
exec bash "$ROOT/window/ios/scripts/build-hosted-sim-app.sh" "$@"

#!/usr/bin/env bash
# Thin MoUI wrapper: package-local HarmonyOS hosted HAP build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MBW_WORKSPACE_ROOT="${MBW_WORKSPACE_ROOT:-$ROOT}"

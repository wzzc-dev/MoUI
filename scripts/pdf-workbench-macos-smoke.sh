#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec node "$repo_root/scripts/pdf-workbench-native-smoke.mjs" --platform macos "$@"

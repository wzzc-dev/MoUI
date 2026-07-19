#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$repo_root"

node --test moui_shell/harmonyos/runner/tests/validate-managed-shell.mjs
node --test moui_shell/harmonyos/runner/tests/validate-plugin-capabilities.mjs
node --test moui_shell/scripts/app-config.test.mjs
node --test moui_shell/scripts/harmonyos-skia-link.test.mjs

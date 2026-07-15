#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$repo_root"

node --test moui/mobile/harmonyos/tests/validate-managed-shell.mjs
node --test moui/mobile/harmonyos/tests/validate-plugin-capabilities.mjs
node --test moui/scripts/mobile/app-config.test.mjs

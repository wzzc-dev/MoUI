#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$script_dir/validate-managed-shell.mjs"
node --test "$script_dir/../../runner/resolve-shell.test.mjs"

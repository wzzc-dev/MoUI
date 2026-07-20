#!/usr/bin/env bash
# Thin launcher that delegates to `moui_cli build-ios-core`. The real
# implementation lives in `moui_cli/build_ios_core.mbt` (M6). This shim exists
# because Xcode Run Script Phases can only invoke shell scripts, not bare
# binaries. The path is referenced by
# `shell_sources.mbt::canonical_shell_source_plan`.
set -euo pipefail
exec "${MOUI_BUILD_IOS_CORE_BIN:-moui_cli}" build-ios-core "$@"

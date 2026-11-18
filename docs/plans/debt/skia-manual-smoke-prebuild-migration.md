# Plan: Port the manual Skia smoke runners to the prebuild environment flow

- **Status**: debt
- **Goal**: Move the remaining manually-invoked Skia smoke scripts off the
  retired `configure-*-native-pkg --write` + `stub-cc-flags` +
  `MOON_CC=clang-cl` flow and onto the `moui_skia/build.mbtx` environment
  exports, so a future real-Skia smoke run does not stop at a helper that now
  exits 2 by design.
- **Non-goals**: not touching the CI path (`scripts/macos-platform-evidence.sh`,
  `scripts/linux-platform-evidence.sh`, `scripts/windows-platform-evidence.sh`
  and `.github/workflows/*` already run the prebuild flow); not re-adding
  `stub-cc-flags` anywhere; not changing what the smokes assert.

## Context

Skia option 1 landed: the C++ stub compiles inside `moui_skia/build.mbtx`
(`/std:c++20` on Windows, `-std=c++17` elsewhere), `moui_skia/native/moon.pkg`
carries no `native-stub`/`stub-cc-flags`, and the only Skia flags are the
prebuild-emitted `${build.MOUI_SKIA_CC_LINK_FLAGS}`. The four
`configure-*-native-pkg` helpers now refuse `--write`/`-Write` (exit 2 / throw)
and validate the committed package with `--check`; the evidence scripts export
`MOUI_SKIA_PLATFORM/SKIA_INCLUDE/SKIA_LIB_DIR/LINK_MODE` plus
`STUB_MODE=build` instead of patching packages.

These manual smoke runners still assume the old contract:

| Script | Old-flow anchor |
|---|---|
| `moui_skia/scripts/macos-skia-smoke.sh` | `--write` at :550, helper call at :558, `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` at :651/:731 |
| `moui_skia/scripts/linux-skia-smoke.sh` | `--write` at :529, `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` at :623/:703 |
| `moui_skia/scripts/windows-skia-smoke.ps1` | `-Write` at :151, `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` at :253/:331 |
| `moui_skia/scripts/windows-msvc-skia-smoke.ps1` | `-Write` at :392, `.cmd` block sets `MOON_CC` + DISABLE at :433/:437/:542/:546/:659/:663 |
| `moui_skia/scripts/windows-msvc-skia-triangle.ps1` | `-Write` at :141, `.cmd` block at :177/:181 |
| `moui_skia/scripts/windows-msvc-skia-text.ps1` | `-Write` at :222, `.cmd` block at :259/:263 |

`moui_skia/scripts/check-fallback.ps1` was updated to the new helper contract
but has not been executed on a PowerShell host.

## Why deferred

The scripts are path-triggered real-device smokes, not part of `check.sh` or CI;
they need real Skia archives plus a PowerShell/MSVC host to validate, and the
port itself is mechanical. Until then they are expected to stop at the
`--write` step with the helper's migration message instead of silently
producing the retired package shape.

## Acceptance

- Each runner exports the prebuild variables (or sources a shared helper) and
  drops `--write`/`-Write`, `MOON_CC`, and `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1`
  from its real-Skia path; an intentional no-Skia fallback path keeps the
  escape hatch and says so.
- `native-stub` in `moui_skia/scripts/native_smoke/moon.pkg` stays pure C
  (`smoke_debug.c`).
- One real smoke run per OS records the same first-frame and IME markers as
  `scripts/{macos,linux,windows}-platform-evidence.sh`.

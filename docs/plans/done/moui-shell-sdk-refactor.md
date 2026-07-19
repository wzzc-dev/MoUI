# Plan: moui_shell native shell SDK refactor

- **Status**: complete
- **Goal**: Ship the platform-first `wzzc-dev/moui_shell` SDK: shared embedding
  semantics plus Android/iOS/HarmonyOS typed platform packages, while keeping
  MoUI's root facade platform-neutral.
- **Non-goals**: Desktop shell profiles, new platform capabilities, and
  compatibility with the former mobile ABI/configuration/legacy fixtures.

## Acceptance

- [x] `moui_shell` has no `wzzc-dev/moui` package import.
- [x] `embedding` owns neutral lifecycle, epoch, scheduling, request/wire, and
  capability-negotiation APIs.
- [x] Each MoUI platform backend imports `embedding` and its matching platform
  package, without a reverse shell-to-MoUI import.
- [x] Android, iOS, and HarmonyOS managed, plugin, and clean-ejected fallback
  packaging paths use the new shell package and schema.
- [x] No legacy mobile shell/configuration/ABI path remains in active code.
- [x] The relevant MoonBit, ABI, shell-matrix, validator, generated-doc, and
  static checks
  pass without changing platform readiness claims.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | Publish a MoUI-specific `wzzc-dev/moui_shell`; it is not a generic replacement for `wzzc-dev/window`. |
| 2026-07-19 | Keep the root `wzzc-dev/moui` facade free of shell imports; Android/iOS/HarmonyOS backends consume `moui_shell/embedding` plus their own typed package. |
| 2026-07-19 | Keep only the `handheld` shell profile and managed/ejected runner modes. |
| 2026-07-19 | Use a platform-first physical layout: `<platform>/embedder` and `<platform>/runner`; do not flatten typed native handles into a lowest-common-denominator API. |

## Progress

| Date | Note |
| --- | --- |
| 2026-07-19 | Added `embedding`, `android`, `ios`, and `harmonyos` MoonBit packages and connected them to the three platform backends. |
| 2026-07-19 | Moved native assets to platform-first paths and updated shell scripts, CMake, Gradle, resolver tests, workflow paths, and the ABI header tests. |
| 2026-07-19 | Added app-independent platform embedding adapters, reduced the Android/iOS/HarmonyOS example entrypoints to app/renderer/configuration wiring, and kept the ABI provider in `moui/backend/internal/embedded_runtime_session`. |
| 2026-07-19 | Added shared ejected-lock validation for package versions, API/schema values, handheld profile, capability snapshots, and project pins; clean ejected iOS resolves copied sources separately from the published SDK. |
| 2026-07-19 | Passed all three static managed/plugin/ejected fallback matrices, package/ABI/ASan checks, entrypoint checks, generated-doc checks, and the static maintenance/API/guidance guards. Platform readiness remains `runtime_partial`. |

## Validation note

`sh scripts/check.sh --profile pr` and `--profile daily` reached the existing
`validate-window-dependency` repository baseline mismatch (`moui` pins
`wzzc-dev/window@0.5.1`, while `moui_skia`, `moui_webview`, and Markdown Editor
pin `0.5.1-0.1.7`). That dependency issue is outside this shell refactor; all
shell-specific PR stages completed before it.

`--profile platform` passed shared host/Web service checks, then stopped because
the locally resolved macOS `window` package lacks the pre-existing
`SystemMenuDescriptor`/`set_system_menus` API expected by `backend/macos`.

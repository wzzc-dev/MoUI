# Plan: Release module dependency closures

- **Status**: done
- **Goal**: Split concrete renderers and integration tests out of
  `wzzc-dev/moui` so each published module carries only its production
  dependency closure.
- **Non-goals**: Split platform backends, change renderer behavior, or change
  platform readiness classifications.

## Acceptance

- [x] `wzzc-dev/moui@0.2.0` has no concrete-renderer, renderer-binding,
      WGPU/Cosmic/Swash/image, quickcheck, or pixelmatch dependency.
- [x] Skia, Web, WGPU, and Sun are independent published modules with explicit
      dependencies on `wzzc-dev/moui@0.2.0`.
- [x] Dedicated integration tests and tester renderer smokes live in an
      unpublished module.
- [x] The small tester harness and its repository-only fixture live under
      `moui_tests/tester` instead of creating an unused public release unit.
- [x] Base-only, Skia, and Web external-consumer package checks pass outside
      the repository checkout.
- [x] Module closure, API, maintenance, guidance, and renderer boundary gates
      pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-07 | Use new public package paths under `moui_*_renderer`; do not ship compatibility wrappers. |
| 2026-08-07 | Keep WebGPU and Canvas2D in one `moui_web_renderer` module. |
| 2026-08-07 | Release the affected public ecosystem at 0.2.0, then allow independent versions. |
| 2026-08-07 | Keep platform backends in the base module for this wave. |
| 2026-08-07 | Fold `moui_tester` into `moui_tests/tester`; its only real consumers are internal renderer smokes. |

## Progress

| Date | Note |
|------|------|
| 2026-08-07 | Plan accepted; implementation started. |
| 2026-08-07 | Extracted four renderer modules and the unpublished integration-test module; split prebuild ownership and migrated composition roots. |
| 2026-08-07 | Added the release catalog/closure gate, package consumer profiles, CLI template dependencies, and updated docs/CI paths. |
| 2026-08-07 | Daily, platform, theme, focused WGPU, registry-base, and package base/Skia/Web checks passed; all public modules produced local archives. No registry publish was performed. |
| 2026-08-07 | Full-profile functional steps passed when run individually. The aggregate full lint remains unavailable on this host because `pwsh`, PSScriptAnalyzer, and shellcheck are not installed; the pre-existing full maintenance scope also reports five unrelated oversized files. |
| 2026-08-07 | Removed the redundant public tester release unit and moved its harness and fixture under `moui_tests/tester`. |

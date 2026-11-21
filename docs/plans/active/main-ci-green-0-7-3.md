# Plan: Green `main` CI and the 0.7.3 release

- **Status**: active
- **Goal**: Restore every failing `main` workflow to green and then publish
  `0.7.3`. The five failures share one cause: the `moui_skia/build.mbtx`
  prebuild took ownership of the stub and link config while the smoke and
  fallback gates still spoke the retired `--write` protocol; separately the
  Playground bundle schema and the RISC-V nested prebuild drifted.
- **Non-goals**: No renderer or platform reclassification, no restoration of
  `configure-*-native-pkg --write`, no new features beyond the Playground
  manifest schema bump required by the per-package core bundle.

## Context

Failing workflows on `main` (`6a5c9c1c`):

| Workflow | Root cause |
|---|---|
| Deploy Website | Playground asset generator expected one monolithic `core.core`; the toolchain now emits a per-package bundle. |
| Real Skia Acceptance (6 legs) | Smoke runners called `configure-*-native-pkg --write`, which exits 2 by design. |
| Renderer Real Skia CI | Same `--write` retirement in the macOS/Linux smoke runners. |
| Skia Provider Fallback CI | Stale verifier tokens, unscoped Windows workspace commands, nested `native_smoke` module pinning the retired `build.js`, and a stale fake-env assertion. |
| Linux RISC-V64 Cross Build | The renderer hook nested `moon run build.mbtx` after `MOON_CC` was cross, linking host `single` with the RISC-V wrapper. |

## Acceptance

- [ ] Playground assets use the schema-v3 core-file list; generator, worker,
      `pages.yml` assertions, and Deploy Website are green.
- [ ] macOS/Linux/Windows smoke runners consume the prebuild env; no package
      rewrites and no `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` on real-Skia paths.
- [ ] Real Skia Acceptance (6 legs) and Renderer Real Skia CI are green.
- [ ] Fallback CI: verifiers match the current helpers, Windows commands are
      scoped, `native_smoke` is a local package, and the fallback gate is green.
- [ ] RISC-V precomputes the Skia contract with the host toolchain before
      exporting `MOON_CC`; Linux RISC-V64 is green.
- [ ] Pre-push guards and `main` are green.
- [ ] `0.7.3` published: 25 modules bumped/pinned, compatibility-matrix pins
      synced, release notes written, fresh-consumer resolution verified, tag made.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-21 | Do not restore `--write`; smoke scripts consume the `build.mbtx` env contract. `scripts/macos-platform-evidence.sh` is the template. |
| 2026-11-21 | Remove `native_smoke/moon.mod`; build it from the module root. The nested module resolved the published `@0.2.5` pin, and `-C` does not apply module-root prebuild link configs. |
| 2026-11-21 | Scope `moon check/test` in CI to explicit paths; unscoped runs resolve the ancestor `moon.work` (832 tasks). |
| 2026-11-21 | Playground manifest moves to schema v3 with an explicit core-file list; v2 assets are rejected. |
| 2026-11-22 | All six smoke runners use the prebuild env; Windows exe paths live under `wzzc-dev/moui_tests/...`; renderer/text builds run from the repo root. |
| 2026-11-22 | RISC-V captures the host prebuild JSON into `MOUI_SKIA_PREBUILD_CONTRACT_FILE`; the renderer/tests hooks read it instead of nesting `moon run`, and the script clears an inherited disable switch. |

## Progress

| Date | Note |
|------|------|
| 2026-11-21 | Diagnosed all five failures; plan written before coding. |
| 2026-11-22 | Playground, smoke, fallback, and RISC-V fixes implemented. Local: static guards, formatting, fallback tests 75/75, `moon check`, `native_smoke` build, and macOS real-Skia smokes pass. Windows/RISC-V await CI. |

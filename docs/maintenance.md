# Maintenance Mainline

MoUI keeps a narrow default maintenance baseline so the framework can keep
growing without turning every diagnostic route into daily release pressure.

<!-- BEGIN GENERATED PLATFORM TIER MATRIX -->
| Tier | Canonical routes | Gate |
|---|---|---|
| Tier 1 | `macOS Skia`, `Web wasm-gc WebGPU (Canvas2D fallback)` | Blocking: PR build/test, daily presentation, and release evidence |
| Tier 2 | `Windows Skia`, `Linux Skia` | Blocking: L0-L2 and first frame; complete L3 may remain partial |
| Tier 3 | `macOS WGPU (CoreText, Cosmic fallback)`, `Windows WGPU (DirectWrite, Cosmic fallback)`, `Linux WGPU (Fontconfig, Cosmic fallback)`, `Android window-hosted Skia`, `iOS window-hosted Skia`, `HarmonyOS window-hosted Skia`, `macOS Sun`, `Windows Sun`, `Linux Sun`, `WeChat Skyline Canvas2D` | Non-blocking: scheduled/manual build, run, and evidence |

Tier, L0-L3 evidence, and `product_class`/`ready` are independent. Source: `checks/platform-matrix.json`; actual observations remain in `checks/platforms/*.json`.
<!-- END GENERATED PLATFORM TIER MATRIX -->

## Status Classes

- `mainline`: covered by the default `sh scripts/check.sh --profile daily` path. Mainline
  work must stay green before ordinary handoff.
- `diagnostic`: runnable, testable, and allowed to record observation, but not a
  default daily gate. Run the matching opt-in flag or focused command when the
  diagnostic route changes.
- `pending`: documented scaffold or capability note exists, but the route must
  not be described as ready until matching smoke has run.

## Default Baseline

The default daily baseline covers:

- `moui/core` and `moui/views`
- `moui/backend` and `moui/backend/web`
- `moui/render`, `moui_skia_renderer`, and `moui_web_renderer`
- fallback-safe `moui_skia` checks
- Showcase app/Web wasm-gc validation
- Markdown Editor app/Web wasm-gc validation
- renderer/provider static checks and lightweight Web handoff validation
- maintenance baseline ratchets for oversized source files, source-level
  `pub(all)` counts, and root facade type-forwarding counts
- API surface package budgets plus semantic classification budgets for
  `core`, `views`, `runtime`, `backend`, and `render`

Complete platform runtime smoke is a release or matching-host gate, not a
default daily gate. Daily checks do not require fresh matching-host promotion.

## Engineering Baseline Ratchets

The maintenance baseline ratchets are implemented as the MoonBit tool at
`tools/moui/validate_maintenance_baseline`. They scan MoUI-owned MoonBit source
under `moui/`, `examples/`, and `website/`, excluding generated
`pkg.generated.mbti` files, vendored `.mooncakes/` trees, build output, and
generated Unicode fixture tests. The default `sh scripts/check.sh --profile daily` path
runs the guard through `node scripts/validate-maintenance-baseline.mjs`; run
that wrapper directly when splitting files, shrinking `pub(all)`, or reducing
root facade forwards, then ratchet the relevant budget downward in the same
change.

The guard tracks three budgets:

- oversized file ratchets for current hotspots such as `moui/core/unicode/grapheme_data.mbt`,
  `moui/runtime/view_tree.mbt`, `moui/views/form/form_validation_test.mbt`,
  `moui/backend/common` lifecycle/image tests, Skia renderer text/tests, and large
  example app files;
- direct package source `pub(all)` counts for core, views, host, render,
  mainline examples, Mo Workbench, PDF Workbench, and Website;
- root facade `pub type` forwarding count in `moui/moui.mbt`.

The API surface guard is separate from this maintenance baseline. It tracks
generated public API size, forbidden boundary tokens, and semantic API
classification budgets such as `app_constructor`, `advanced_core_protocol`,
`runtime_diagnostic`, `host_contract`, and `renderer_contract`. See
[API surface](api-surface.md) and
[API surface audit](api-surface-audit.md) before expanding public API.

Application performance guardrails are also separate from source-size and API
ratchets. `checks/performance-budgets.json` owns the reviewed thresholds and
update policy; `node scripts/validate-performance-budgets.mjs` validates the
catalog in the PR profile, while the macOS benchmark job compares real Skia
Raster samples and uploads the ignored result artifact. Do not weaken a
threshold to accommodate an unexplained regression or compare artifacts from a
different runner.

Current `max` values intentionally match today's debt so unrelated changes do
not need to solve the whole backlog. When a refactor splits a file, moves
control-level entrypoints into `views`, shrinks public surface area, or removes
root facade forwards, lower the corresponding budget in the same commit.

The default wrapper runs the `daily` scope. The MoonBit tool also supports a
full-workspace hotspot scope:

```sh
moon run tools/moui/validate_maintenance_baseline --target native -- --scope full
```

The `full` scope keeps the daily budgets and additionally scans addon/tool
workspace roots such as `moui_richtext`, `moui_skia`, `moui_sun`, `moui_theme`,
`moui_tests`, `moui_devtools`, `moui_webview`, `moui_agent*`, and `tools`.
Known large files have explicit full-only temporary budgets so broad validation
can report hotspots without forcing every 2k-4k line diagnostic/test file into
the daily baseline or this refactor. Split those files in focused follow-up
changes and ratchet their full-only budgets down as each split lands.

## Diagnostic Routes

Native WGPU is an **experimental** renderer diagnostic route. Its engineering
gate stays `diagnostic` — runnable, testable, allowed to record observation,
but **not** a default daily gate and carrying **no** product commitment. It
stays available through `sh scripts/check.sh --profile full` and focused
renderer/provider commands, but it is not the native mainline.

Design Systems is addon diagnostic coverage. `moui_theme` and
`examples/design_systems` remain important source-mapped preview/parity
surfaces, but they are not part of the core MoUI framework baseline. Run
`sh scripts/check.sh --profile theme` when changing `moui_theme` or
the Design Systems example.

Slow native example builds and matching-host platform runtime collection remain
opt-in through `--profile full`, real Skia smoke helpers, and direct
runtime logs.

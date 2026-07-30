# Project Invariants

This file collects every structural constraint in MoUI in a single,
scannable table. When you write or review a change, check the relevant rows.
If you must break an invariant, open an RFC first (see `GOVERNANCE.md`).

Agent map: `AGENTS.md`. Doc catalog: `docs/INDEX.md`. Package sketch:
`docs/architecture-map.md`. Taste rules: `docs/golden-principles.md`.
Mechanization batch1 (done): `docs/plans/done/harness-mechanize-invariants-batch1.md`.

## Package Ownership

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| P1 | App logic goes in `examples/<name>/app`; platform entrypoints are thin wiring | `validate-harness-invariants.mjs` (pr) | root `app.mbt` demos without `app/` package (e.g. agent_counter) |
| P2 | New built-in controls go in `moui/views` as concrete `@core.ViewNode` implementations constructed with `@core.View::from_node`; do not add core enum variants | `validate-harness-invariants.mjs` (pr) | devtools-only controls |
| P3 | Cross-runtime protocols + value types go in `moui/core`. Core carries no control vocabulary (ADR 0017); control theme tokens (`ButtonTheme`, `ControlStateTokens`, …) live in `moui/views` as `ControlThemeSet`. | `validate-core-theme-no-control-surface.mjs` | none |
| P4 | Runtime lifecycle, element/layout/render tree execution go in `moui/runtime` | code review | none |
| P5 | Host service contracts go in `moui/backend/host` (ADR 0018: contracts only — `HostRuntimeDriver`, `RedrawScheduler`, `HostWallClock` moved to `moui/runtime`; render completion moved to `moui/render`); concrete platform behavior in platform backends | `validate-host-import-baseline.mjs` | none |
| P6 | Renderer implementation and provider-ID capability reporting go in `moui/render/*`; platform composition roots own `RendererProviderBinding` assembly, while `RendererBackendKind` is diagnostic metadata only | `validate-renderer-provider-open-extension.mjs` + code review | none |
| P10 | Neutral close/focus/resize/scale/redraw/surface lifecycle and logical-coordinate conversion go through `moui/backend/platform_bridge`; native pointer/keyboard/IME/drag decode stays platform-local | `validate-platform-adapter-duplication.mjs` (pr) | WeChat `direct-canvas-callback`, validated without a `WindowEvent` import |
| P7 | Native Skia binding ownership + FFI borrow rules go in `moui_skia` | code review | none |
| P8 | App packages import `wzzc-dev/moui` + domain facades (`geometry`/`graphics`/`animation`/`text`/`state`) + `views` only | `validate-maintenance-baseline.mjs` | `showcase/app` for diagnostics; `for "test"` imports |
| P9 | App packages must not depend on `moui/runtime`, `moui/render/*`, concrete platform backends, renderer providers, or `moui_theme/*` (unless a design-system preview) | `validate-maintenance-baseline.mjs` | `showcase/app` |

## Platform and Renderer Status

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| R1 | Native Skia is the mainline; native WGPU is diagnostic | code review | RFC-required to reclassify |
| R2 | `SkiaGpuNative` is the product `auto` default on all native Skia platforms when a host GPU surface is available; `SkiaRasterNative` remains the explicit mode and sticky recovery fallback | `validate-renderer-provider-manifests.mjs` | none |
| R3 | Desktop entrypoints honor `--renderer auto\|skia-gpu\|skia-raster` (or `MOUI_SKIA_RENDERER`). Embedded-runtime entrypoints use `*_window_hosted`, import `wzzc-dev/window/<platform>`, construct `*EmbeddedRuntimeBackend`, and call `EventLoop.run_app`; the platform event loop is the only lifecycle, surface, and input path. | `validate-harness-invariants.mjs` (provider + window-hosted entrypoint + prepare support) | none |
| R4 | `moon.work` must not list `./window/modules/window` or `./window/modules/windowing` by default; use `sh scripts/window-dev-mode.sh on/off` | `validate-window-dependency.mjs` (daily CI) | explicit Provider Phase E consumer-proof window only: exact `checks/window-dependency-exception.txt`; turn dev mode off and remove it after the proof |
| R5 | `moon.work` must not list `./openseek`; `examples/mo_workbench` uses registry pin | `validate-maintenance-baseline.mjs` | none |
| R6 | Do not claim mobile runtime support as `passed` without matching-device evidence (pixels changed, input received, detach, IME, clipboard, accessibility, async image) recorded in `checks/platforms/*.json`. | code review + platform-status schema validation | fallback APK builds are packaging evidence only |

## Embedded-Runtime Platform Specific

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| M1 | Android: `window/android` owns Activity/JNI/CMake/Gradle template lifecycle and `HostCmd`; `backend/android` owns the typed adapter and contracts, and `backend/android/skia` owns the `ANativeWindow` Skia presenter. | code review | none |
| M2 | Android frames paced by `Choreographer`; input/resize must request redraw, not present synchronously | code review | none |
| M3 | iOS: `window/ios` owns UIKit lifecycle and template glue; `backend/ios` owns the typed adapter and contracts, while `backend/ios/skia` owns the UIKit presenter. | code review | none |
| M4 | iOS frames are paced by the platform event loop; keep `UILaunchScreen` and `UIApplicationSupportsMultipleScenes=false` in template Info.plists. | code review | none |
| M5 | HarmonyOS: `window/harmonyos` owns the ArkTS Stage Ability/XComponent/NAPI template at API 20; XComponent is the only pointer/surface/resize/detach source and ArkTS owns `displaySync`. | code review | none |
| M6 | Embedded runtime backends translate neutral lifecycle callbacks through `platform_bridge` into `HostCmd`/`HostEvent`; native input decode and runtime-session assembly stay platform-private. | API import whitelist + duplication validator + code review | none |
| M7 | Platform status uses `passed` (complete evidence), `partial` (useful but incomplete), or `failed` (no usable evidence). | platform-status schema validation | none |
| M8 | Mobile acceptance evidence requires clipboard write/read completion, two distinct surface sizes, accessibility tree/focus/action, async loading/ready logs | code review | none |
| M9 | `moui_cli` is the sole entry point for mobile build / run / verify; it stages and builds the matching `wzzc-dev/window` template. | code review | none |

## API and Code Discipline

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| A1 | Verify API existence in the exact imported package before use (`moon ide doc <pkg>.<fn>`) | `moon check` | none |
| A2 | Update `moon.pkg` imports when introducing a new `@pkg` prefix | `moon check` | none |
| A3 | Study all target platforms before cross-platform fixes (macOS/Linux patterns ≠ Windows patterns) | code review | none |
| A4 | Prefer existing helpers over inventing new conventions (e.g. `skia_test_temp_dir()`) | code review | none |
| A5 | Use `moon ide doc/outline/peek-def/find-references` for API discovery | — | none |
| A6 | After publishing a new `window` version, update the pinned version in all four consumers (`moui/`, `moui_skia/`, `moui_webview/`, `examples/markdown_editor/`) and run `moon update` | `validate-window-dependency.mjs` (shared pin + Fix/A6 anchors) | none |

## Button Styling Pipeline

When changing button colors or styles, update `docs/button-styling-guide.md` in the same change. The pipeline is:

```
ColorPalette/from_seed → ButtonTheme/ControlStateTokens/StateLayerTokens →
minimal_components/minimal_state_layer → ButtonVariant::style/to_token →
ButtonStyle::filled/tonal/outline/ghost/control_state → button/button_control paint
```

Files involved: `moui/core/theme.mbt` (neutral palette/spacing/typography only — no `components` field per ADR 0017), `moui/views/control_theme_tokens.mbt`, `moui/views/control_theme_set.mbt`, `moui/views/control_theme_resolver.mbt`, `moui/views/style_api.mbt`, `moui/views/control_style.mbt`, `moui/views/button.mbt`, `moui/views/control_primitives.mbt`.
Prefer app-level overrides over framework edits.

## Pre-push Validation

| Command | When |
|---------|------|
| `node scripts/validate-maintenance-baseline.mjs` | every commit |
| `node scripts/validate-api-surface.mjs` | every commit |
| `node scripts/validate-guidance-consistency.mjs` | every commit |
| `node scripts/validate-core-theme-no-control-surface.mjs` | every commit |
| `node scripts/validate-host-import-baseline.mjs` | every commit |
| `node scripts/validate-renderer-provider-open-extension.mjs` | renderer changes |
| `node scripts/validate-platform-adapter-duplication.mjs` | platform/backend changes |
| `moon check <package>` | during editing |
| `moon test <package> --target native` | during editing |
| `sh scripts/check.sh --profile daily` | before pushing core/view/render/backend changes |
| `sh scripts/check.sh --profile platform` | platform behavior changes |
| `sh scripts/check.sh --profile theme` | `moui_theme` or `design_systems` changes |

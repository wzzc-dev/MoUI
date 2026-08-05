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
| P1 | App logic goes in `examples/<name>/app`; platform entrypoints are thin wiring, discovered from `checks/platform-matrix.json`, contain at most two production `.mbt` files, with Native `main.mbt` at most 24 lines and Web/WeChat at most 40 lines. Because Moon exports only executable-owned definitions, Web/WeChat may use the second file solely for the validator-closed ABI callbacks that delegate directly to their backend. | `validate-harness-invariants.mjs` + `validate-platform-matrix.mjs` (pr) | root `app.mbt` demos without `app/` package (e.g. agent_counter) |
| P2 | New built-in controls go in `moui/views` as concrete `@core.ViewNode` implementations constructed with `@core.View::from_node`; do not add core enum variants | `validate-harness-invariants.mjs` (pr) | devtools-only controls |
| P3 | Cross-runtime protocols + value types go in `moui/core`. Core carries no control vocabulary (ADR 0017); control theme tokens (`ButtonTheme`, `ControlStateTokens`, …) live in `moui/views` as `ControlThemeSet`. | `validate-core-theme-no-control-surface.mjs` | none |
| P4 | Runtime lifecycle, element/layout/render tree execution go in `moui/runtime` | code review | none |
| P5 | App-facing capabilities live in `moui/services`; neutral backend protocols/DTOs live in root `moui/backend`; queues, registries, lifecycle/frame/input state, and service adapters live in `moui/backend/common*`; platform behavior stays in concrete backends. Root backend must not import common, runtime, or render. | `validate-host-import-baseline.mjs` + `validate-api-surface.mjs` + `validate-backend-common-boundary.mjs` | none |
| P6 | Renderer protocols/DTOs live in root `moui/render`; provider selection, fallback, workers, image lifecycle, and shared drawing algorithms live in `moui/render/common`; concrete implementations and decode/native bindings live in renderer subpackages. Backends must not import a concrete renderer. Executable composition roots assemble a renderer and platform backend through `@runtime.run_app(...)`. | `validate-api-surface.mjs` + `validate-backend-renderer-boundary.mjs` + `validate-renderer-provider-open-extension.mjs` | none |
| P10 | Neutral close/focus/resize/scale/redraw/surface lifecycle and logical-coordinate conversion go through `moui/backend/common`; native pointer/keyboard/IME/drag decode stays platform-local | `validate-backend-common-boundary.mjs` (pr) | WeChat `direct-canvas-callback`, validated without a `WindowEvent` import |
| P7 | Native Skia binding ownership + FFI borrow rules go in `moui_skia` | code review | none |
| P8 | App packages import `wzzc-dev/moui` + domain facades (`geometry`/`graphics`/`animation`/`text`/`state`) + `views` + `services` only | `validate-api-surface.mjs` | `for "test"` / `for "wbtest"` imports |
| P9 | App production dependencies must not include `moui/runtime`, `moui/backend/*`, `moui/render/*`, platform objects, renderer providers, or `moui_theme/*` (unless a design-system preview). Showcase diagnostics belong in its module-root integration package. | `validate-api-surface.mjs` + `validate-maintenance-baseline.mjs` | none |
| P13 | Business `Model` values are plain data. `init`/`update`/`view`/`subscriptions`/`commands` are the only app state and effect entrypoints; services, timers, routes, shortcuts, system menus, and context menus re-enter through typed `Msg`. `State`/`Cell`/`ScrollState` are limited to local UI transients. | reducer tests + code review | rich-text, focus, and scroll transients |
| P11 | Renderer provider budgets shrink-or-stay: growth in `RendererProvider` / `RendererProviderBinding` provider-ID and capability surface requires an RFC allowlist entry (ADR 0019) | `validate-renderer-provider-open-extension.mjs` + `validate-renderer-provider-manifests.mjs` | RFC allowlist entry |

## Platform and Renderer Status

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| R1 | Native Skia is the mainline; native WGPU is diagnostic | code review | RFC-required to reclassify |
| R7 | Sun CPU raster (`moui_sun` + `moui/render/sun`) is an experimental renderer: no product commitment, not on default composition roots, no `auto` selection; new sun capabilities are exceptions requiring an ADR note (ADR 0023) | code review | ADR 0023 |
| R2 | `SkiaGpuNative` is the product `auto` default on all native Skia platforms when a host GPU surface is available; `SkiaRasterNative` remains the explicit mode and sticky recovery fallback | `validate-renderer-provider-manifests.mjs` | none |
| R3 | Desktop entrypoints honor `--renderer auto\|skia-gpu\|skia-raster` (or `MOUI_SKIA_RENDERER`). Embedded-runtime entrypoints use `*_window_hosted`, import `wzzc-dev/window/<platform>`, construct `*EmbeddedRuntimeBackend`, and call `EventLoop.run_app`; the platform event loop is the only lifecycle, surface, and input path. | `validate-harness-invariants.mjs` (provider + window-hosted entrypoint + prepare support) | none |
| R4 | `moon.work` must not list `./window/modules/window` or `./window/modules/windowing` by default; use `sh scripts/window-dev-mode.sh on/off` | `validate-window-dependency.mjs` (daily CI) | none |
| R5 | `moon.work` must not list `./openseek`; `examples/mo_workbench` uses registry pin | `validate-maintenance-baseline.mjs` | none |
| R6 | Do not claim mobile runtime support as `passed` without matching-device evidence (pixels changed, input received, detach, IME, clipboard, accessibility, async image) recorded in `checks/platforms/*.json`. | code review + platform-status schema validation | fallback APK builds are packaging evidence only |

## Embedded-Runtime Platform Specific

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| M1 | Android: `window/android` owns Activity/JNI/CMake/Gradle template lifecycle and `HostCmd`; `backend/android` owns the typed adapter, neutral `ANativeWindow` surface/presenter, and host contracts; concrete renderer binding stays in `render/*` and the application entrypoint. | boundary validator + code review | none |
| M2 | Android frames paced by `Choreographer`; input/resize must request redraw, not present synchronously | code review | none |
| M3 | iOS: `window/ios` owns UIKit lifecycle and template glue; `backend/ios` owns the typed adapter, neutral UIKit/Metal surface presenter, and contracts; concrete renderer binding stays in `render/*` and the application entrypoint. | boundary validator + code review | none |
| M4 | iOS frames are paced by the platform event loop; keep `UILaunchScreen` and `UIApplicationSupportsMultipleScenes=false` in template Info.plists. | code review | none |
| M5 | HarmonyOS: `window/harmonyos` owns the ArkTS Stage Ability/XComponent/NAPI template at API 20; XComponent is the only pointer/surface/resize/detach source and ArkTS owns `displaySync`. | code review | none |
| M6 | `wzzc-dev/window/internal/embedded_dispatch` is stateless physical callback dispatch only. All Android/iOS/HarmonyOS logical phase, surface-generation, primary-window, detach, and application-exit state is owned by `EmbeddedWindowCoordinator` in `moui/backend/common`; session/renderer/redraw/IME assembly stays in `moui/backend/common/embedded`. | `validate-window-lifecycle-boundary.mjs` + host-sim tests + code review | none |
| M6a | Root `backend` uniquely owns neutral `HostService*` contracts; desktop routing lives in `backend/common/desktop`, embedded callback services in `backend/common/embedded/services`, and native filesystem/image sources in `backend/common/native`. | API surface + backend common boundary validators | none |
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
minimal_control_theme_set/minimal_state_layer → ButtonVariant::style/to_token →
ButtonStyle::filled/tonal/outline/ghost/control_state → button/button_control paint
```

Files involved: `moui/core/theme.mbt` (neutral palette/spacing/typography only — no `components` field per ADR 0017), `moui/views/style/control_theme_tokens.mbt`, `moui/views/style/control_theme_set.mbt` (incl. `views_ambient_control_theme` resolver), `moui/views/style/style_api.mbt` (ButtonVariant::style), `moui/views/views.mbt` (@style re-export facade), `moui/views/style/control_style.mbt`, `moui/views/style/control_primitives.mbt`, `moui/views/button/button.mbt` (button/button_control).
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
| `node scripts/validate-backend-renderer-boundary.mjs` | backend, renderer, or composition-root changes |
| `node scripts/validate-backend-common-boundary.mjs` | platform/backend changes |
| `moon check <package>` | during editing |
| `moon test <package> --target native` | during editing |
| `sh scripts/check.sh --profile daily` | before pushing core/view/render/backend changes |
| `sh scripts/check.sh --profile platform` | platform behavior changes |
| `sh scripts/check.sh --profile theme` | `moui_theme` or `design_systems` changes |

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
| P1 | App logic goes in `examples/<name>/app`; platform entrypoints are thin wiring | `validate-harness-batch1.mjs` (pr) | root `app.mbt` demos without `app/` package (e.g. agent_counter) |
| P2 | New controls go in `moui/views`, using `@core.View::node`; do not add core enum variants | `validate-harness-batch1.mjs` (pr) | devtools-only controls |
| P3 | Cross-runtime protocols + value types go in `moui/core` | code review | none |
| P4 | Runtime lifecycle, element/layout/render tree execution go in `moui/runtime` | code review | none |
| P5 | Host service contracts go in `moui/backend/host`; concrete platform behavior in platform backends | code review | none |
| P6 | Renderer implementation + capability reporting go in `moui/render/*` | code review | none |
| P7 | Native Skia binding ownership + FFI borrow rules go in `moui_skia` | code review | none |
| P8 | App packages import `wzzc-dev/moui` + domain facades (`geometry`/`graphics`/`animation`/`text`/`state`) + `views` only | `validate-maintenance-baseline.mjs` | `showcase/app` for diagnostics; `for "test"` imports |
| P9 | App packages must not depend on `moui/runtime`, `moui/render/*`, concrete platform backends, renderer providers, or `moui_theme/*` (unless a design-system preview) | `validate-maintenance-baseline.mjs` | `showcase/app` |

## Platform and Renderer Status

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| R1 | Native Skia is the mainline; native WGPU is diagnostic | code review | RFC-required to reclassify |
| R2 | `SkiaGpuNative` is the product `auto` default on all native Skia platforms when a host GPU surface is available; `SkiaRasterNative` remains the explicit mode and sticky recovery fallback | `validate-renderer-provider-manifests.mjs` | none |
| R3 | Mobile/desktop entrypoints accept `--renderer auto\|skia-gpu\|skia-raster` (or `MOUI_SKIA_RENDERER`) and record requested/selected modes; `auto` and `skia-gpu` select GPU when available, while `skia-raster` forces the CPU path | `validate-harness-batch1.mjs` (providers + mobile configure + prepare-native-build) | none |
| R4 | `moon.work` must not list `./window`; use `sh scripts/window-dev-mode.sh on/off` | `validate-window-dependency.mjs` (daily CI) | local development only |
| R5 | `moon.work` must not list `./openseek`; `examples/mo_workbench` uses registry pin | `validate-maintenance-baseline.mjs` | none |
| R6 | Do not claim mobile runtime support as `passed` without matching-device smoke evidence (pixels changed, input received, detach, IME, clipboard, accessibility, async image) | `validate_mobile_runtime_manifest` | fallback APK builds are packaging evidence only |

## Mobile-Specific

| # | Constraint | Detection | Exemption |
|---|-----------|-----------|-----------|
| M1 | Android: embedded-session route; `backend/android` owns contracts, `backend/android/skia` owns the `ANativeWindow` Skia presenter; `mobile/android` owns the canonical Kotlin/AndroidX shell, registered JNI, and Gradle/CMake template; `mobile/legacy/android` is Release N compatibility only | code review | none |
| M2 | Android frames paced by `Choreographer`; input/resize must request redraw, not present synchronously | code review | none |
| M3 | iOS: embedded-session route; `backend/ios` owns host contracts, `backend/ios/skia` owns the UIKit presenter; `mobile/ios` owns the canonical SwiftUI/CAMetalLayer shell, ABI bridge, plugin registry, and Xcode template; `mobile/ios/legacy` is Release N compatibility only | code review | none |
| M4 | iOS ABI v1 is single-scene; frames are paced by `CADisplayLink`; keep `UILaunchScreen` and `UIApplicationSupportsMultipleScenes=false` in Info.plists; simulator smoke uses `idb`/`idb-companion`, not `simctl` | code review | none |
| M5 | HarmonyOS: `mobile/harmonyos` owns the canonical ArkTS managed shell at API 20; XComponent is the only pointer/surface/resize/detach source; do not restore `.onTouch` or duplicate lifecycle calls; ArkTS owns `displaySync` | `validate-harmonyos-m5-shell.mjs` (pr profile) + `moui/mobile/harmonyos/tests/validate-managed-shell.mjs` | none |
| M6 | Mobile services cross `MobileHostChannel`; JNI/Obj-C++/NAPI adapters are thin wire translators only. The shared session core lives at `backend/internal/mobile_runtime`: MoonBit's internal visibility makes this package-private to all backend siblings, while `backend/host/internal` would incorrectly reject Android/iOS/HarmonyOS imports. | API import whitelist + code review | none |
| M7 | Mobile runtime manifests: `passed` (complete evidence) / `partial` (useful run with missing observations) / `failed` (no usable evidence); `--require-passed` rejects both `partial` and `failed` | `validate_mobile_runtime_manifest` | none |
| M8 | Mobile acceptance evidence requires clipboard write/read completion, two distinct surface sizes, accessibility tree/focus/action, async loading/ready logs | code review | none |

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

Files involved: `moui/core/theme.mbt`, `moui/core/theme_components.mbt`, `moui/core/theme_resolver.mbt`, `moui/views/style_api.mbt`, `moui/views/control_style.mbt`, `moui/views/button.mbt`, `moui/views/control_primitives.mbt`.
Prefer app-level overrides over framework edits.

## Pre-push Validation

| Command | When |
|---------|------|
| `node scripts/validate-maintenance-baseline.mjs` | every commit |
| `node scripts/validate-api-surface.mjs` | every commit |
| `node scripts/validate-guidance-consistency.mjs` | every commit |
| `moon check <package>` | during editing |
| `moon test <package> --target native` | during editing |
| `sh scripts/check.sh --profile daily` | before pushing core/view/render/backend changes |
| `sh scripts/check.sh --profile platform` | platform behavior changes |
| `sh scripts/check.sh --profile theme` | `moui_theme` or `design_systems` changes |

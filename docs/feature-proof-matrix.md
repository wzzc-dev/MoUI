# Feature Proof Matrix

This page maps every MoUI feature to the CI workflow and job that proves it.
"Proven" means the corresponding CI job passed on the matching host. Feature
status declarations live in `render/capabilities.mbt` and
`docs/renderer-capability-report.md`; this page tracks **proof coverage**, not
implementation status.

## Proof Levels

| Level | Definition | CI trigger | Host requirement |
|-------|-----------|------------|-----------------|
| **L1** | API correctness, algorithm correctness, protocol correctness | Every PR (`ci.yml`) | None (fallback-safe build) |
| **L2** | Runtime behavior on real renderer/platform | Every PR and push-to-main (`moui-renderer-real-skia-ci.yml`) | Matching-host real Skia |
| **L3** | Cross-platform consistency | `feature-proof-summary.yml` after `ci.yml` completes | All L2 platforms passed |

Framework rendering code (`moui/render/skia/`, `moui/views/`) depends on real
Skia linking provided by `moui_skia`. Any framework change can affect real
rendering behavior, so L2 real Skia smoke runs on every PR.

## L1 Features (ci.yml, every PR)

| Feature | Proof job | Platform | What passing proves |
|---------|-----------|----------|-------------------|
| Core API (View/Element/Layout/Animation) | `pr-profile` | macOS-14 | check.sh --profile pr: core package tests pass |
| Runtime lifecycle | `pr-profile` | macOS-14 | check.sh --profile pr: runtime effects/subscriptions/diagnostics |
| Views controls (Text/Button/TextField/Container/Row/Column/Flex/Stack/Scroll/List/Grid/Navigation) | `pr-profile` | macOS-14 | check.sh --profile pr: views package tests pass |
| Host services protocol (clipboard/menus/dialogs URL) | `pr-profile` | macOS-14 | check.sh --profile pr: backend/host package tests pass |
| Web wasm-gc build | `pr-profile` | macOS-14 | check.sh --profile pr: Web wasm-gc build succeeds |
| Renderer capability report consistency | `pr-profile` | macOS-14 | check.sh --profile pr: capabilities_test.mbt passes |
| Text conformance (grapheme/cluster/caret) | `pr-profile` | macOS-14 | `sh scripts/check.sh --profile full` includes text diagnostics |
| API surface stability | `api-surface` | macOS-14 | moon info drift check passes |
| Linux backend contracts | `linux-platform` | ubuntu-24.04 | `sh scripts/check.sh --profile platform` passes |
| Windows backend contracts | `windows-native` | windows-2022 | Windows backend MSVC tests pass |
| macOS packaging | `macos-packaging` | macOS-14 | Showcase app bundle packages successfully |
| Benchmark scaffold | `benchmark-scaffold` | macOS-14 | Benchmark targets build successfully |

## L2 Features (moui-renderer-real-skia-ci.yml, every PR and push-to-main)

All L2 features use release-provider real Skia with static linking. Each
platform job runs `verify-native-smoke-log` and `verify-acceptance-log` to
assert pixel markers and acceptance markers.

| Feature | macOS job | Linux job | Windows job | What passing proves |
|---------|-----------|-----------|-------------|-------------------|
| Rect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real Skia rect fill/stroke pixels |
| RoundedRect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real Skia rounded rect pixels |
| Gradient | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real Skia linear/radial gradient pixels |
| Shadow | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real Skia shadow blur pixels |
| Text | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real FontMgr fallback, glyph-run rendering |
| Image | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real PNG/JPEG decode and draw |
| Clip | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real rect/rounded/path clip pixels |
| Transform | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real affine transform pixels |
| Opacity | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real save-layer opacity pixels |
| LayerCompositing | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real layer/mask composition pixels |
| BlendMode | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real blend mode pixels |
| FilterEffect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real blur/saturation/color-matrix pixels |
| PathVector | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real path fill/stroke pixels |
| ShaderEffect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real procedural shader pixels |
| TextShaping | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real SkShaper/SkParagraph shaping, bidi Arabic/mixed-direction visual-order |
| EmojiText | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real emoji cluster rendering, keycap/regional-indicator/skin-tone-modifier fallback, deterministic color glyph format detection via `Typeface::has_color_glyphs` (font table tag query: COLR/sbix/CBDT/SVG), resolved font name in diagnostic (`resolved_font_name` field) |
| AsyncImage | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | Real second-frame repaint after completion, deferred-completion via HostNativeAsyncImageSource, off-main-thread local-file I/O plus Skia decode via platform native workers (GCD/pthread/CreateThread), decoded RGBA completion payloads with `background_io` and `background_decode` verification in provider tests |

## L3 Cross-Platform Consistency

Mobile host-channel, IME replacement/selection, semantics action validation,
renderer selection, and mailbox behavior have L1 package-test proof. Mobile L3
is separate and remains pending until each platform's release/manual
`mobile-runtime-smoke` manifest passes on a matching device or simulator. The
manifest requires before/after pixels, app receipt, actual detach, IME,
text/image clipboard, accessibility tree/focus/action, and async image.

Registered suites cover Android and iOS Counter/Component Gallery plus
HarmonyOS Demo/Component Gallery. GPU promotion is not part of current L1/L2
renderer proof; it needs the per-platform performance and recovery manifest in
`mobile-mainline-roadmap.md`.

## L2 GPU Direct Presentation Phase 1 Capability

Phase 1 of the GPU readback elimination plan has landed the direct GPU
presentation capability in source behind the `--renderer skia-gpu` opt-in
(see ADR 0006 and `.trae/documents/gpu-readback-elimination-plan.md`). The
capability is implemented per platform but `gpu_promoted` stays `false` on
every platform until Phase 2 matching-device evidence passes the seven ADR
0006 gates (`readbackEliminated`, `rendererThread`, `mailboxOk`,
`performance`, `memory`, `contextLoss`, `rasterFallback`).

| Platform | Backend | Surface route | Phase 1 source | Phase 2 promotion |
| --- | --- | --- | --- | --- |
| iOS | Metal | `MetalGpuSurfaceRoute` | implemented | pending matching-device manifest |
| macOS | Metal | `MetalGpuSurfaceRoute` | implemented | pending matching-device manifest |
| Android | Vulkan / GLES | `VulkanGpuSurfaceRoute` / `EglGpuSurfaceRoute` | implemented | pending matching-device manifest |
| HarmonyOS | EGL/GLES | `EglGpuSurfaceRoute` | implemented | pending matching-device manifest |
| Windows | Direct3D 11 | `Direct3DGpuSurfaceRoute` | implemented | pending matching-device manifest |
| Linux | Vulkan (Wayland) | `VulkanGpuSurfaceRoute` | implemented | pending matching-device manifest |

The Phase 2 promotion gate scaffolding has L1 package-test proof:

| Gate | Source | L1 proof |
| --- | --- | --- |
| Renderer mailbox control queue | `moui/render/render_frame_mailbox.mbt` | `moui/render` whitebox tests (capacity-two latest-wins; control messages never dropped) |
| Context-loss recovery state machine | `moui/runtime/renderer_recovery.mbt` | `moui/runtime` whitebox tests (Idle → Lost → Recovering → Recovered → Idle; terminal `FallbackToRaster`) |
| Manifest schema + `gpuPromotionEvidence` | `tools/moui/validate_mobile_runtime_manifest` | `validate_mobile_runtime_manifest_wbtest` (9 new Phase 2.3 tests) |

Phase 2 per-platform promotion flips `MobileRendererSelection::gpu_promoted`
to `true` only after the matching-device manifest passes `--require-passed`.

`feature-proof-summary.yml` runs after `ci.yml` or
`moui-renderer-real-skia-ci.yml` completes (via
`workflow_run`). It collects all job statuses from `ci.yml` and
`moui-renderer-real-skia-ci.yml`, generates a proof report, and verifies
coverage:

- L1 jobs must pass (ci.yml).
- L2 jobs must pass on all three platforms (moui-renderer-real-skia-ci.yml).

## Artifact Paths

| CI job | Artifact name | Content |
|--------|--------------|---------|
| `macos-real-skia` | `macos-renderer-real-skia-ci` | `moui_skia/logs/macos-*.log` (native/renderer/text-emoji/acceptance) |
| `linux-real-skia` | `linux-renderer-real-skia-ci` | `moui_skia/logs/linux-*.log` (native/renderer/text-emoji/acceptance) |
| `windows-real-skia` | `windows-renderer-real-skia-ci` | `moui_skia/logs/windows-*.log` (native/renderer/text-emoji/acceptance) |
| `summarize` | `feature-proof-summary` | `artifacts/feature-proof/proof-report.json` + `.md` |

## Adding CI Proof For A New Feature

1. If the feature is L1 (no real renderer needed): add a package test under
   the appropriate `moui/` package. The `pr-profile` job in `ci.yml` will
   pick it up via `check.sh --profile daily`.
2. If the feature is L2 (needs real Skia): add a smoke assertion to
   `moui_skia/scripts/native_smoke/` and update
   `moui_skia/native/capabilities.json` if needed. The
   `moui-renderer-real-skia-ci.yml` jobs will pick it up automatically.
3. Add the feature to the tables above.
4. Update `scripts/generate-feature-proof-report.mjs` feature list if a new
   L2 feature job name was introduced.

## Trigger Reference

| Workflow | Trigger condition | Paths filter |
|----------|------------------|-------------|
| `ci.yml` | push/PR to main | none (always) |
| `moui-skia-provider-fallback-ci.yml` | push/PR to main | `moui_skia/**` (moui_skia package self-test) |
| `moui-renderer-real-skia-ci.yml` | push/PR to main | none (validates framework rendering on push and every PR) |
| `moui-runtime-gates.yml` | schedule nightly + manual | none |
| `moui-macos-app-real-skia-manual.yml` | manual | none (MoUI macOS app/runtime validation) |
| `moui-skia-provider-macos-real-skia-manual.yml` | manual | none |
| `moui-skia-provider-linux-real-skia-nightly.yml` | weekly + manual | none |
| `moui-skia-provider-windows-real-skia-manual.yml` | manual | none |
| `moui-skia-provider-real-skia-acceptance.yml` | push-to-main + weekly + manual | `moui_skia/**` on push; none on schedule/manual |
| `feature-proof-summary.yml` | `workflow_run` on `ci.yml` or `moui-renderer-real-skia-ci.yml` completed | none |

# Feature Status Dashboard

This page tracks MoUI feature proof coverage. For implementation status
(supported/partial/gap), see
[renderer-capability-report.md](renderer-capability-report.md). For the
feature-to-CI-job mapping, see
[feature-proof-matrix.md](feature-proof-matrix.md).

The `feature-proof-summary.yml` CI workflow generates a proof report after
every `ci.yml` run. The latest report is available as the
`feature-proof-summary` artifact on the most recent `MoUI Feature Proof Summary`
workflow run.

## Proof Levels

| Level | CI workflow | Trigger | What it proves |
|-------|------------|---------|---------------|
| L1 | `ci.yml` | Every PR | API/algorithm/protocol correctness (no real renderer) |
| L2 | `moui-renderer-real-skia-ci.yml` | Every PR and push-to-main | Real Skia runtime behavior on matching host |
| L3 | `feature-proof-summary.yml` | After `ci.yml` completes | All required L1 and L2 passed |

## Renderer Feature Proof Status

All 17 renderer features from `RendererFeature` enum share the same CI job
mapping. L1 proof is always provided by `pr-profile` (package tests). L2 proof
is provided by the three platform jobs on every PR.

| Feature | L1 (ci.yml) | L2 macOS | L2 Linux | L2 Windows | L3 |
|---------|-------------|----------|----------|------------|-----|
| Rect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| RoundedRect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Gradient | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Shadow | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Text | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Image | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Clip | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Transform | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Opacity | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| LayerCompositing | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| BlendMode | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| FilterEffect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| PathVector | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| ShaderEffect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| TextShaping | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| EmojiText | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| AsyncImage | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |

## Release-Ready Coverage

`TextShaping`, `EmojiText`, and `AsyncImage` are now declared `supported` in
`renderer-capability-report.md` and in the structured capability API. Their
proof status:

### TextShaping

- **Implementation status**: supported
- **L1 proof**: `pr-profile` job passes (grapheme break, caret stabilization,
  UAX#29 fixture)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (SkShaper/SkParagraph smoke markers, bidi Arabic and
  mixed-direction visual-order markers via `--run-text-emoji-smoke`)
- **Release readiness**: ready. Runtime evidence is obtained automatically on
  every PR.

### EmojiText

- **Implementation status**: deterministic color emoji proven by
  `Typeface::has_color_glyphs` (font table tag query: COLR/sbix/CBDT/SVG);
  preflight readiness and emoji font fallback diagnostic now report
  runtime-determined `deterministic_color_emoji_ready` and `glyph_format`
  (rgba/alpha).
- **L1 proof**: `pr-profile` job passes (emoji cluster detection, caret
  stabilization, glyph format runtime check)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (emoji glyph/raster observation markers, keycap/
  regional-indicator/skin-tone-modifier fallback diagnostic markers via
  `--run-text-emoji-smoke`)
- **Release readiness**: ready. Runtime evidence is obtained automatically.

### AsyncImage

- **Implementation status**: supported (native Skia local-file sources use
  off-main-thread file I/O plus Skia decode into decoded RGBA completion
  payloads; provider tests assert `background_io` and `background_decode`)
- **L1 proof**: `pr-profile` job passes (HostAsyncImageLoader dedup, late
  callback gating, completion routing, drain_fn spawn/drain cycle,
  decoded payload header plus `background_io` / `background_decode` flags
  asserted in provider tests)
- **L2 proof**: `macos-real-skia` / `linux-real-skia` / `windows-real-skia`
  pass on every PR (second-frame repaint marker after local/data URI
  completions, deferred-completion marker after `HostNativeAsyncImageSource`
  completion via `--run-renderer-smoke`)
- **Release readiness**: ready. The `moui-renderer-real-skia-ci.yml` workflow
  automatically obtains second-frame and deferred-completion markers on all
  three platforms on every PR.
- **Runtime path**: Off-main-thread file I/O and Skia decode are implemented
  for local-file sources via platform native workers (GCD on macOS, pthread on
  Linux, CreateThread on Windows). `ImageResourceLoadCompletion` can carry
  decoded RGBA pixels, row bytes, `background_io`, and `background_decode`, and
  Skia applies decoded completions directly into the image cache.

## Mobile Status

Android, iOS, and HarmonyOS have source-level VSync and mobile service bridges.
HarmonyOS also has native-only XComponent pointer/lifecycle ownership and
touch-slop scroll arbitration.

Local Component Gallery `mobile-runtime-smoke` evidence (validator
`--require-passed`):

| Platform | Status | Artifact | Notes |
| --- | --- | --- | --- |
| iOS Simulator | **`passed`** | `artifacts/mobile-runtime/ios/component_gallery/` | Full service set (IME/clipboard/a11y/async-image/detach/resize/input/scroll). Metal GPU route. |
| Android emulator | **`passed`** | `artifacts/mobile-runtime/android/component_gallery/` | Full service set. Vulkan GPU route. Shell-side service smoke + semantics probe plan. |
| HarmonyOS device | **pending install** | rebuild + signed HAP required | Service-smoke code path is in tree; commercial MateBook-class hosts reject unsigned/OpenHarmony-community HAPs (`9568320` / `9568257`). Provide `MOUI_HARMONYOS_SIGNING_CONFIG(_FILE)` and re-run `scripts/harmonyos-mobile-runtime-evidence.sh`. |

CI entrypoints: `moui-ios-mobile-runtime-evidence.yml`,
`moui-android-mobile-runtime-evidence.yml` (self-hosted android),
`moui-harmonyos-mobile-runtime-evidence.yml` (self-hosted harmonyos + signing).

`SkiaGpuNative` carries unpromoted window-surface source paths per Phase 1 of
the GPU readback elimination plan (iOS/macOS Metal, Android Vulkan/GLES,
HarmonyOS EGL/GLES, Windows D3D12, Linux Wayland Vulkan). The native worker
proves safe `SkPicture`/POD handoff on an independent thread. Its macOS branch
now owns Ganesh/Metal context and drawable presentation and emits `Presented`
after a local first-frame smoke; remaining platform worker ownership and all
promotion manifests are still pending. The Phase 2 promotion gate scaffolding
has L1 package-test proof:

| Gate | L1 proof |
| --- | --- |
| Renderer mailbox control queue (`moui/render/render_frame_mailbox.mbt`) | `moui/render` whitebox tests (capacity-two latest-wins; `RendererControlMessage` never dropped) |
| Native Picture handoff (`moui_skia/native/skia_stub_gpu_worker.cpp`) | focused native tests (independent thread, retained picture, detach acknowledgement, zero readback counter) |
| Context-loss recovery (`moui/runtime/renderer_recovery.mbt`) | `moui/runtime` whitebox tests (Idle → Lost → Recovering → Recovered → Idle; `FallbackToRaster` after 2 failures) |
| Manifest schema + `gpuPromotionEvidence` (`tools/moui/validate_mobile_runtime_manifest`) | `validate_mobile_runtime_manifest_wbtest` (9 new Phase 2.3 tests) |

Product `auto` defaults to `SkiaGpuNative` on every native Skia platform when a
host GPU surface is available (`gpu_promoted` is `true` everywhere). Raster
remains the explicit/recovery path. Matching-device seven-gate manifests remain
the quality evidence bar; see ADR 0006 and `mobile-mainline-roadmap.md`.

## Evidence Traceability

| CI workflow | Artifact name | Content |
|------------|--------------|---------|
| `moui-renderer-real-skia-ci.yml` → `macos-real-skia` | `macos-renderer-real-skia-ci` | `moui_skia/logs/macos-*.log` |
| `moui-renderer-real-skia-ci.yml` → `linux-real-skia` | `linux-renderer-real-skia-ci` | `moui_skia/logs/linux-*.log` |
| `moui-renderer-real-skia-ci.yml` → `windows-real-skia` | `windows-renderer-real-skia-ci` | `moui_skia/logs/windows-*.log` |
| `feature-proof-summary.yml` → `summarize` | `feature-proof-summary` | `artifacts/feature-proof/proof-report.json` + `.md` |

## Update Rule

This dashboard is a static reference. The actual proof status is generated
dynamically by `feature-proof-summary.yml` after each `ci.yml` run. To check
the latest proof status:

1. Go to the **Actions** tab in the GitHub repository.
2. Find the **MoUI Feature Proof Summary** workflow.
3. Open the latest run and check the `GITHUB_STEP_SUMMARY` or download the
   `feature-proof-summary` artifact.

When a new renderer feature is added to `RendererFeature` enum in
`render/capabilities.mbt`, update:
1. `docs/renderer-capability-report.md` (implementation status)
2. `docs/feature-proof-matrix.md` (proof mapping)
3. This dashboard (feature row)
4. `scripts/generate-feature-proof-report.mjs` (feature list if a new L2 job
   name was introduced)

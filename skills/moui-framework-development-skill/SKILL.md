---
name: moui-framework-development-skill
description: Change MoUI framework internals and repository quality gates. Use when modifying moui/core, moui/views, moui/runtime, backend, platform backends, renderers, moui_skia, moui_theme, public API, pkg.generated.mbti, maintenance baselines, smoke/gates.json, scripts, CI workflows, docs, AGENTS.md, or repo-local skills.
---

# MoUI Framework Development

Use this skill for framework-layer changes. Preserve package ownership, public
API reviewability, and validation gates.

## Start Here

Read only what the task needs:

- `docs/architecture.md` for package roles and target routes.
- `docs/moui-app-package-boundary.md` for owning-package rules.
- `docs/development.md` for setup and focused package commands.
- `docs/testing.md` for Daily check, focused checks, and Manual smoke.
- `docs/release-readiness.md` for release gates and smoke catalog policy.
- `docs/window-hosted-moui.md` for mobile lifecycle, surface, input, and
  promotion ownership.
- `moui_skia/AGENTS.md` before changing `moui_skia` native/fallback binding
  ownership.

## Ownership Rules

- `moui/core`: cross-runtime protocols and neutral value types **only** — no
  control vocabulary (ADR 0017). Control theme tokens (`ButtonTheme`,
  `ControlStateTokens`, `ComponentThemes`, …) live in `moui/views` as
  `ControlThemeSet`. `InteractionState` and `PressableState` remain in core as
  neutral gesture/interaction state consumed by core's view-tree and gesture
  layers.
- `moui/{geometry,graphics,animation,text,state}`: app-facing domain facades
  and light extensions over `moui/core`; they may depend on `core`, but `core`
  must not depend on them or on `views`.
- `moui/views`: app-facing controls, control styles, default themes,
  form/navigation/data helpers, WebView facade, and concrete custom view
  behavior.
- `moui/services`: app-facing files, clipboard, URL, settings, appearance,
  application-menu, timer, and route contracts. It depends only on `core` and
  owns `AppServices`, `ServiceTask[T]`, `TimerSource`, `RouteSource`, and
  `AppEnvironment`.
- `moui/runtime`: runtime lifecycle, element/layout/render trees, event
  dispatch, effects, subscriptions, diagnostics, inspector snapshots.
- `moui/backend`: neutral event/window/service/input/IME/accessibility/
  platform-view protocols and DTOs, plus `HostServiceBridge` and
  `EmbedderHostChannel`. Per ADR 0018, `HostRuntimeDriver`,
  `RedrawScheduler`, and `HostWallClock` moved to `moui/runtime`; render
  completion and GPU recovery moved to `moui/render`. Host carries
  platform-neutral contracts only.
- `moui/backend/common`: stateless DTO conversion and cross-owner window-host
  workflows only. Stateful ownership is split across `common/lifecycle`
  (registry, requests, runtime slots, platform ID map, phase/generation and
  exactly-once close), `common/frame` (per-window renderer session, redraw,
  resize, present completion and IME frame hook), `common/image` (cancellable
  I/O tasks, tokenized completion, callback detach and cancellation),
  `common/input` (pointer/text/IME session), and `common/services` (service
  facade, async completion and bridge lifetime). Raw native input decoding
  stays in the concrete platform backend. Platform backends hold these owners
  directly and contribute `WindowSurfaceActions` to stateless workflows; do
  not add another aggregate coordinator.
- `moui/backend/common/services/desktop`: single synchronous desktop service
  router. macOS/Windows/Linux provide native closures and must not copy routing
  logic.
- `moui/backend/common/services/embedded`: single asynchronous mobile service
  queue for clipboard/platform-channel `Pending(id)`, FIFO drain, completion,
  duplicate rejection, and dispose/cancel.
- `moui/backend/common/services/native`: shared native `@fs` text, binary, and
  directory services used by desktop and embedded backends.
- `moui/backend/common/image/native`: shared filesystem image-byte source.
- `moui/backend/common/embedded`: embedded session capability layer
  (`HostedWindowBackend`, `HostedRuntimeSession`, `EmbeddedRuntimeHostBridge`),
  including renderer binding, IME, semantics, platform views, service update
  mapping, and native transport. `EmbeddedSession` composes
  `common/lifecycle::EmbeddedLifecycle` with the shared frame/image/input/
  services owners; it must not own a second phase, surface generation, or frame
  loop. Android/iOS/HarmonyOS `window_hosted.mbt` are thin shells.
- `moui/backend/{macos,windows,linux}`: native host backends that own the host
  runtime, native windows, and event-loop integration.
- `moui/backend/{android,ios,harmonyos}`: embedded runtime backends. The
  platform `wzzc-dev/window` embedder owns lifecycle, surfaces, input, and the
  event loop; MoUI owns the attached runtime session and neutral presenter.
- `moui/backend/<platform>` owns native windows/handles, CPU presentation, GPU
  descriptors, host I/O, and lifecycle only. It must not import or construct a
  concrete renderer.
- `moui/render`: renderer-neutral frame/image/descriptor DTOs plus opaque
  `HostSurface`/`NativeSurface` capabilities and the two lifecycle contracts
  `RendererProvider` and `RendererSession`. Application entrypoints register
  ordered providers and one platform entry; root render has no platform or
  graphics-API surface tag. `RendererBackendKind` is diagnostic only.
- `moui/render/common`: provider selection, fallback, mailbox/GPU worker,
  image lifecycle/repaint, and shared drawing algorithms.
- `moui_skia_renderer`: native Skia CPU/GPU providers, renderer, and
  renderer-local `NativeGpuPlatform`/`SkiaSurfaceRoute` policy over `moui_skia`.
- `moui_web_renderer`: browser WebGPU host-import adapter for
  `wasm-gc`.
- `moui_wgpu_renderer`: experimental native WGPU renderer.
- `moui_sun_renderer`: experimental Sun CPU raster renderer over `moui_sun`.
- `moui_tests`: unpublished integration tests, benchmarks, renderer smokes,
  and tester smokes. Production unit tests remain with their owning module.
- `moui_skia`: Skia binding, native capability manifests, fallback parity, FFI
  ownership, and native smoke marker coverage.
- `moui_theme`: optional design-system addon diagnostics and theme builders.

Do not add a new public package until the existing owning packages cannot
naturally own the capability.

## Architecture Convergence Pointers (ADR 0017–0027)

When touching a convergence surface, run its matching gate in addition to the
focused checks below:

- **Host split (ADR 0018)**: `HostRuntimeDriver`, `RedrawScheduler`, and
  `HostWallClock` live in `moui/runtime`; render completion / GPU recovery
  live in `moui/render`. `moui/backend` stays contracts-only in default
  imports. Gate: `node scripts/validate-host-import-baseline.mjs`.
- **Renderer provider/session (ADR 0019/0027)**: renderer implementations,
  provider-ID capability reporting, and platform-handle interpretation go in
  `moui_*_renderer`. Composition roots assemble ordered `RendererProvider`
  values; each successful bind returns one per-window `RendererSession`.
  Rejection is side-effect free and session disposal is idempotent.
  `RendererBackendKind` is diagnostic metadata only. Gate:
  `node scripts/validate-renderer-provider-open-extension.mjs`.
- **Backend common boundary (ADR 0020/0025)**: neutral close/focus/resize/scale/redraw/
  surface lifecycle and logical-coordinate normalization go through
  `moui/backend/common`; native pointer/keyboard/IME/drag decode
  stays platform-local. Gate:
  `node scripts/validate-backend-common-boundary.mjs`. The gate has no
  duplication budget or allowlist; shared behavior must move to its owner.
- **Window lifecycle owner (ADR 0024/0025)**: `wzzc-dev/window/internal/embedded_dispatch`
  is physical callback dispatch only. All seven platforms enter
  the matching backend-common owner; embedded session assembly remains in
  `backend/common/embedded`, which must not grow a second lifecycle, surface
  generation, or frame loop.
  Gate: `node scripts/validate-window-lifecycle-boundary.mjs`.
- **Theme layering (ADR 0017)**: `moui/core` carries no control vocabulary;
  control theme tokens live in `moui/views` as `ControlThemeSet`. Gate:
  `node scripts/validate-core-theme-no-control-surface.mjs`.
- **Sun CPU raster (ADR 0023)**: `moui_sun` + `moui_sun_renderer` is an
  experimental renderer — no product commitment, not on default composition
  roots, capability freeze by default. New sun capabilities are exceptions
  requiring an ADR note.

## Public API Workflow

1. Locate the owning package and inspect `moon.pkg`.
2. Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` before adding or renaming public symbols.
3. Add focused black-box tests for public behavior; use white-box tests only
   when private internals matter.
4. Run `moon info` after public API changes.
5. Review `pkg.generated.mbti` diffs and keep them committed when intended.
6. Run `node scripts/validate-api-surface.mjs`.

Use `#alias(old_api, deprecated)` only when compatibility is intentionally
preserved. The default for this repo is to keep public surface small and
owning-package boundaries clear.

## Package Map

- `core/`: one MoonBit foundation package for cross-runtime protocols and
  neutral value types: `View`, `Program` / `Effect` / `Subscription`, geometry,
  input, layout, paint/draw command protocols, semantics, text contracts, theme
  token schema, and custom view callback contracts. Concrete controls, routing
  helpers, rich text documents, runtime diagnostics, and platform services live
  outside `core`. Keep files grouped by responsibility
  (`runtime_state`,
  `component_context`, `input_*`, `paint_*`, `rich_text_*`) without adding
  subpackages.
- root `moui`: app-loop public facade for `View`, `Program`, `Effect`,
  `Subscription`, `Theme`, `Environment`, and `ViewEnvironment`. It does not
  import runtime, expose `run_app`, import `moui_theme`, or replace the domain
  facades.
- `geometry/`, `graphics/`, `animation/`, `text/`, `state/`: app-facing domain
  facades over `core`. Use them for high-frequency geometry, paint/drawing,
  transition/easing, text, and state/focus value types. They are not `core`
  dependencies.
- `views/`: public view constructors, command/menu facade, control styles,
  default themes, form/navigation/data helpers, WebView facade, `DateValue`
  compatibility facade, and concrete custom view behavior. It should not become
  a catch-all re-export surface for low-level drawing, animation, focus,
  semantics, runtime id, or component kernel types.
- `services/`: app-facing typed service tasks and timer/route subscriptions.
  Host request ids, bridge protocols, and completion queues do not cross this
  package boundary.
- `moui_theme/common/`: repo-local addon common package for shared
  source-mapped design-system
  manifests, golden token mappings, golden source-usage audits,
  source-lock quality reports, source-package inventories,
  source-imported token records with pinned file shas, raw source expressions,
  official-anchor coverage gaps, manifest/golden integrity reports, runtime
  token alignment reports for resolved source values,
  official-token/source-lock coverage, adaptation-difference reports,
  token taxonomy reports, semantic palette role reports, typography role reports,
  component-token matrices, semantic/component token models, density and
  variant adapters, coverage metadata, and custom token/theme helpers that return
  platform-neutral
  `@core.Theme` values; it may depend on `wzzc-dev/moui/core`, while
  `moui/core`, `moui/views`, and the root `wzzc-dev/moui` workspace member must
  not depend on `moui_theme`. `moui_theme/material`, `moui_theme/carbon`,
  `moui_theme/primer`, and `moui_theme/fluent` expose package-local
  official-system entrypoints over the common model for light/dark/high-contrast
  and system themes, tokens, manifests, reports, and component matrices.
  Concrete design-language names stay here rather than in `core` or `views`.
  External presets stay source-mapped previews until
  tests prove
  official source, token category, variant, component-token, customization,
  official-token golden mapping coverage, golden mapping source usage, stable
  source version locks, source-package import coverage,
  source-imported token source-lock coverage, source-imported token
  official-anchor coverage, source-imported token manifest/golden integrity,
  runtime token alignment, token taxonomy parity, semantic palette role parity,
  typography role parity,
  component-token matrix coverage plus
  adaptation-difference closure.
- `backend/`: shared `Event`, surface metrics, input contracts, window scene
  resolver, and neutral host protocols. Stateful registry/runtime slots,
  platform-window mapping, renderer-session frame state, and tokenized image
  I/O task delivery remain in their owning common packages. Renderer resource
  status, cache residency, repaint revisions, and image diagnostics stay in
  renderer sessions rather than backend mirrors,
  image-resource load completion apply bridge,
  native async image loading-record scheduler,
  native provider async-image scheduling hooks,
  native async image completion source and deferred native completion request source,
  host-event subscription source fanout, window-scoped subscription source,
  platform event-source bundles for feeding normalized Web/native host and window
  events into integration subscriptions,
  window request/completion queue, text-input session, window-event conversion,
  async host-service queue, and frame-aware redraw driver with
  idle/scheduled/in-frame/follow-up coalescing, and native WebView
  capability/command/event contracts.
- `backend/web/`: wasm-gc Web host, canvas constraints, resolver-backed
  multi-canvas window slots, browser runtime bridge, async browser
  file-open/save text completion for shared text-file reads/writes, and
  accessibility adapter. Web reports `web_view` unavailable and must not use an
  iframe overlay as a substitute for native WebView.
- `backend/macos/`: AppKit/window host, resolver-backed multi-window slots,
  native WKWebView platform-view sync, CPU presenter, and neutral CAMetalLayer surface.
- `backend/windows/`: Win32/window host, resolver-backed multi-window slots,
  optional WebView2 platform-view sync, CPU presenter, and neutral HWND surface.
- `backend/linux/`: Wayland host over `wzzc-dev/window@0.5.4-0.1.5`, Linux
  host-service bridge, text-input/IME request sync, drag/drop conversion, a
  neutral CPU presenter plus Wayland GPU surface descriptor,
  optional WebKitGTK platform-view sync, shared host event conversion, and
  explicit native menu/AT-SPI follow-up reporting. Its RISC-V64 architecture
  variant uses the existing Linux route with `riscv64-linux-gnu` glibc and
  Skia Raster static linking; use
  `scripts/prepare-linux-riscv64-sysroot.sh` and
  `scripts/linux-riscv64-cross-build.sh --sysroot PATH --run-qemu` for
  non-blocking L0-L2 evidence. QEMU offscreen smokes do not promote Wayland L3.
- `backend/android/`: Android embedded runtime backend. `window/android` owns
  the Kotlin/AndroidX template, native event queue, lifecycle, surface, and
  input; the backend translates window events and supplies a neutral
  `ANativeWindow` presenter/surface kit. Package checks are not runtime platform evidence. Use
  `MOUI_SKIA_PLATFORM=android` plus `MOUI_SKIA_ARCH=<arch>` for Android Skia
  cross-build checks.
- `backend/ios/`: iOS embedded runtime backend. `window/ios` owns the UIKit
  template and event-loop callbacks; the backend translates them and supplies
  a neutral UIKit/Metal presenter/surface kit. Package checks are not runtime platform evidence. Use
  `MOUI_SKIA_PLATFORM=iosSim` plus `MOUI_SKIA_ARCH=<arch>` for iOS Simulator
  Skia cross-build checks.
- `backend/harmonyos/`: HarmonyOS embedded runtime backend. `window/harmonyos`
  owns Stage Ability/XComponent/NAPI lifecycle, native surface acquisition, and
  input callbacks; the backend translates them and supplies a neutral native-
  window presenter/surface kit. Package checks are not runtime platform evidence.
  API 20 is the compatibility floor. Native XComponent callbacks exclusively
  own surface/pointer/resize/detach; ArkTS owns displaySync and platform services.
- HarmonyOS composition entrypoints supply `moui_skia_renderer` providers. Use
  `MOUI_SKIA_PLATFORM=harmonyos`, `MOUI_SKIA_ARCH=arm64`, and static linking
  for `auto` / `skia-gpu` HarmonyOS cross-build checks. The locked
  `libskia.so` hides Ganesh internal symbols required by the separate
  `libskia_ganesh_ext.a`; dynamic linking remains supported only for explicit
  `skia-raster` builds.
- `examples/harmonyos_demo`: standalone experimental HarmonyOS demo with a
  window-hosted entrypoint. Use `moui build harmonyos harmonyos_demo` for the
  template-driven build; matching device or emulator evidence is still required
  before claiming runtime support.
- `examples/showcase/harmonyos_window_hosted` is the Showcase mobile entrypoint.
- Showcase's mobile entrypoints open the Platform workspace's `Mobile Service Probe`
  for matching-host IME, system text clipboard, accessibility action,
  rotation/resize, scroll, and async-image evidence. The mobile recorder only
  accepts clipboard write/read, two distinct surface sizes, accessibility
  tree/focus/action, and async loading/ready application logs.
- Platform status is `passed`, `partial`, or `failed`. Use `partial` when
  useful runtime evidence exists but required observations are missing.
- `moui/render`: renderer facade, shared draw helpers, and capability report API.
- `moui_skia_renderer`: native Skia raster mainline renderer over the local
  `moui_skia` binding, including renderer-local command/reason diagnostics for
  unsupported Skia fallbacks, renderer-local image-resource lifecycle change
  callbacks, and `skia_image_load_completion` source decode completion payloads
  through renderer-owned decode of backend-supplied `HostImageSource` bytes. The
  binding/renderer may expose an explicit macOS Metal/Ganesh GPU context and
  offscreen GPU surface preflight, but provider/window GPU presentation remains
  separate matching-host evidence and must not replace the raster mainline
  without real smoke proof. Host-layer completion routing and platform redraw
  scheduling from async image load/error notifications
  remain outside `moui_skia_renderer`.
- `moui_wgpu_renderer`: experimental native wgpu renderer, including a renderer-owned
  byte decoder used by provider-created image loader hooks.
- `moui_sun_renderer`: **experimental** Sun CPU raster renderer over the
  repo-local `moui_sun` workspace (ADR 0023: experimental, capability freeze
  by default, not on default composition roots). It renders rects, rounded
  rects, paths, gradients, text (via moui_sun/text FontFace), images
  (PNG/BMP data URIs), shadows, layers, filters, and shader effects.
  TextShaping, EmojiText, and AsyncImage remain tracked as gaps; new
  capabilities are exceptions requiring an ADR note.
- `moui_wgpu_renderer/cosmic_text`: standalone Moon Cosmic provider.
- `moui_wgpu_renderer/coretext`: macOS CoreText provider.
- `moui_wgpu_renderer/directwrite`: Windows DirectWrite scaffold.
- `moui_wgpu_renderer/fontconfig`: Linux fontconfig/FreeType provider boundary with
  a narrow native color-emoji path and Cosmic fallback for general text.
- `moui_wgpu_renderer/text_protocol`: shared native text provider payload protocol.
- `moui_web_renderer`: wasm-gc bridge to browser WebGPU host imports, with
  Canvas2D/WeChat under `moui_web_renderer/canvas2d`.
- `moui_tests/skia_renderer_smoke/native`: opt-in real Skia renderer smoke that
  verifies MoUI draw commands against captured Skia presenter pixels and checks
  async image second-frame repaint through the host completion route.
- `moui_tests/skia_text_emoji_smoke/native`: opt-in real Skia text/emoji proof
  smoke that records renderer-proof markers only after captured Skia pixels and
  font/glyph metadata plus text-system evidence prove color emoji, ZWJ
  grapheme, paragraph wrapping, and bidi observations. Native paragraph
  wrapping, bidi layout, and selection-rectangle proof must use the real
  SkParagraph path and include `engine=skparagraph` markers.
- `moui_tests/text_conformance/{native,web}`: opt-in diagnostic text matrix
  packages for comparing supported text systems and documented gaps.
- `examples/*/app`: shared application logic.
- `examples/*/{web_wasm,<platform>_<renderer>}`: platform/renderer profile
  entrypoints where an example has a runnable host package.
- `examples/webview_demo/{app,macos_skia,windows_skia,linux_skia,web_wasm}`:
  native WebView host-contract demo; Web wasm is an unavailable fallback and
  not an iframe implementation.
- `examples/showcase/{macos_skia,windows_skia,linux_skia}` and
  `examples/markdown_editor/macos_skia`: recommended native Skia renderer
  example entrypoints.
- `examples/design_systems/{web_wasm,macos_skia}`:
  dedicated design-system addon diagnostic sampler entrypoints over the shared
  `examples/design_systems/app` logic.
- `examples/pdf_workbench/app`, `examples/pdf_workbench/pdflite_adapter`, and
  `examples/pdf_workbench/macos_skia`: lightweight PDF UI shell, separate
  `pdflite` adapter checks, and native Skia mainline entrypoint.
- Canonical `examples/showcase/{macos_wgpu,windows_wgpu,linux_wgpu}` routes use
  the platform font provider with Cosmic as an internal fallback; do not add a
  second provider-specific WGPU composition root.
- `examples/showcase/{macos_sun,windows_sun,linux_sun}`: Sun CPU raster
  entrypoints. Do not add Markdown Editor Sun entrypoints until text and
  editor runtime evidence exists.

## Development Workflow

1. Confirm the user goal and non-goals.
2. Read the relevant docs and `moon.pkg` package boundary.
3. Prefer `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` for MoonBit API discovery.
4. Keep edits small and package-local.
5. Preserve `///|` delimiters.
6. Add or update focused package tests.
7. Run targeted validation first.
8. Run `moon fmt`.
9. Run `moon info` after public API changes.
10. Update docs, `AGENTS.md`, and repo-local skills when guidance changes.
11. Report changed files, validation commands, and remaining risks.

## Validation Commands

Daily check:

```sh
sh scripts/check.sh --profile daily
```

The daily check runs `node scripts/validate-window-dependency.mjs`, which
confirms that all known consumers pin the same published
`wzzc-dev/window@0.5.4-0.1.5` version and that `moon.work` does not include a
local window checkout.
Keep the root README focused on reviewer/user quick paths; detailed `window/`
submodule and local-source instructions belong in `docs/development.md` and this
skill. Ordinary MoUI framework work should resolve `wzzc-dev/window` from
mooncakes.io. When a task explicitly requires editing window source, initialize
the `window` submodule if needed, run `sh scripts/window-dev-mode.sh on`, make
the dependency changes, validate them through MoUI, then run
`sh scripts/window-dev-mode.sh off` before committing so `moon.work` returns to
the published dependency.
Use `scripts/run-window-package-smoke.sh <platform>` for matching-host smoke
runs from the resolved package instead of creating a local window checkout. Run
`moon update` if the package cache is stale or missing. The MoonBit package
ecosystem is still maturing, so dependency resolution, registry cache state, and
package regressions are plausible causes for otherwise surprising failures.
Treat those window smoke helpers as dependency-level matching-host evidence,
not as a replacement for MoUI Showcase/Markdown Editor platform entrypoint
validation.
`moui_sun` is a repo-local editable workspace member under the single
`wzzc-dev/moui_sun` module. Keep Sun graphics/text/softbuffer surface area and
its provider in `moui_sun_renderer`; platform presentation stays renderer-neutral.
The daily profile also runs `moon test moui_skia --target native`. The binding
status/capability files and `verify-platform-status.sh` /
`verify-native-capability-contract.sh` are validated by the dedicated
`.github/workflows/moui-skia-provider-fallback-ci.yml` workflow; run those
scripts explicitly when changing binding metadata. Treat those checks as
binding-level provider/status evidence. MoUI renderer pixels and platform
runtime behavior still need the opt-in real Skia smoke or matching-host example
runs.
The runnable `moui_skia` binding/provider GitHub Actions workflows live in the
repository root as `.github/workflows/moui-skia-*.yml`, and Copilot setup lives
at root `.github/workflows/copilot-setup-steps.yml`. Keep workflow files there
while `moui_skia` is a workspace member; nested workflow files are not
discovered by GitHub Actions in the monorepo. The
`.github/workflows/moui-renderer-real-skia-ci.yml` workflow is
MoUI-owned integration proof, not a package-owned `moui_skia` workflow.
The daily profile also runs the maintenance/API/source-policy guards, generated
repository and website docs checks, renderer/provider and mobile-config guards,
GPU/smoke catalog checks, MoonBit format/workspace/interface drift checks,
focused framework/app tests, Showcase and Markdown Editor Web builds, and the
validator/runner self-tests listed in `checks/profiles.json`. The interface
drift step snapshots tracked interface files before running workspace-wide
`moon info`, so existing local changes may be validated while newly generated
drift still fails.
`ci.yml` uses `sh scripts/check.sh --profile pr` for the PR profile gate and
`sh scripts/check.sh --profile platform` for Linux platform contracts. The
Windows MSVC job keeps setup/build/package steps explicit and only verifies the
PowerShell wrapper dry-run plan with
`powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit`.
The `platform` profile starts with shared platform service checks, while
host-specific backend/provider tests live in `checks/profiles.json`.
Use `sh scripts/check.sh --profile theme` for `moui_theme` and Design
Systems addon diagnostic coverage. Keep `docs/testing.md` and repo-local skills
synchronized when adding or removing daily quality gates.
For Web runtime evidence, use `record-web-runtime-presentation.mjs` to collect
the browser-session artifact, then fold it into
`platform-runtime-evidence.json` with
`record-platform-evidence-manifest.mjs ... web --web-presentation-manifest ...`.
When Web folding runs in GitHub Actions, expect `github-actions` provenance
from the successful non-skipped job/run. When it runs locally, expect
`matching-host-artifact` provenance for the browser-session manifest and
screenshots. Do not invent CI run URL, runner, or job fields for local
artifacts.
The canonical Actions job for Web browser-session evidence is
`web-runtime-presentation`; it runs `scripts/ci-web-runtime-presentation.sh` to
build Showcase and Markdown Editor Web wasm-gc targets, serve the repository,
start Chrome CDP, record and fold the presentation manifest, validate the Web
platform entry, and upload `moui-web-runtime-presentation` artifacts.
Renderer proof is tracked separately in schema v1 manifests under
`artifacts/conformance/renderer-proof/<backend>-<platform>.json`. Validate them
with `scripts/validate-renderer-proof-manifest.mjs`; passed entries require
GitHub Actions provenance plus exactly `radialGradient`, `transformPixels`,
`colorEmojiPixels`, `zwjGrapheme`, `bidiLayout`, `paragraphWrapping`,
`selectionRects`, `graphemeEditing`, `imeCandidateAnchor`,
`imeCompositionVisual`, and `asyncImageSecondFrame` observations with strong
marker tokens. Passed
`colorEmojiPixels` observations must also include `font-metadata` /
`glyph-metadata` evidence and structured metadata fields, including a non-empty
glyph key plus positive glyph width/height; native Skia color emoji proof must
also include `fallback-request`, `emoji-hint`, and `stable-glyph-key` tokens
plus fallback script/language tag-list/count metadata, resolved missing-glyph count,
fallback request character metadata, missing-glyph recovery readiness, and a
glyph key that contains the recorded
source/text-system/shaper/script/language-tags/language-count/fallback-request-character/format metadata. Native Skia `paragraphWrapping`,
`bidiLayout`, and `selectionRects` observations must include SkParagraph
markers such as `native_paragraph_ready=true`, `bidi_visual_order_ready=true`,
`line-metrics`, `later-line-pixels`, `visual-order`, `selection-rects`,
`line-range`, `rect-geometry`, and `hit-test` as appropriate. Package-only tests, skipped jobs,
missing uploaded artifacts, blank screenshots, caret-only
diagnostics, heuristic visual-order logs, fallback paragraph geometry,
coverage-only font matching, provider preflights,
preflight-only checks, and fallback-safe descriptor audits must stay failed
proof. Complete local observations may be
preserved for debugging, but without GitHub Actions provenance the manifest
status stays failed. The native Skia proof matrix
configures the locked release Skia artifact with required SkParagraph support
before running real renderer/text smokes. Native WGPU proof remains a
non-blocking diagnostic and still requires a
usable runner WGPU adapter for offscreen readback.
Native Skia `graphemeEditing`, `imeCandidateAnchor`, and
`imeCompositionVisual` renderer-proof markers come from the text/emoji smoke's
shared grapheme-boundary contract, host IME request diagnostics including UTF-8
cursor/anchor offsets plus composition cursor evidence, Skia caret geometry,
and captured text-field composition pixels; they do not replace matching-host
native IME runtime evidence.
The `renderer-proof-summary` job requires the native Skia macOS, Windows,
Linux, and WebGPU wasm proof
artifacts to validate as passed before mainline capability promotion; native
WGPU diagnostic artifacts are uploaded separately but do not block the summary.
The platform evidence manifest is schema v2 and records the
`wzzc-dev/window@0.5.4-0.1.5` package monitor/cursor probe as
`monitorCursor`; native passed entries must set it to
`yes`, while Web browser-session evidence may leave it pending. Native passed
entries must also set `imeCandidateAnchor`, `imeSurroundingText`,
`imeCompositionVisual`, `imeCommitDelete`, `imeCursorUpdate`,
`imeScrollAnchor`, `imeScaleDprAnchor`, and `imeResizeAnchor` to `yes` from
matching-host Showcase
runtime artifacts; host-core unit tests, package logs, provider preflights, and
coarse `textInput` observations are not enough. Native entries
also record a `skiaEvidence` block for Skia provider/preflight commands,
fallback-unavailable checks, real-renderer smoke, async image second-frame
smoke, and Showcase first-frame status. Any `status=passed` platform
entry, and any
`skiaEvidence.status=passed` route, must include `evidenceProvenance` that
traces the claim to a non-skipped successful GitHub Actions job/run or to a
matching-host artifact bundle. Build-only jobs, package-only jobs,
provider/preflight summaries, dependency smokes, and skipped workflow-dispatch
paths are not runtime proof. `artifacts/platform-evidence/*/README.md` files
are placeholder documentation and must not be used as passed platform, Skia, or
provenance artifacts. `skiaEvidence.status=passed` is Skia-route
evidence, not a complete platform-services claim by itself, but native platform
entries cannot be marked `passed` unless their Skia evidence is also `passed`.
Use `record-native-ime-evidence.mjs` for matching-host IME logs when you only
want to validate and update native IME observations; it deliberately leaves the
broader platform runtime status unchanged and rejects generic host unit-test or
package logs without matching-host runtime, native-app, `renderer=application`,
matching app, platform-protocol,
candidate-anchor, surrounding-text, composition, commit/delete, cursor, scroll,
scale/DPR, resize, and Showcase markers. The `renderer=application`, app, and
platform-protocol markers are exact whitespace-delimited tokens; suffixed
labels are not matching-host runtime IME evidence. Renderer-route identity
comes from the recorded composition-root command and renderer artifact, not
from a concrete renderer name emitted by the backend.
For macOS, the first-party producer is the Showcase native Skia
entrypoint with
`MOUI_MACOS_NATIVE_IME_EVIDENCE=1 moon run examples/showcase/macos_skia --target native`;
store that run as
`artifacts/platform-evidence/macos/ime-showcase-runtime.log` and pass it to
each macOS native IME recorder log option after confirming it prints the
Showcase marker. The macOS recorder also requires AppKit
`NSTextInputClient` markers: candidate/surrounding/composition logs must include
`appkit-setMarkedText` and `appkit-firstRectForCharacterRange`, and
post-commit logs, including commit/delete, cursor, scroll, scale/DPR, resize,
and Showcase runtime markers, must include `appkit-insertText`.
Use
`record-native-skia-evidence.mjs` for matching-host Skia logs when you only
want to validate and update `skiaEvidence`; it deliberately leaves the broader
platform runtime status unchanged. Its provider-preflight log check requires
both the matching Skia provider identity and a passing preflight, test, or build
marker; do not use generic passing test output as provider evidence. Its
Showcase and Markdown Editor first-frame checks require app-identifying
`title=MoUI Showcase` and `title=MoUI Markdown Editor` markers on the platform
first-frame line, respectively.
Use `record-macos-platform-runtime-evidence.mjs` only for macOS platform
promotion after macOS `skiaEvidence` is passed and every native IME observation
has already been recorded by `record-native-ime-evidence.mjs`. The macOS helper
validates the `wzzc-dev/window@0.5.4-0.1.5` package runtime smoke transcript
through `--window-smoke-log` for window/open/resize/redraw/input/monitor/cursor/shutdown
source observations, and validates a Showcase or Markdown Editor `macos_skia`
first-frame source log through `--app-runtime-log` before delegating to the
generic platform manifest recorder. Collect the macOS window package transcript
with `WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=... scripts/run-window-package-smoke.sh macos --run`
so the AppKit smoke app writes the marker artifact itself; do not use outer
shell redirection as the source artifact for monitor/current-monitor evidence.
Do not use renderer-proof IME markers, provider preflights, or the window
package smoke alone as macOS platform-passed evidence.
For local macOS matching-host collection after Skia evidence is already passed,
prefer `scripts/record-macos-local-runtime-evidence.sh`; it runs the AppKit
window smoke, runs the Markdown Editor IME producer, folds native IME
observations, promotes the macOS platform entry with `matching-host-artifact`
provenance, and validates the macOS entry without changing Windows, Linux, or
global Skia claims.
A passed presentation manifest must include WebGPU startup, wasm startup,
canvas sizing, resize/input event-bridge delivery, Markdown Editor text input,
clean target close, clean console, nonblank screenshots, and Showcase
transform-scene pixel markers for the named browser session before the Web
platform entry can be marked passed.

Focused checks:

```sh
node scripts/validate-guidance-consistency.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-release-module-closures.mjs
node scripts/validate-core-theme-no-control-surface.mjs
node scripts/validate-host-import-baseline.mjs
node scripts/validate-backend-renderer-boundary.mjs
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-backend-common-boundary.mjs
node scripts/smoke-check.mjs --check
moon check
moon test moui/core --target native
moon test moui/views --target native
moon test moui_skia_renderer --target native
moon test moui/backend --target native
moon test moui/backend/android --target native
moon check examples/showcase/android_window_hosted --target native
moon test moui/backend/ios --target native
moon check examples/showcase/ios_window_hosted --target native
moon test moui/backend/harmonyos --target native
moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/web --target wasm-gc
moon test moui_tests/tester --target native
moon test moui_devtools --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Use focused tests during implementation, then run the full daily script when
possible.

## Maintenance Ratchets

Run:

```sh
node scripts/validate-maintenance-baseline.mjs
moon run tools/moui/validate_maintenance_baseline --target native -- --scope full
```

when changing file organization, public facade size, `pub(all)` exposure, test
file sizes, package boundaries, or MoonBit-backed JS validator wrappers. The
Node wrapper runs the daily scope; use `--scope full` for addon/tool workspace
hotspots tracked outside the daily gate. Keep those wrappers as thin
compatibility shims over
`scripts/lib/moonbit-tool-runner.mjs`; do not reintroduce local process
runners, direct filesystem parsing, or hard-coded native `_build` executable
paths there. If a refactor reduces a budget, ratchet the baseline down in the
same change. If a budget grows, explain why in review.

## Script Tooling Policy

Keep scripts simple, clear, and maintainable first. Prefer MoonBit `tools/...`
packages when repository rules, static validation, structure scans,
deterministic generators, or smoke catalog planning can stay clearer and gain
`moon check`/`moon test` coverage. Keep established `node scripts/*.mjs`
commands as stable compatibility wrappers over
`scripts/lib/moonbit-tool-runner.mjs`.

Keep Node for browser/CDP, Web smoke, HTTP/GitHub artifacts, npm ecosystem
tools, and runner logic that is clearer in JavaScript. Keep sh/PowerShell thin
for environment variables, platform setup, and OS command dispatch. Windows
MSVC, vcpkg, and zlib setup remains PowerShell-owned; MoonBit may validate
related manifests or docs but must not install machine tools.

Use `.mbtx` only for short standalone developer scripts; promote maintained CI
behavior to a `tools/...` package. Use `rule`/`dev_build` only for deterministic
package pre-build input/output generation. Do not use `rule`/`dev_build` to
install MSVC, vcpkg, zlib, Chrome, CI runners, or other machine dependencies,
and do not use it for smoke execution, networking, or global/user environment
mutation.

## Renderer And Backend Work

- Native Skia is the native mainline. Keep Skia provider wiring, renderer tests,
  `moui_skia` capability contracts, and docs in sync.
- Product `auto` prefers `SkiaGpuNative` when the host exposes a usable GPU
  surface; `SkiaRasterNative` remains the explicit mode and sticky recovery
  fallback. This policy belongs to `moui_skia_renderer`, never a platform backend.
- Web rendering goes through `moui/backend/web` and
  `moui_web_renderer` on `wasm-gc`.
- Native WGPU is diagnostic; keep it opt-in through `--wgpu-experimental`.
- Text changes often span `moui/core`, `moui_skia_renderer`,
  `moui_web_renderer`, optional native WGPU text providers, and
  `docs/text-system.md`.
- Platform behavior claims require matching-host tests or manual smoke.

## Manual Smoke

Manual smoke is required for real renderer/browser/platform claims:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

`smoke/gates.json` is the smoke gate catalog. Use:

```sh
node scripts/smoke-check.mjs --check
node scripts/smoke-gate.mjs --tier release --dry-run --json
```

before changing or running catalog-backed smoke. The CI owner for runtime smoke
is `.github/workflows/moui-runtime-gates.yml`.

## Docs And Skills

When workflow, package ownership, validation, examples, or smoke behavior
changes, update:

- `docs/`
- `AGENTS.md`
- `skills/moui-app-development/SKILL.md`
- `skills/moui-framework-development-skill/SKILL.md`
- `tools/moui/validate_guidance_consistency/*`

Then sync website docs:

```sh
node scripts/sync-website-docs.mjs
node scripts/check-website-docs.mjs
```

The sync command refreshes the ignored local preview copy. The check command
generates into an OS temporary directory and validates that isolated output, so
clean CI checkouts do not depend on ignored files.

Design Systems is addon diagnostic coverage. Run
`sh scripts/check.sh --profile theme` when changing `moui_theme` or
`examples/design_systems`.

Do not commit `artifacts/`. Cite CI run IDs, uploaded artifacts, or manual smoke
logs in release notes instead.

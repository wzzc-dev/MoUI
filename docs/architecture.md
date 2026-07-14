# Architecture

MoUI is a multi-platform MoonBit GUI framework. The repository is organized
around one rule: app logic stays platform-neutral, while host backends own
windows, lifecycle, platform services, and renderer selection.

The current mainline is native Skia raster plus the Web
`wasm-gc + backend/web + browser WebGPU host imports` path. Native WGPU remains
an experimental diagnostic route. Keep new work aligned with this shape unless
the change intentionally updates the architecture.

The runtime pipeline is explicit:

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## Code Map

| Path | Owner responsibility |
| --- | --- |
| `moui/` | Root public facade for app-loop types: `View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`, and `ViewEnvironment`. |
| `moui/{geometry,graphics,animation,text,state}/` | Domain facades over `moui/core` for app-facing geometry, paint/drawing, motion, text, and state/focus value types. They depend on `core`; `core` does not depend on them. |
| `moui/core/` | Platform-neutral foundation contracts: opaque `View`, typed events, `Program`, `Effect`, `Subscription`, geometry, draw commands, semantics, text editing, theme token surface, and custom view protocol. |
| `moui/views/` | Public view constructors, app-facing control APIs, default themes, form/navigation/data helpers, and concrete custom view behavior built with `@core.View::node`. |
| `moui/runtime/` | AppRuntime construction, runtime state, element/layout/render tree generation, event dispatch, program queue drain, effects, subscriptions, diagnostics, and inspector snapshots. |
| `moui/backend/host/` | Shared host contracts for windows, routes, timers, host services, WebView, async image loading, accessibility, input, redraw scheduling, and renderer handoff. |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos,web}/` | Concrete platform host implementations. Native platform packages normalize events into host contracts; Android, iOS, and HarmonyOS are currently embedded-session scaffolds driven by platform-owned callbacks; web is the canonical browser host. |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos}/skia/` | Native Skia renderer provider packages for the main native route. Android presents CPU pixel frames to an `ANativeWindow`; iOS presents CPU pixel frames to a UIKit `UIImageView` child; HarmonyOS presents CPU pixel frames to a supplied XComponent native-window handle. |
| `moui/backend/{macos,windows,linux}/wgpu/` | Native WGPU diagnostic provider packages. |
| `moui/render/` | Renderer facade, shared render capability models, fallback planning, shader/image helpers, and renderer-neutral command handling. |
| `moui/render/skia/` | Native Skia renderer facade over `moui_skia`. |
| `moui/render/webgpu_adapter/` | Browser WebGPU host-import adapter for `wasm-gc`. |
| `moui/render/wgpu/` | Experimental native WGPU renderer and native text providers. |
| `moui_richtext/` | Markdown/rich-text document, editor, command, input, paste, table, and source-mapping logic used by rich editing apps. |
| `moui_skia/` | Editable Skia binding and native/fallback capability contract workspace. |
| `moui_theme/` | Optional design-system addon workspace for Material, Carbon, Primer, Fluent, common source-mapped token diagnostics, and first-party visual theme addons such as Sickle. |
| `moui_tester/` | Harnesses, fixtures, and first-frame/native smoke helpers. |
| `moui_devtools/` | Devtools and overlay/debug helpers. |
| `moui_agent/`, `moui_agent_mcp/` | Agent protocol, schema, host runtime, and MCP router support packages. |
| `examples/*/app/` | Shared app logic packages. These should be platform-neutral unless an app-specific service package is intentionally separate. |
| `examples/*/{web_wasm,macos_skia,windows_skia,linux_skia,...}/` | Thin platform entrypoints that create runtime/backend/renderer wiring for an app package. |
| `tools/` | MoonBit-backed repository validators used by JS shell entrypoints under `scripts/`. |
| `scripts/` | Local/CI command entrypoints, smoke runners, package validators, and platform setup helpers. |

## App Boundary

Shared app packages should default to:

- `wzzc-dev/moui`
- domain facades such as `wzzc-dev/moui/geometry`,
  `wzzc-dev/moui/graphics`, `wzzc-dev/moui/animation`,
  `wzzc-dev/moui/text`, and `wzzc-dev/moui/state` as needed
- `wzzc-dev/moui/views`

Use `wzzc-dev/moui/core` only when the app needs advanced kernel/diagnostic
types that are not exposed by a domain facade or `moui/views`. Use
`wzzc-dev/moui/backend/host` only for host service protocols such as file
import, WebView commands, route events, or async image service integration.

Avoid direct dependencies from ordinary app packages to:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- concrete platform backend packages
- renderer provider packages
- `moui_theme/*`, unless the app is a design-system preview or addon diagnostic

`examples/showcase/app` is allowed to be broader because it demonstrates
diagnostics and renderer capabilities. Treat it as a framework showcase, not as
the default app dependency model. See `docs/moui-app-package-boundary.md` for
the detailed policy.

## Framework Boundary

Add new APIs to the narrowest owning package:

- Cross-runtime protocols and neutral value types belong in `moui/core`.
- App-facing domain facades over `core` belong in
  `moui/{geometry,graphics,animation,text,state}`. They can depend on `core`,
  but `core` must not depend on them.
- App-facing controls, control styles, form/navigation helpers, WebView facade,
  default themes, and concrete custom view implementations belong in
  `moui/views`.
- Runtime lifecycle, inspector snapshots, effect/subscription diagnostics, and
  runtime construction belong in `moui/runtime`.
- Host service and platform service protocols belong in `moui/backend/host`.
- Renderer implementation and capability reporting belong in `moui/render/*`.
- Native Skia binding ownership, fallback parity, FFI borrow rules, and native
  capability manifests belong in `moui_skia`.

Do not add a new top-level public package for every feature. Prefer the existing
owning package unless the capability is independently reusable and cannot be
owned cleanly by `views`, `runtime`, `backend/host`, `render`, or an addon
workspace.

## Target Routes

- Web app route: shared app package -> `examples/<app>/web_wasm` ->
  `moui/backend/web` -> `moui/render/webgpu_adapter`.
- Native Skia route: shared app package -> platform `*_skia` entrypoint ->
  platform backend -> platform Skia provider -> `moui/render/skia` ->
  `moui_skia`.
- Android Skia route (experimental scaffold): shared app package ->
  `examples/<app>/android_skia` plus app-owned Gradle metadata project such as
  `examples/counter/android_app`, using the package-published
  `moui/mobile/android` Gradle/Activity/JNI/CMake template ->
  `moui/backend/android` embedded session -> `moui/backend/android/skia` ->
  `moui/render/skia` -> `moui_skia`. The app or Android Activity layer owns
  lifecycle, `ANativeWindow` handle acquisition, `Choreographer` pacing,
  `InputConnection`, clipboard, virtual accessibility nodes, and input forwarding until a
  checked APK/device smoke promotes the route.
- iOS Skia route (experimental scaffold): shared app package ->
  `examples/<app>/ios_skia` plus app-owned Xcode metadata project such as
  `examples/counter/ios_app`, using the package-published
  `moui/mobile/ios` UIKit/Xcode/native build template ->
  `moui/backend/ios` embedded session -> `moui/backend/ios/skia` ->
  `moui/render/skia` -> `moui_skia`. The app or UIKit view controller owns
  lifecycle, `UIView` handle ownership, `CADisplayLink` pacing, the UIKit text
  proxy, pasteboard, accessibility container, and touch forwarding until a checked
  simulator/device smoke promotes the route.
- HarmonyOS Skia route (experimental scaffold): shared app package ->
  `examples/<app>/harmonyos_skia` plus app-owned Stage Ability/XComponent shell
  such as `examples/harmonyos_demo/harmonyos_app`, using the
  package-published `moui/mobile/harmonyos` Stage Ability/XComponent/NAPI/CMake
  template ->
  `moui/backend/harmonyos` embedded session ->
  `moui/backend/harmonyos/skia` -> `moui/render/skia` -> `moui_skia`.
  Native XComponent callbacks exclusively own surface/pointer lifecycle and
  touch-slop scroll arbitration. ArkTS owns `displaySync`, the transparent IME
  proxy, pasteboard, and accessibility overlays. A checked device/emulator smoke
  is still required before promotion.
- Native WGPU route: shared app package -> platform `*_wgpu` entrypoint ->
  platform WGPU provider -> `moui/render/wgpu`. This is diagnostic, not the
  default mainline.

Platform entrypoints should stay thin: create the program/runtime, select the
backend and renderer provider, and pass app-owned service adapters. Business
model/update/view logic should remain in the shared app package.

Mobile runtime sessions share `MobileHostChannel` for revisioned IME and
semantics updates plus asynchronous clipboard/accessibility responses. See
[Mobile Mainline And GPU Roadmap](mobile-mainline-roadmap.md), ADR 0005, and
ADR 0006. `SkiaRasterNative` remains the mobile default. `SkiaGpuNative` is a
formal `HostGpuSurface` descriptor with unpromoted window-surface source paths
implemented per Phase 1 (iOS Metal, macOS Metal, Android Vulkan/GLES,
HarmonyOS EGL/GLES, Windows D3D12, Linux Vulkan); the Phase 2 promotion gate
scaffolding (renderer mailbox control queue, context-loss recovery, manifest
schema) is in place, but `gpu_promoted` stays `false` on every platform until
matching-device evidence passes the seven ADR 0006 gates. Native
`SkPicture`/POD handoff now runs on an independent `std::thread` with a
latest-wins frame slot, ordered controls, detach acknowledgement, and polling
diagnostics. Platform branches now own Metal, D3D12, Vulkan WSI, or EGL
context/surface/swapchain/synchronization resources on that worker and emit
`Presented` only after the platform present call. Android dynamically loads
Vulkan so API 23 can remain loadable and fall back to EGL/GLES. Matching-host
builds are complete for macOS/iOS/Android/HarmonyOS. Native hosts poll worker
completions independently from frame submission, count only `Presented`, and
keep the current `AppRuntime` when terminal GPU recovery switches to raster.
Windows MSVC, Linux Wayland, and all matching-hardware promotion manifests
remain blockers.

## Extension Rules

- New controls: add app-facing constructors and concrete behavior in
  `moui/views`; use `@core.View::node` for custom layout/paint/event/focus/text
  behavior; do not add new core primitive enum variants for ordinary controls.
- New app examples: create `examples/<name>/app` first, then add one or more
  thin platform entrypoints.
- New renderer capability: update the implementation, tests, capability model,
  `docs/renderer-capability-report.md`, and text docs when text behavior
  changes.
- New public API: update or regenerate `pkg.generated.mbti`, run API surface
  checks, and explain the owning package in review.
- New docs affecting workflow: update root `docs/`, `AGENTS.md`, and relevant
  `skills/` guidance. Website docs are synced from root docs by
  `node scripts/sync-website-docs.mjs`.

## Validation Hooks

Architecture-sensitive changes should usually run:

```sh
sh scripts/check.sh --profile daily
moon info
node scripts/validate-api-surface.mjs
```

Use focused package tests while editing, then the daily validation script before
handoff when possible. Platform and real-renderer behavior needs the opt-in
manual smoke gates described in `docs/testing.md` and `docs/release-readiness.md`.

## Scope

- Platform-neutral `core` contracts, opaque views, environment/event/geometry,
  draw models, and the private custom view protocol wrapped by `View[Msg]`.
  `core` should grow only cross-runtime protocols and shared
  value types; concrete control behavior belongs in `moui/views`, alongside the
  public view facade. New controls must not add core enum variants, primitive
  constructors, or lowering arms. Persistent runtime state, element/render
  trees, layout, paint, event dispatch, and program execution are runtime-owned
  and are not exposed from `core`.
- `moui/runtime` is the app/host runtime entrypoint package. It exposes opaque
  `@runtime.AppRuntime` construction/query/dispatch methods and owns program
  message drain, effect task, subscription lifecycle, and runtime diagnostics.
- Public root package aliases only the curated app-loop types
  `View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`, and
  `ViewEnvironment` for `@wzzc-dev/moui` consumers. Geometry, graphics,
  animation, text, and state/focus aliases live in their domain facades.
  Neutral default/light/dark/custom theme builders live in `moui/views` and
  return plain `@moui.Theme` values.
- `moui_theme/common` is the app-facing construction surface of the optional
  design-system addon: `DesignPreset`, `DesignSystemTokens`, the per-system
  token structs with their `core_*` projection methods, and the
  construction-surface methods on `DesignPreset` (`theme`/`tokens`/`label`...).
  It exposes only what an app needs to build a `@core.Theme` from a branded
  system — no audit/diagnostics machinery.
- `moui_theme/audit` is the design-system diagnostics package: source-mapped
  manifests, golden mappings, official-token/source-lock coverage,
  source-package inventories, source-imported token records with pinned file
  shas, runtime token alignment, adaptation-difference, token taxonomy,
  semantic palette / typography role, token-group resolver, component-token
  matrix, density/variant resolver, and customization capability reports.
  Audit methods are top-level `pub fn` (MoonBit forbids defining methods on a
  type from another package), keyed by `@common.DesignPreset`. Apps reach it
  via `@audit.xxx(@material.preset())`; the variant packages no longer re-export
  audit entrypoints.
- `moui_theme` is a repo-local addon workspace member. It may import
  `wzzc-dev/moui/core`, but `moui/core`, `moui/views`, and the root
  `wzzc-dev/moui` package do not depend on `moui_theme`. Concrete Material,
  Carbon, Primer, Fluent, and first-party addon theme names stay in this addon through the
  `moui_theme/material`, `moui_theme/carbon`, `moui_theme/primer`, and
  `moui_theme/fluent` package entrypoints plus focused packages such as
  `moui_theme/sickle`; `core` remains a neutral token runtime.
- Spec-first views in `views`, including `text`, `button`, `text_field`, `container`, row/column layout, and spacer primitives.
- Unified host boundaries in `backend/host`, with shared window-event mapping and platform hosts normalizing events into `HostEvent`.
- Native mainline rendering through provider packages over `render/skia`, with experimental native WGPU diagnostics retained under `render/wgpu`.
- Web rendering through `render/webgpu_adapter` on `wasm-gc` only, with browser WebGPU host imports for visible drawing. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
moui/                         root public facade workspace member
moui/core/                    platform-neutral contracts, opaque View, and custom view callback contracts
moui/runtime/                 opaque app/host AppRuntime entrypoint, runtime state, tree/layout/paint, and program execution
moui/views/                   public view constructors and concrete custom view control behavior
moui_theme/common/            addon construction surface: DesignPreset, DesignSystemTokens, per-system token structs + core_* projections, and the construction-surface DesignPreset methods
moui_theme/audit/             addon diagnostics: manifests, golden mappings, official-token/source-lock coverage, source-import records, runtime alignment, taxonomy/role/resolver/matrix reports (top-level pub fn, not DesignPreset methods)
moui_theme/{material,carbon,primer,fluent}/ package-local official-system entrypoints: light/dark/high-contrast/system Theme helpers, tokens, and theme_for_variant over common
moui_theme/sickle/            first-party hybrid skeuomorphic/flat Theme addon with light/dark and style-mode helpers
moui/backend/host/            shared HostEvent, HostWindowEventSource, HostTimerSource, HostRouteSource, metrics, HostWindowRenderer, native async image completion source, input, redraw driver, window/core + dpi event conversion
moui/backend/windows/         Windows native host core
moui/backend/windows/skia/    Windows Skia renderer provider mainline
moui/backend/windows/wgpu/    Windows WGPU renderer provider diagnostic
moui/backend/macos/           macOS native host core
moui/backend/macos/skia/      macOS Skia renderer provider mainline
moui/backend/macos/wgpu/      macOS WGPU renderer provider diagnostic
moui/backend/linux/           Linux Wayland native host core
moui/backend/linux/skia/      Linux Skia renderer provider mainline
moui/backend/linux/wgpu/      Linux WGPU renderer provider diagnostic
moui/backend/android/         Android embedded native host scaffold over shared host/runtime contracts
moui/backend/android/skia/    Android Skia renderer provider over ANativeWindow pixel presentation
moui/backend/ios/             iOS embedded native host scaffold over shared host/runtime contracts
moui/backend/ios/skia/        iOS Skia renderer provider over UIKit UIImageView pixel presentation
moui/backend/harmonyos/       HarmonyOS embedded native host scaffold over shared host/runtime contracts
moui/backend/harmonyos/skia/  HarmonyOS Skia renderer provider over XComponent native-window pixel presentation
moui/mobile/harmonyos/        HarmonyOS reusable Stage Ability/XComponent/NAPI/CMake template and native glue
moui/backend/web/             canonical Web host on wasm-gc plus browser JS assets
moui/render/                  renderer facade and shared draw helpers
moui/render/skia/             native Skia raster renderer facade over moui_skia
moui/render/webgpu_adapter/   browser WebGPU host-import renderer for wasm-gc
moui/render/wgpu/             experimental native wgpu renderer
moui/render/wgpu/cosmic_text/ Moon Cosmic provider for native wgpu text
moui/render/wgpu/coretext/    macOS CoreText provider for native wgpu text
moui/render/wgpu/text_protocol/ shared native measure/run/raster/register bytes protocol
moui/render/wgpu/directwrite/ Windows DirectWrite provider scaffold
moui/render/wgpu/fontconfig/  Linux fontconfig/HarfBuzz/FreeType provider scaffold
moui/tests/tooling/           quickcheck and pixelmatch integration tests
moui/tests/text_conformance/  opt-in native/Web text diagnostic matrix
moui/tests/skia_renderer_smoke/native/ opt-in real Skia renderer pixel smoke
moui/tests/skia_cached_layer_benchmark/ opt-in real Skia cached-layer benchmark harness
moui/tests/skia_text_emoji_smoke/ opt-in real Skia text/emoji renderer smoke
moui/tests/wgpu_renderer_smoke/ opt-in native WGPU renderer smoke
examples/counter/app/         smallest shared app shape
examples/counter/{macos_skia,web_wasm,android_skia,ios_skia,macos_wgpu,windows_wgpu,linux_wgpu}/ platform counter entrypoints
examples/counter/android_app/ Counter Android Activity/JNI/CMake APK shell
examples/counter/ios_app/     Counter iOS UIKit simulator app shell
examples/counter/windows_wgpu_cosmic/ Windows counter selecting Moon Cosmic text
examples/harmonyos_demo/app/  standalone HarmonyOS demo app with viewport/tap feedback
examples/harmonyos_demo/harmonyos_skia/ HarmonyOS demo embedded-session Skia entrypoint
examples/harmonyos_demo/harmonyos_app/ HarmonyOS app-owned Stage Ability/XComponent shell over mobile/harmonyos
examples/component_gallery/harmonyos/ Component Gallery HarmonyOS embedded-session Skia entrypoint
examples/component_gallery/harmonyos_app/ Component Gallery HarmonyOS Stage Ability/XComponent shell
examples/agent_counter/       minimal agent-controllable runtime example (shared app at example root plus main/ and macos_skia/ entrypoints)
examples/button_freeze_probe/app/ minimal native Skia button-freeze repro app
examples/button_freeze_probe/{macos_skia,windows_skia,linux_skia}/ platform Button Freeze Probe entrypoints
examples/showcase/app/        shared MoUI framework showcase app with Counter/Todo patterns, no moui_theme dependency
examples/design_systems/app/  dedicated addon diagnostic source-mapped design-system preview/parity example using moui_theme
examples/design_systems/{web_wasm,macos_skia,windows_skia,linux_skia}/ Design Systems addon diagnostic host entrypoints
examples/showcase/macos_skia/ macOS showcase selecting native Skia raster
examples/showcase/macos_wgpu/      macOS native WGPU diagnostic showcase
examples/showcase/macos_wgpu_cosmic/ macOS showcase selecting Moon Cosmic text
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows_skia/ Windows showcase selecting native Skia raster
examples/showcase/windows_wgpu/    Windows native WGPU diagnostic showcase
examples/showcase/windows_wgpu_cosmic/ Windows showcase selecting Moon Cosmic text
examples/showcase/linux_skia/ Linux showcase selecting native Skia raster
examples/showcase/linux_wgpu/      Linux Wayland native WGPU diagnostic showcase
examples/showcase/linux_wgpu_cosmic/ Linux showcase selecting Moon Cosmic text
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos_skia/ macOS Markdown editor selecting native Skia raster
examples/markdown_editor/macos_wgpu/ macOS native WGPU diagnostic Markdown editor
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/markdown_editor/windows_skia/ Windows Markdown editor selecting native Skia raster
examples/markdown_editor/windows_wgpu/ Windows native WGPU diagnostic Markdown editor
examples/markdown_editor/windows_wgpu_cosmic/ Windows Markdown Editor selecting Moon Cosmic text
examples/markdown_editor/linux_skia/ Linux Markdown editor selecting native Skia raster
examples/code_editor/app/ shared native code editor and language-provider demo app
examples/code_editor/{macos_skia,windows_skia,linux_skia}/ platform Code Editor Skia entrypoints
examples/webview_demo/app/ shared native WebView demo app
examples/webview_demo/{macos_skia,windows_skia,linux_skia,web_wasm}/ platform WebView demo entrypoints
examples/pdf_workbench/app/  shared PDF reader/light editor app
examples/pdf_workbench/{macos_skia,windows_skia,linux_skia}/ platform PDF Workbench Skia entrypoints
examples/pdf_workbench/{pdflite_adapter,pdflite_service_protocol,pdflite_service_native_transport,pdflite_service_cli,pdfium_adapter}/ app-private PDF parse/writeback/raster adapter and service subpackages
examples/mo_workbench/app/   shared multi-backend agent desktop dogfood app
examples/mo_workbench/openseek_native_transport/ app-private OpenSeek in-process agent backend (native)
examples/mo_workbench/acp_native_transport/ app-private generic ACP stdio agent backend (native)
examples/mo_workbench/macos_skia/ macOS Mo Workbench native Skia entrypoint
examples/{settings,data_table,file_importer,command_palette}/app/ shared app-pattern packages without platform entrypoints
```

## Public View API

MoUI app code builds UI with opaque `@moui.View[Msg]` values using a typed TEA
loop: `view : Model -> View[Msg]`, typed messages, `update` handlers, and
explicit `Effect[Msg]` for follow-up work. `Subscription[Msg]` declares ongoing
event sources. Full details: [TEA Program Model](tea-program-model.md).

Key surface: `Program::simple` / `Program::new` / `*_with_environment`,
`Effect::send` / `Effect::run` / `Effect::task` / `Effect::service_task`,
`Subscription::timer` / `Subscription::host_event` / `Subscription::route_event`,
`View::map`, `Effect::map`, `Subscription::map`. Message drains are bounded
runtime turns; stale dispatchers after `AppRuntime::destroy()` are ignored.

## Runtime Mental Model

MoUI keeps the runtime pipeline explicit:

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

- `View[Msg]` is the immutable, opaque public description produced by app code;
  it wraps an internal view protocol with identity, children, layout, paint,
  event, semantics, text-control, and focus behavior.
- `ElementTree` is the mounted runtime tree. Its `ElementNode` entries own
  view identity, keys, child elements, dirty flags, control state, component state,
  layout cache, and render cache.
- `LayoutTree` is the latest placement result. Its `PlacedNode` entries carry
  the final frames produced by measurement and parent placement.
- `RenderTree` is the paint-stage tree. Its `RenderNode` entries attach hit
  testing and draw command payloads to frames that came from `LayoutTree`.
- App code should normally go through `AppRuntime`, `Component`, and
  `ComponentContext`; `RuntimeState`, `ElementTree`, `LayoutTree`, `RenderTree`,
  and their node types are engine implementation details even though some core
  tests still exercise them directly.
- `ViewEnvironment` is the read-only TEA-facing environment snapshot. It exposes
  the current viewport size and `Environment` without giving app-level views
  access to `ComponentContext` subscriptions, bindings, or component effects.
- `ScrollState`, `FocusState`, and `NavigationState` are the preferred state
  holders for reusable app structure instead of ad hoc view-local fields.
- `ComponentContext::run_effect` registers keyed component-scoped effects with
  cleanup callbacks. Effects with stable keys are reused across rebuilds, and
  cleanups run when keys disappear or the component leaves the tree.
  `ComponentContext` also exposes scoped save/restore helpers for small saveable
  string, bool, and int state.
- `AppRuntime` owns app-level `Program` diagnostics, including dispatch,
  update, message queue, effect plan, scheduled effect, effect-kind counters
  that distinguish send, anonymous dispatch, structured run, and cancellable
  task effects, active/completed/cancelled effect-task lifecycle counters,
  active subscription counts/kind summaries, subscription plan,
  start/reuse/cancel, duplicate effect descriptor-key counters/names, and
  duplicate subscription-key counters/names, plus ignored effect-task and
  subscription dispatch counters for stale callbacks from completed, canceled,
  or destroyed lifetimes, and ignored program-dispatch counters for anonymous or
  structured effect dispatchers that fire after runtime destruction. Program
  message drains are bounded runtime turns, so synchronous self-queued work can
  leave pending messages instead of monopolizing the current host callback.
  Program runtime and runtime
  inspector snapshots expose active effect-task descriptors, effect-task
  lifecycle entries, active subscription descriptors, active subscription
  kind-count summaries, and subscription lifecycle entries so tooling can
  identify which tasks and sources completed, were reused, or were canceled
  without inspecting app messages. Runtime inspector snapshots also expose a
  structured dirty-state summary for pending rebuild/layout/paint/redraw work,
  including dirty element ids, alongside legacy reason strings. Inspector
  snapshots read cached layout/render/semantics state without draining pending
  dirty work, so devtools can consume stable fields instead of parsing captions.
  Structured
  effect descriptors from `Effect::run`, `Effect::host_service`,
  `Effect::task`, and `Effect::service_task` travel through effect summaries so
  tooling can identify planned host-service or service/task runners without
  inspecting `Msg` values; duplicate descriptor-key counts/names make planned
  key conflicts visible before execution. Runtime
  inspector snapshots also expose platform-neutral pipeline pass counters for
  rebuild, layout, paint, and draw-command building. Dirty summaries also carry
  the latest damage kind, dirty-rect count, full-surface reason, cache epoch,
  and cached-layer count so tools can distinguish retained boundary updates
  from full redraws without parsing command streams. It keeps
  the latest effect summary, latest scheduled effect summary, and latest
  subscription plan summary, including planned subscription descriptors, for
  inspector tooling. This is separate from
  component-local `ComponentContext::watch` and
  `ComponentContext::run_effect`; program subscriptions model ongoing app event
  sources, while build-context subscriptions model component-local state
  invalidation and lifecycle effects.
- Layout uses constraints down, measured size up, then parent placement, and
  writes the result into `LayoutTree`.
- Paint consumes `LayoutTree` frames to build `RenderTree` and emits
  platform-neutral `DrawCommand` values. `RenderNode` entries retain paint
  bounds, content revisions, and repaint-boundary cache keys. The normal host
  path asks `AppRuntime::draw_frame()` for commands plus a `DamageRegion` and
  cache epoch. `DrawFrame.clear_color` owns frame initialization, while its
  command array contains view content without a leading `Clear`; legacy
  command-only renderer adapters materialize that clear when lowering the
  frame. Rect-damage renderers must constrain the complete command stream to
  the effective damage clip before skipping retained cached layers.
  `DrawFrame.platform_views` carries native platform-view
  placements such as `web_view` without adding them to `DrawCommand`. Legacy
  tests can still call `draw_commands()` for a full command stream. Renderers
  may degrade based on capability, but view constructors preserve brush, border,
  shadow, clip, image, and text intent.
- Backends normalize platform events into `HostEvent`; they do not own UI
  state or mutate element/render trees directly.
- `HostRuntimeDriver` owns redraw scheduling at the host boundary, dispatches
  normalized events into `AppRuntime`, and exposes platform-neutral draw frames
  for renderers. The redraw scheduler tracks `idle`, `scheduled`, `in-frame`,
  and `follow-up` states so repeated host callbacks coalesce and redraw
  requests made during presentation become the next frame.
  `HostWindowRenderer::render_frame()` forwards retained cached-layer commands
  to renderers that implement frame rendering, while its renderer-neutral
  command cache remains the fallback for simpler backends. Native Skia now owns
  a renderer-local offscreen surface/image cache for repaint boundaries and
  reports cache hit/miss/update/evict diagnostics. The real-app cached-layer
  benchmark uses Showcase hover/scroll and Markdown Editor text input, scroll,
  and caret-overlay interactions to verify sibling-boundary reuse, state-backed
  scroll redraw, rich-text block boundaries, editing overlays, command-count
  changes, and remaining rebuild, layout, and damage bottlenecks; OS-level
  partial present still remains a separate platform capability.
- `AppRuntime::focus_next` and `AppRuntime::focus_previous` expose explicit
  focus traversal entry points on top of the shared tab-order model.

## State And Binding

Inside component builds, display state should be read through `ComponentContext`:

```moonbit
@core.Component::new(ctx => {
  let count = ctx.watch(self.count)
  @views.text("Count: \{count}")
})
```

Use TEA-first controlled constructors for ordinary app state, for example
`@views.text_field(model.draft, on_input=DraftChanged)`. Component-local state
should still be projected into explicit values and typed messages before it
crosses the `views` public API boundary; event handlers and model methods can
use `state.get()`, `state.set()`, and `state.update()` inside the component.
The runtime cancels and replaces build subscriptions on rebuild, so repeated
builds do not accumulate listeners.

Component-scoped side effects should be registered with `ctx.run_effect`. The
returned cleanup callback is invoked when the effect key is no longer registered
for that component and when the component leaves the element tree:

```moonbit
@core.Component::new(ctx => {
  ctx.run_effect(key="subscription", () => {
    connect()
    Some(() => disconnect())
  })
  @views.text("Connected")
})
```

For simple lifecycle work, `ctx.on_mount(key=..., ...)` and
`ctx.on_dispose(key=..., ...)` are named wrappers around the same keyed effect
model.

State that needs to survive rebuilds, resize, and same-root remount can use the
scoped `save`, `restore`, or `saveable` helpers with a `SaveableCodec[T]`.
The string, bool, and int helpers remain as convenience wrappers over the same
codec path. `saveable_*` helpers return `State` values that write back to the
runtime store and request component rebuilds when changed. Their write-back
subscriptions are component-lifecycle-scoped like `ctx.watch`, so stale handles
from older builds stop invalidating the component or overwriting the saveable
store after rebuild or unmount. The store can be snapshotted/restored through
`SaveableStateSnapshot` for higher-level state restoration flows.

Environment values flow through `ComponentContext` so components can react to
platform and accessibility signals such as color scheme, locale, layout
direction, accessibility contrast, reduced motion, content size category, text
scale, and scale factor. TEA apps that only need to read those values should use
`ViewEnvironment`, keeping `ComponentContext` scoped to components and advanced
state holders.

## Layout

```text
Constraints down -> Size up -> parent places children
```

`Constraints::tight`, `Constraints::loose`, `Constraints::deflate`,
`Constraints::tighten`, and `Constraints::unbounded` are available in `core`.
`Padding` deflates child constraints and inflates its measured size. `Frame`
tightens child constraints. `Flex`, `Grid`, `List`, `Stack`, `Scroll`, and
ordered layout modifiers are implemented as concrete custom view behavior in
`moui/views`; runtime measures children, passes child sizes into the owning
virtual node, and stores returned child frames in `PlacedNode`. Paint reuses those
placed child frames rather than running layout a second time.

Advanced layout authors can use `@views.custom_children_layout` to define a
child layout delegate while still returning `View[Msg]`. The delegate receives
measured child sizes, returns its own
size, and places children with explicit frames. Its context also exposes child
baselines and layout priorities so custom layouts can align text and make
priority-aware placement decisions; paint and semantics metadata are kept on
the same `View::node` callback surface.

## Modifiers And Environment

Modifiers are represented as internal view wrappers instead of recursively
rewriting every child view. This keeps modifier order observable and makes
stateful wrappers like disabled, focusable, semantics, and shortcuts compose
predictably:

```moonbit
@views.text("A").padding(8.0).background(@core.Color::gray())
@views.text("A").background(@core.Color::gray()).padding(8.0)
```

The first paints the background outside the padding; the second paints it
inside. `font`, `foreground`, `corner_radius`, and the runtime text system
flow through the render environment, while layout and paint modifiers stay as
ordered wrappers.
MoUI currently supports background brushes, opacity, shadow, border, offset,
clip, scale, disabled, accessibility labels, semantics roles, focusability,
tap actions, keyboard shortcuts, and simple flexible/alignment wrappers in
addition to padding and frame.

## Visual

MoUI's visual system is a `ThemeSpec -> resolve_theme -> Theme` pipeline.
`core` owns the neutral schema and resolver; controls resolve styles ambient-ly
at paint time. Full details: [Visual Theme System](visual-theme-system.md).

Key points: `@views.light_theme()` / `@views.dark_theme()` resolve the Minimal
preset, `ButtonVariant::style(theme)` resolves from `theme.components.button`,
`ControlStateStyle` lives in `core` and is shared by the token resolver and
view-layer style structs, and `DesignSemanticPalette` carries the Fluent 2
neutral ramp. See also [Button Styling Guide](button-styling-guide.md) for
per-control style resolution.

## Built-In And Custom Views

The public `views` package includes text, button, text field, checkbox, image,
container, row/column, stack, scroll_view, grid, list, frame, padding, spacer,
navigation stack, tab view, dialog host, lazy list, toggle, radio, slider,
progress, menu button, tooltip, and layout helper functions.

See [View catalog](view-catalog.md) for the current public constructor matrix,
test coverage, and example coverage.
The larger WYSIWYG editing workflow is documented in
[Markdown Editor](markdown-editor.md).

Advanced users can use `@views.custom_layout` to provide measurement, paint, and
semantics callbacks without exposing the internal runtime tree. Internally this
is implemented with the same `View::node` callback surface as ordinary `moui/views`
raw constructors:

```moonbit
let swatch = @views.custom_layout(
  measure=constraints => constraints.constrain(@moui.Size::new(width=32.0, height=20.0)),
  paint=frame => [
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(rect=frame, radius=4.0),
      @core.Brush::solid(@core.Color::blue()),
    ),
  ],
  semantics_label="Color swatch",
)
```

For custom layouts with children, use the `@views.custom_children_layout` helper:

```moonbit
let pair = @views.custom_children_layout(
  children=[@views.text("A"), @views.text("B")],
  measure=ctx => ctx.constraints.constrain(@moui.Size::new(width=160.0, height=24.0)),
  place=ctx => [
    @core.Rect::new(x=ctx.frame.origin.x, y=ctx.frame.origin.y, width=80.0, height=24.0),
    @core.Rect::new(x=ctx.frame.origin.x + 80.0, y=ctx.frame.origin.y, width=80.0, height=24.0),
  ],
  semantics_label="Custom pair",
)
```

When adding a reusable control, put its concrete custom view behavior in
`moui/views`, expose the app-facing constructor from `moui/views`, and add tests
around custom view runtime behavior. Do not expose `ViewNode`, add a
`@core.View::primitive_*_view` constructor, `ViewLoweringSink`, or runtime
lowering arm for new controls.

## Platform Host Contract

`backend/host` defines the shared boundary between platform packages and the
platform-neutral runtime. It covers window lifecycle, multi-window bookkeeping,
host-event subscriptions, timer/route sources, WebView contracts, async image
loading, typed host services, keyboard shortcuts, menus, file drop, and
renderer handoff. Full details: [Platform Host Contract](platform-host-contract.md).

See [Platform notes](platform-notes.md) for setup, backend-specific constraints,
and validation commands.

## Accessibility

`core/semantics.mbt` produces a platform-neutral semantics tree with roles,
labels, hints, values, focus order, checked state, and live-region metadata.
`backend/web` includes a semantics-to-ARIA adapter for the wasm-gc Web path.
Native accessibility snapshots are exported from `backend/host` as
`Milky2018/moon_accesskit` tree updates. Platform bridges stay behind backend
boundaries and consume that AccessKit-shaped snapshot while `@core.SemanticsNode`
remains the source of truth.

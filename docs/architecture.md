# Architecture

One-page map (prefer for orientation): [`architecture-map.md`](architecture-map.md).
Doc catalog: [`INDEX.md`](INDEX.md). Constraints: [`invariants.md`](invariants.md).

MoUI is a multi-platform MoonBit GUI framework. The repository is organized
around one rule: app logic stays platform-neutral, while host backends own
windows, lifecycle, platform services, neutral surface capabilities, and host
I/O. Application entrypoints compose platform entries with renderer factories.

The current mainline is native Skia raster plus the Web
`wasm-gc + backend/web + browser WebGPU host imports` path. Native WGPU remains
an experimental diagnostic route. Keep new work aligned with this shape unless
the change intentionally updates the architecture.

The runtime pipeline is explicit:

```text
ViewDeclaration -> ElementTree
                       |-> LayoutTree -> RenderTree -> DrawCommand -> renderer
                       |-> SemanticsTree -> committed snapshot / Agent / accessibility
                       `-> PlatformTree -> platform-view host
```

## Code Map

| Path | Owner responsibility |
| --- | --- |
| `moui/` | Root public facade for app-loop types: `View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`, and `ViewEnvironment`. |
| `moui/{geometry,graphics,animation,text,state}/` | Domain facades over `moui/core` for app-facing geometry, paint/drawing, motion, text, and state/focus value types. They depend on `core`; `core` does not depend on them. |
| `moui/core/` | Platform-neutral foundation contracts: opaque `View`, typed events, `Program`, `Effect`, `Subscription`, geometry, draw commands, semantics, text editing, theme token surface, and the public message-independent `ViewNode` extension protocol. |
| `moui/views/` | Public view constructors, app-facing control APIs, default themes, form/navigation/data helpers, and concrete `ViewNode` behavior constructed with `@core.View::from_node`. |
| `moui/services/` | App-facing `AppServices`, typed `ServiceTask[T]`, `TimerSource`, `RouteSource`, and `AppEnvironment`; depends only on `moui/core`. |
| `moui/runtime/` | AppRuntime construction, runtime state, element/layout/render/semantics/platform tree generation, committed semantics generations and indices, event/action dispatch, program queue drain, effects, subscriptions, diagnostics, and inspector snapshots. |
| `moui/backend/host/` | Shared host wire contracts for windows and services, `HostServiceBridge`, completion queues, WebView, async image loading, accessibility, input, redraw scheduling, renderer handoff, and adapters to `moui/services`. |
| `moui/backend/platform_bridge/` | Neutral lifecycle and logical-coordinate bridge from platform facts to host contracts; it does not decode raw native input. |
| `moui/backend/internal/embedded_runtime_backend/` | Shared runtime/session assembly for Android, iOS, and HarmonyOS embedded runtime backends; it attaches a resolved neutral `HostWindowRenderer` after `ApplicationHandler` surface callbacks. |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos,web}/` | Concrete platform backend implementations. macOS, Windows, and Linux are native host backends; Android, iOS, and HarmonyOS are embedded runtime backends driven by `wzzc-dev/window`; web is the canonical browser host. They decode native input locally and route neutral lifecycle facts through `platform_bridge`. |
| `moui/backend/wechat/` | Direct Canvas2D callback host. It is in the bridge duplication inventory but intentionally does not fabricate a `WindowEvent` import. |
| `moui/render/` | Renderer facade, provider-ID capability reports, `RendererProviderBinding` composition contract, fallback planning, shader/image helpers, and renderer-neutral command handling. |
| `moui/render/skia/` | Native Skia renderer facade over `moui_skia`. |
| `moui/render/webgpu_adapter/` | Browser WebGPU host-import adapter for `wasm-gc`. |
| `moui/render/wgpu/` | Experimental native WGPU renderer and native text providers. |
| `moui/render/sun/` | Experimental Sun CPU raster renderer over the repo-local `moui_sun` workspace (ADR 0023: capability freeze by default, not on default composition roots). |
| `moui_sun/` | Experimental MoonBit-native CPU raster graphics/text/softbuffer workspace (ADR 0023). |
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

## Backend Hosting Models

The two native backend models are classified by host ownership, not by device
form factor. Android and HarmonyOS may run on desktop hardware; that does not
change which model their current MoUI integration uses.

| Model | Current platforms | Ownership boundary |
| --- | --- | --- |
| Native host backend | macOS, Windows, Linux | The MoUI backend owns the host runtime, native window lifecycle, event-loop integration, and window registry. |
| Embedded runtime backend | Android, iOS, HarmonyOS | The `wzzc-dev/window` embedder owns lifecycle, surfaces, input, and the event loop; the MoUI backend owns the attached runtime session and neutral surface binding. The application owns renderer composition. |

## App Boundary

Shared app packages should default to:

- `wzzc-dev/moui`
- domain facades such as `wzzc-dev/moui/geometry`,
  `wzzc-dev/moui/graphics`, `wzzc-dev/moui/animation`,
  `wzzc-dev/moui/text`, and `wzzc-dev/moui/state` as needed
- `wzzc-dev/moui/views`
- `wzzc-dev/moui/services` when the app needs platform capabilities

Use `wzzc-dev/moui/core` only when the app needs advanced kernel types that are
not exposed by a domain facade or `moui/views`. App-facing file, clipboard,
URL, settings, menu, timer, and route capabilities come from `moui/services`.

Avoid direct dependencies from ordinary app packages to:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/backend/*`
- `wzzc-dev/moui/render/*`
- concrete platform backend packages
- renderer provider packages
- `moui_theme/*`, unless the app is a design-system preview or addon diagnostic

Example runtime/renderer inspection and platform assembly live in module-root
integration packages and enter pure apps as neutral DTOs. Production
`examples/*/app` packages have no runtime/backend/render exception. See
`docs/moui-app-package-boundary.md`.

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
- App-facing service protocols belong in `moui/services`; host wire protocol,
  bridge, and completion queues belong in `moui/backend/host`.
- Platform windows, neutral presenters, native handles, and host I/O belong in
  `moui/backend/<platform>`; those packages must not import a concrete renderer.
- Renderer implementation and capability reporting belong in `moui/render/*`.
- Native Skia binding ownership, fallback parity, FFI borrow rules, and native
  capability manifests belong in `moui_skia`.

Do not add a new top-level public package for every feature. Prefer the existing
owning package unless the capability is independently reusable and cannot be
owned cleanly by `views`, `runtime`, `backend/host`, `render`, or an addon
workspace.

## Target Routes

- Web app route: shared app package -> `examples/<app>/web_wasm` composition ->
  `moui/backend/web` + `moui/render/webgpu_adapter`.
- Native Skia route: shared app package -> platform `*_skia` entrypoint ->
  `@runtime.run_app(...).render_all(@render_skia.from_env()).backend(@platform.entry())`
  -> neutral platform surface + `moui/render/skia` -> `moui_skia`.
- Android embedded-runtime route (`experimental`): shared app package ->
  `examples/<app>/android_window_hosted` composition via
  `@runtime.run_app(...).render_all(@render_skia.from_env()).backend(@android.entry())`
  -> `wzzc-dev/window/android` `HostCmd` / `EventLoop` -> neutral Android
  surface binding -> `moui/render/skia` -> `moui_skia`.
  The window template owns Android lifecycle, surface acquisition, and input;
  the embedded runtime backend owns runtime/session assembly and rendering.
- iOS embedded-runtime route (`experimental`): shared app package ->
  `examples/<app>/ios_window_hosted` composition via
  `@runtime.run_app(...).render_all(@render_skia.from_env()).backend(@ios.entry())`
  -> `wzzc-dev/window/ios` `HostCmd` / `EventLoop` -> neutral iOS surface
  binding -> `moui/render/skia` -> `moui_skia`.
  UIKit lifecycle, surface, and touch callbacks enter through the window event
  loop only.
- HarmonyOS embedded-runtime route (`experimental`): shared app package ->
  `examples/<app>/harmonyos_window_hosted` composition via
  `@runtime.run_app(...).render_all(@render_skia.from_env()).backend(@harmonyos.entry())`
  -> `wzzc-dev/window/harmonyos` `HostCmd` / `EventLoop` -> neutral HarmonyOS
  surface binding -> `moui/render/skia` -> `moui_skia`.
  Native XComponent callbacks are the sole source for surface, pointer, resize,
  and detach events.
- Native WGPU route: shared app package -> platform `*_wgpu` entrypoint ->
  `render/wgpu.native(...)` + platform `entry()` composition. This is experimental and
  diagnostic, not the default mainline.

Platform entrypoints should stay thin: create the program/runtime, add ordered
renderer factories, add one platform entry, and pass app-owned service
adapters. Binding selection uses `RendererProvider.id`; the optional
`RendererBackendKind` classification is diagnostic-only. Desktop product lists
prefer Skia GPU then raster according to the requested route; Web registers
WebGPU then Canvas2D fallback; native WGPU remains an explicit experimental
diagnostic
route. Business
model/update/view logic should remain in the shared app package.

Embedded runtime sessions share `EmbedderHostChannel` for sequenced IME
updates and generation-checked committed semantics plus asynchronous
clipboard/accessibility responses. See
[Window-hosted MoUI](window-hosted-moui.md), ADR 0005, and ADR 0006. Product
default is now `SkiaGpuNative` for every native Skia platform
when the host GPU surface is available (`NativeGpuPlatform::gpu_promoted` is
`true` for macOS, Windows, Linux, Android, iOS, and HarmonyOS). Window-surface
paths are Metal (macOS/iOS), Vulkan with EGL/GLES fallback (Android), EGL/GLES
(HarmonyOS), D3D12 (Windows), and Wayland Vulkan (Linux). `SkiaRasterNative`
remains the explicit `skia-raster` mode and the sticky recovery fallback after
terminal GPU failure. Matching-device seven-gate manifests remain useful
evidence and may still be incomplete for non-macOS hosts, but they no longer
gate the product `auto` default. Native `SkPicture`/POD handoff runs on an
independent `std::thread` with a latest-wins frame slot, ordered controls,
detach acknowledgement, and polling diagnostics. Platform branches own Metal,
D3D12, Vulkan WSI, or EGL context/surface/swapchain/synchronization resources
on that worker and emit `Presented` only after the platform present call.
Android dynamically loads Vulkan so API 23 can remain loadable and fall back to
EGL/GLES. Native hosts poll worker completions independently from frame
submission, count only `Presented`, and keep the current `AppRuntime` when
terminal GPU recovery switches to raster.

## Extension Rules

- New controls: add app-facing constructors and concrete behavior in
  `moui/views`; implement `@core.ViewNode` for message-independent
  layout/paint/focus/semantics behavior and use `@core.View::from_node` for typed
  children/events/text commands; do not add new core primitive enum variants.
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
  draw models, and the public message-independent `ViewNode` protocol wrapped
  by typed `View[Msg]` adapters.
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
- Native mainline rendering through factories in `render/skia`, with
  experimental native WGPU diagnostics retained under `render/wgpu`.
- Web rendering through `render/webgpu_adapter` on `wasm-gc` only, with browser WebGPU host imports for visible drawing. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
moui/                         root public facade workspace member
moui/core/                    platform-neutral contracts, opaque View, and custom view callback contracts
moui/runtime/                 opaque app/host AppRuntime entrypoint, runtime state, tree/layout/paint, and program execution
moui/views/                   public view constructors and concrete custom view control behavior
moui/services/                app-facing ServiceTask/AppServices/AppEnvironment and timer/route sources
moui_theme/common/            addon construction surface: DesignPreset, DesignSystemTokens, per-system token structs + core_* projections, and the construction-surface DesignPreset methods
moui_theme/audit/             addon diagnostics: manifests, golden mappings, official-token/source-lock coverage, source-import records, runtime alignment, taxonomy/role/resolver/matrix reports (top-level pub fn, not DesignPreset methods)
moui_theme/{material,carbon,primer,fluent}/ package-local official-system entrypoints: light/dark/high-contrast/system Theme helpers, tokens, and theme_for_variant over common
moui_theme/sickle/            first-party hybrid skeuomorphic/flat Theme addon with light/dark and style-mode helpers
moui/backend/host/            shared HostEvent, HostWindowEventSource, HostServiceBridge/queues, AppServices adapters, metrics, HostWindowRenderer, native async image completion source, input, redraw driver, window/core + dpi event conversion
moui/backend/windows/         Windows native host backend
moui/backend/macos/           macOS native host backend
moui/backend/linux/           Linux Wayland native host backend
moui/backend/android/         Android embedded runtime backend over shared host/runtime contracts
moui/backend/ios/             iOS embedded runtime backend over shared host/runtime contracts
moui/backend/harmonyos/       HarmonyOS embedded runtime backend over shared host/runtime contracts
moui/backend/web/             canonical browser lifecycle/canvas-surface host on wasm-gc
moui/backend/wechat/          WeChat lifecycle and neutral canvas-surface host
moui/render/                  host-surface kit, renderer factory/provider contracts, shared draw helpers
moui/render/skia/             native Skia CPU/GPU factories and implementation over moui_skia
moui/render/sun/              experimental native Sun CPU raster factory and implementation
moui/render/canvas2d/         WeChat Canvas2D factory and implementation
moui/render/webgpu_adapter/   browser WebGPU/Canvas2D factories, adapter, and JS renderer runtime
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
examples/counter/{macos_skia,web_wasm}/ retained Counter platform entrypoints
examples/harmonyos_demo/app/  standalone HarmonyOS demo app with viewport/tap feedback
examples/showcase/harmonyos_window_hosted/ Showcase HarmonyOS window-hosted entrypoint
examples/agent_counter/       minimal agent-controllable runtime example (shared app at example root plus main/ and macos_skia/ entrypoints)
examples/button_freeze_probe/app/ minimal native Skia button-freeze repro app
examples/button_freeze_probe/macos_skia/ retained Button Freeze Probe entrypoint
examples/showcase/            module-root Showcase integration facade
examples/showcase/app/components/ focused reusable component catalog with app-safe dependencies
examples/showcase/app/patterns/ Counter/Todo, forms, data, navigation, and workflow patterns
examples/showcase/app/platform/ host Effect/Subscription, canvas, routes, and mobile service probe
examples/showcase/app/diagnostics/ pure diagnostic DTO/view package
examples/showcase/diagnostics.mbt runtime/renderer DTO adapter
examples/design_systems/app/  dedicated addon diagnostic source-mapped design-system preview/parity example using moui_theme
examples/design_systems/{web_wasm,macos_skia}/ retained Design Systems addon diagnostic host entrypoints
examples/showcase/macos_skia/ macOS showcase selecting native Skia raster
examples/showcase/macos_wgpu/      macOS native WGPU diagnostic showcase
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows_skia/ Windows showcase selecting native Skia raster
examples/showcase/windows_wgpu/    Windows native WGPU diagnostic showcase
examples/showcase/linux_skia/ Linux showcase selecting native Skia raster
examples/showcase/linux_wgpu/      Linux Wayland native WGPU diagnostic showcase
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos_skia/ macOS Markdown editor selecting native Skia raster
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/code_editor/app/ shared native code editor and language-provider demo app
examples/code_editor/macos_skia/ retained Code Editor Skia entrypoint
examples/webview_demo/app/ shared native WebView demo app
examples/webview_demo/{macos_skia,web_wasm}/ retained WebView demo entrypoints
examples/pdf_workbench/app/  shared PDF reader/light editor app
examples/pdf_workbench/macos_skia/ retained PDF Workbench Skia entrypoint
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

Key surface: `Program::simple` / `Program::new` / `Program::with_commands` / `*_with_environment`,
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
  Structured effect descriptors from `Effect::run`, `Effect::task`, and
  `Effect::service_task` travel through effect summaries so tooling can identify
  planned structured or service/task runners without inspecting `Msg` values;
  duplicate descriptor-key counts/names make planned key conflicts visible
  before execution. Runtime
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
the same concrete `ViewNode` behavior surface.

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
preset, `ButtonVariant::style(control_set)` resolves from `control_set.button`
(the views-owned `ControlThemeSet`, ADR 0017),
`ControlStateStyle` lives in `views` and is shared by the token resolver and
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
semantics callbacks without exposing the internal runtime tree. Internally its
concrete node implements `ViewNode` and is constructed through
`View::from_node`, like ordinary `moui/views` controls:

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
around custom view runtime behavior. Do not re-export `ViewNode` from app-facing
facades, add a `@core.View::primitive_*_view` constructor, `ViewLoweringSink`,
or runtime lowering arm for new controls.

## Platform Host Contract

`backend/host` defines the shared boundary between platform packages and the
platform-neutral runtime. It covers window lifecycle, multi-window bookkeeping,
host-event subscriptions, timer/route sources, WebView contracts, async image
loading, typed host services, keyboard shortcuts, menus, file drop, and
renderer handoff. Full details: [Platform Host Contract](platform-host-contract.md).

See [Platform notes](platform-notes.md) for setup, backend-specific constraints,
and validation commands.

## Platform Bridge

`backend/platform_bridge` is the only shared platform-event conversion layer.
It owns Close, Focus, resize/scale, redraw, surface attach/detach, lifecycle
state, and logical-coordinate normalization. It depends only on `core`, host
contracts, and `window` value types. Platform packages keep raw pointer,
keyboard, IME, drag, and modifier decoding plus pacing and capability details.
WeChat is the `direct-canvas-callback` exception: it remains subject to the
duplication gate but imports no fictitious window-event API.

## Accessibility

`core/semantics.mbt` defines platform-neutral semantic identity, roles, state,
explicit composition, and typed actions. `moui/runtime` is the sole committed
semantics authority: it publishes immutable generation-tagged snapshots and
deltas, maintains stable-ID and node-route indices, and dispatches actions
directly into runtime state plus typed TEA messages. Semantics reads and
semantics-only updates do not require paint.

`backend/web` translates committed deltas to ARIA. `backend/host` translates
the same runtime reads to `Milky2018/moon_accesskit` updates, and mobile hosts
carry `SemanticsNodeId`, generation, and typed actions through the embedding
channel. Platform adapters do not maintain a second revision, repeat runtime
validation, or convert accessibility actions into coordinate input. Agent and
MCP ownership is documented in [Committed Semantics And Agent Actions](agent-semantics.md).

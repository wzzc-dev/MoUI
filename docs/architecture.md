# Architecture

MoUI is a multi-platform MoonBit GUI framework prototype. The current architecture keeps the app/runtime/view model platform-neutral. Native hosts own platform windows, events, services, and lifecycle, then receive concrete renderers through platform `RendererProvider` packages. The recommended mainline is native Skia raster plus the single Web `wasm-gc + window/web + browser WebGPU host imports` path; native WGPU remains an experimental diagnostic route while the MoonBit WGPU ecosystem matures. The project roadmap keeps this architecture focused on shared app logic, explicit backend contracts, transparent renderer capabilities, and bounded validation.

## Scope

- Platform-neutral `core` runtime, view specs, Taffy-backed layout placement,
  hit testing, and draw commands.
- Public root package aliases the most common core/style types for `@wzzc-dev/moui` consumers.
- `style` is the MoonBit package boundary for visual tokens and style type aliases during the gradual split from `core`.
- Spec-first views in `views`, including `text`, `button`, `text_field`, `surface`, row/column layout, and spacer primitives.
- Unified host boundaries in `backend/host`, with shared window-event mapping and platform hosts normalizing events into `HostEvent`.
- Native mainline rendering through provider packages over `render/skia`, with experimental native WGPU diagnostics retained under `render/wgpu`.
- Web rendering through `render/webgpu_adapter` on `wasm-gc` only, with browser WebGPU host imports for visible drawing. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
moui/                         root public facade workspace member
moui/core/                    one package for platform-neutral runtime, state, layout, input, editor, paint, and view model
moui/style/                   visual token and control style compatibility package
moui/views/                   public view constructors
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
moui/tests/skia_renderer_smoke/native/ opt-in real-Skia renderer pixel smoke
examples/counter/app/         smallest shared app shape
examples/counter/{web_wasm,macos_wgpu,windows_wgpu,linux_wgpu}/ platform counter entrypoints
examples/counter/windows_wgpu_cosmic/ Windows counter selecting Moon Cosmic text
examples/showcase/app/        shared visual showcase app with Counter/Todo patterns
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
examples/{settings,data_table,file_importer,command_palette}/app/ shared app-pattern packages without platform entrypoints
```

## Public View API

MoUI app code builds UI with opaque `@core.View[Msg]` values. The standard
shape is a typed TEA loop: `view : Model -> View[Msg]`, events carry typed
messages, `update` handles those messages, and explicit `Effect[Msg]` values
model follow-up work. App-level `Subscription[Msg]` values declare ongoing
event sources that should be started, reused by key, or canceled as the model
changes. Views that need viewport or platform inputs use
`view : (Model, ViewEnvironment) -> View[Msg]` through
`Program::simple_with_environment` or `Program::new_with_environment`. User code
does not call `lower`, `to_spec`, or `ViewSpec`; those names belong to the core
runtime implementation.

`views/` is a facade over core primitive builders:

```moonbit
enum CounterMsg { Inc; Dec }

fn view(count : Int) -> @core.View[CounterMsg] {
  @views.column([
    @views.text("Count: \{count}"),
    @views.row([
      @views.button("-", on_click=Dec),
      @views.button("+", on_click=Inc),
    ], spacing=8.0),
  ], spacing=12.0)
}
```

Function components are ordinary functions returning `View[Msg]`. Child
messages are lifted with `View::map`, for example
`todo_row(todo).map(TodoRowMsg)`. Child updates that return follow-up work lift
their effects with `Effect::map`, so a parent update can preserve typed child
message composition and structured effect descriptors without exposing runtime
dispatch. Ordinary controls are TEA-first controlled views: app code passes the
current value plus `on_input`,
`on_change`, or `on_select`, then updates the model from the emitted message.
Controls that require complex local state, such as rich text editing or
virtualized resources, keep that state explicit through bindings, cells, or
dedicated integration callbacks.

Stateful controls can use localized `View::component` adapters with
`BuildContext` when they must subscribe to framework cells or bridge complex
control state, but shared app runtimes should default to `Program::simple` and
`AppRuntime::new_program`. Effect-capable apps should use `Program::new` when
`update` returns follow-up work: `Effect::send` re-enters the typed message loop
directly, and `Effect::dispatch` gives an effect runner the typed message
dispatcher for app-owned host-service bridges or other callbacks without making
`core` platform-specific. `Effect::run` is the structured form for ordinary
one-shot runners that should appear in diagnostics; it adds a stable key, kind,
and label while leaving concrete async execution outside `core`.
`Effect::host_service` is the standard structured-run helper for host-service
bridges; it fixes the descriptor kind to `host-service` while the app/backend
still owns the actual service call. `Effect::task` starts a one-shot
cancellable task from an effect update, and `Effect::service_task` is the
standard helper for service-like one-shot tasks that need the same runtime-owned
cancellation lifecycle plus a stable `service` descriptor kind: the runtime
records an active task descriptor, completes it on the first typed dispatch,
cancels an older active task when a new task with the same key starts, cancels
active tasks when the runtime is destroyed, and ignores stale task dispatches
after completion or cancellation. Same-key task replacements that change the
descriptor kind are recorded with `EffectTaskKindChanged`, so tooling can
distinguish a service-like task being swapped for another task category from an
ordinary same-kind restart.
`Effect::plan_summary` exposes a platform-neutral diagnostic summary of the
effect tree, including batch, send, anonymous dispatch, structured run, task,
none, scheduled leaf count, max depth, structured effect descriptors, and
duplicate descriptor-key counts/names, without running effect callbacks.
Program runtime snapshots also report message queue enqueue, drain, pending,
max-pending, and ignored program-dispatch counters without requiring `Msg`
values to be serializable. Each program-message drain is bounded as a runtime
turn: messages synchronously queued by clicks, `Effect::send` /
`Effect::dispatch`, structured runners, effect tasks, or subscriptions keep
their FIFO order, but work beyond the per-turn bound remains pending for the
next host/runtime entry instead of keeping the current call stack alive
forever. Dispatch closures captured by anonymous
`Effect::dispatch` or structured `Effect::run` callbacks are ignored after
`AppRuntime::destroy()` so late app-owned callbacks cannot re-enter a destroyed
program runtime.
`Program` constructors also accept
`subscriptions=model => ...`; each `Subscription::listen` / `Subscription::run`
uses a stable key, receives the typed dispatcher, and may return a cleanup
callback. `Subscription::timer`, `Subscription::animation_tick`,
`Subscription::window_event`, `Subscription::host_event`,
`Subscription::route_event`, and
`Subscription::service_completion` standardize descriptor kinds for common
ongoing source categories without starting any concrete platform work in
`core`. `Subscription::plan_summary` exposes the declared none, batch, source,
duplicate-key counts/names, max-depth, and declared source descriptor structure
without starting sources. Existing keys are reused across model changes only
when their descriptor kind still matches, missing keys are canceled, and a
source that keeps the same key but changes kind is restarted with a
`SubscriptionKindChanged` lifecycle reason so an app cannot silently keep an old
timer, host-event, or service adapter running under a reused key. Duplicate keys
in one subscription batch are ignored after the first and reported in runtime
diagnostics, and `Subscription::map` preserves child feature message and
descriptor identity while lifting messages to a parent type. Dispatchers
captured by canceled or destroyed subscriptions are ignored, so stale callbacks
cannot re-enter the model loop after their subscription lifetime ends; program
runtime and inspector snapshots count those ignored subscription dispatches
separately from normal typed dispatch/update counters and expose planned
subscription descriptors, active subscription descriptors, active subscription
kind-count summaries, and lifecycle entries for tooling. Concrete timer,
window, host-event, route, or host-service adapters remain outside `core`; the
core subscription runtime only owns the platform-neutral lifecycle,
subscription plan diagnostics, and typed dispatch contract. `backend/host`
provides the concrete `HostEventSource` fanout adapter for
`Subscription::host_event`, `HostWindowEventSource` for
`Subscription::window_event`, `HostTimerSource` for `Subscription::timer`
ticks, and `HostRouteSource` for `Subscription::route_event` fanout. Browser
history, native URL bars, and OS deep-link dispatch remain platform/app-layer
follow-up work.
Environment-aware TEA apps should use
the `*_with_environment` constructors instead of taking `BuildContext` in their
view layer. In both cases event dispatch flows through typed messages instead of
exposing the internal view tree.

## Runtime Mental Model

MoUI keeps the runtime pipeline explicit:

```text
View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

- `View[Msg]` is the immutable, opaque public description produced by app code;
  the internal view tree is the private core tree realized by the runtime.
- `ElementTree` is the mounted runtime tree. Its `ElementNode` entries own
  identity, keys, child specs, dirty flags, control state, component state,
  layout cache, and render cache.
- `LayoutTree` is the latest placement result. Its `PlacedNode` entries carry
  the final frames produced by measurement and parent placement.
- `RenderTree` is the paint-stage tree. Its `RenderNode` entries attach hit
  testing and draw command payloads to frames that came from `LayoutTree`.
- App code should normally go through `AppRuntime`, `Component`, and
  `BuildContext`; `RuntimeState`, `ElementTree`, `LayoutTree`, `RenderTree`,
  and their node types are engine implementation details even though some core
  tests still exercise them directly.
- `ViewEnvironment` is the read-only TEA-facing environment snapshot. It exposes
  the current viewport size and `Environment` without giving app-level views
  access to `BuildContext` subscriptions, bindings, or component effects.
- `ScrollState`, `FocusState`, and `NavigationState` are the preferred state
  holders for reusable app structure instead of ad hoc view-local fields.
- `BuildContext::run_effect` registers keyed component-scoped effects with
  cleanup callbacks. Effects with stable keys are reused across rebuilds, and
  cleanups run when keys disappear or the component leaves the tree.
  `BuildContext` also exposes scoped save/restore helpers for small saveable
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
  component-local `BuildContext::watch` and
  `BuildContext::run_effect`; program subscriptions model ongoing app event
  sources, while build-context subscriptions model component-local state
  invalidation and lifecycle effects.
- Layout uses constraints down, measured size up, then parent placement, and
  writes the result into `LayoutTree`.
- Paint consumes `LayoutTree` frames to build `RenderTree` and emits
  platform-neutral `DrawCommand` values. `RenderNode` entries retain paint
  bounds, content revisions, and repaint-boundary cache keys. The normal host
  path asks `AppRuntime::draw_frame()` for commands plus a `DamageRegion` and
  cache epoch; legacy tests can still call `draw_commands()` for a full command
  stream. Renderers may degrade based on capability, but view constructors
  preserve brush, border, shadow, clip, image, and text intent.
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

Inside component builds, display state should be read through `BuildContext`:

```moonbit
@core.Component::new(ctx => {
  let count = ctx.watch(self.count)
  @views.text("Count: \{count}")
})
```

Use TEA-first controlled constructors for ordinary app state, for example
`@views.text_field(model.draft, on_input=DraftChanged)`. Use
`ctx.binding(state)` and the `*_binding` view variants when a component or
advanced control needs two-way access during the build, for example
`@views.text_field_binding(ctx.binding(self.draft))`. Event handlers and model
methods can still use `state.get()`, `state.set()`, and `state.update()`. The
runtime cancels and replaces build subscriptions on rebuild, so repeated builds
do not accumulate listeners.

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

Environment values flow through `BuildContext` so components can react to
platform and accessibility signals such as color scheme, locale, layout
direction, accessibility contrast, reduced motion, content size category, text
scale, and scale factor. TEA apps that only need to read those values should use
`ViewEnvironment`, keeping `BuildContext` scoped to components and advanced
state holders.

## Layout

Layout follows the Flutter-style protocol internally:

```text
Constraints down -> Size up -> parent places children
```

`Constraints::tight`, `Constraints::loose`, `Constraints::deflate`,
`Constraints::tighten`, and `Constraints::unbounded` are available in `core`.
`Padding` deflates child constraints and inflates its measured size. `Frame`
tightens child constraints. `Flex`, `Grid`, `List`, and `Stack` use
`Milky2018/moon_taffy` for their primary placement pass, with MoUI converting
internal view children into a short-lived Taffy tree and then writing the computed
frames back into `PlacedNode`. `Scroll` and ordered layout modifiers preserve
MoUI's existing placement semantics. Paint reuses those placed child frames
rather than running flex/grid/list/scroll/custom placement a second time.

Advanced layout authors can use `@views.custom_children_layout` to define a
child layout delegate while still returning `View[Msg]`. The delegate receives
measured child sizes, returns its own
size, and places children with explicit frames. Its context also exposes child
baselines and layout priorities so custom layouts can align text and make
priority-aware placement decisions; paint and semantics metadata are kept on
the same spec. Custom layout delegates remain MoUI-owned and do not go through
Taffy.

## Modifiers And Environment

Modifiers are represented as `ModifiedSpec` wrappers instead of recursively
rewriting every child spec. This keeps modifier order observable and makes
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

The visual system keeps platform-neutral tokens and styles:

- `Theme::light()` and `Theme::dark()` expose color palettes, spacing, radius,
  typography, shadow, motion, and surface scales.
- `ButtonStyle::filled/tonal/outline/ghost` and
  `TextFieldStyle::filled/outline` project state styles into core draw
  commands.
- `SurfaceStyle` supports surface brushes, radius, padding, border metadata,
  and shadow metadata.
- `ShadowStyle` and `BorderStyle` are view-level style inputs; paint converts
  them into concrete `DrawCommand` payloads once the final frame is known.
- `AnimatedDouble`, `AnimatedPoint`, `AnimatedColor`, `TransitionSpec`, and
  `TransitionStyle` provide small property-animation samplers for state-driven
  visuals. `View::transition` and `View::presence` apply those samples through
  existing opacity, offset, scale, and foreground modifiers, including a
  reduced-motion shortcut.
- `ImageFit::Contain/Cover/Stretch/ScaleDown/FitWidth/FitHeight` records image intent, with
  source, opacity, and rounded clipping preserved in the view spec.
- Native Skia and WebGPU renderers keep visible draw-command support on the
  mainline. Skia owns native raster pixels and text diagnostics, while WebGPU
  owns browser wasm-gc presentation. Experimental native WGPU still validates
  the GPU path when explicitly requested.

View constructors pass `Brush`, border, and shadow data into `DrawCommand`
without calling `Brush::fallback_color`; fallback is centralized in renderer
capability layers.

The native Skia renderer is the recommended native baseline for renderer proof
and platform entrypoint evidence. It presents CPU pixel frames through platform
Skia providers and uses the local `moui_skia` binding for raster, path, image,
and text diagnostics. The WebGPU host-import renderer forwards the full command
set to the browser runtime. Experimental native WGPU continues to exercise the
GPU surface path and provider text integrations when explicitly requested. See
[Renderer capability report](renderer-capability-report.md).

Text measurement flows through the runtime `TextSystem` contract. `core/` owns
the neutral contract and deterministic fallback; the native Skia mainline
exposes `skia_text_system()` for renderer/text diagnostics, WGPU diagnostic
providers live under `render/wgpu/*`, and Web installs a browser Canvas-backed
system that matches its WebGPU glyph path. See [Text system](text-system.md).

## Built-In And Custom Views

The public `views` package includes text, button, text field, checkbox, image,
surface/container, row/column, stack, scroll, grid, list, frame, padding,
spacer, navigation stack, tab view, dialog host, lazy list, toggle, radio,
slider, progress, menu button, tooltip, and layout helper functions.

See [View catalog](view-catalog.md) for the current public constructor matrix,
test coverage, and example coverage.
The larger WYSIWYG editing workflow is documented in
[Markdown Editor](markdown-editor.md).

Advanced users can use `@views.custom_layout` to provide measurement, paint, and
semantics callbacks without exposing the internal core tree:

```moonbit
let swatch = @views.custom_layout(
  measure=constraints => constraints.constrain(@core.Size::new(width=32.0, height=20.0)),
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
  measure=ctx => ctx.constraints.constrain(@core.Size::new(width=160.0, height=24.0)),
  place=ctx => [
    @core.Rect::new(x=ctx.frame.origin.x, y=ctx.frame.origin.y, width=80.0, height=24.0),
    @core.Rect::new(x=ctx.frame.origin.x + 80.0, y=ctx.frame.origin.y, width=80.0, height=24.0),
  ],
  semantics_label="Custom pair",
)
```

## Platform Host Contract

`backend/host` is the shared boundary between platform packages and the
platform-neutral runtime. It defines `HostSurfaceMetrics`, input capabilities,
coordinate policies, `HostEvent`, text input session synchronization,
`HostRuntimeDriver`, file drag/drop normalization, and `HostWindowRegistry` for
platform-neutral window lifecycle and multi-window bookkeeping. It also exposes
`HostWindowRequestQueue` so app/runtime or higher-level host code can enqueue
open, focus, close, resize, minimize, show, and primary-window requests without
embedding those requests in a platform backend. `OpenWindow` requests carry a
platform-neutral scene id and payload alongside title and metrics, so future
multi-window hosts have enough app-level identity to choose the runtime/content
for the new platform window. `HostWindowSceneResolver` is the matching shared
contract for resolving those scene requests into new `AppRuntime` instances or
explicit scene rejections before a platform backend allocates a native window.
`HostEventSource` is the host-layer subscription adapter for app-owned
host-event fanout: platform code can publish normalized `HostEvent` values,
while apps map selected events back into typed `Program` messages through
`Subscription::host_event`; cancellation removes the publisher handler so late
host events do not re-enter stale app state.
`HostWindowEventSource` is the matching host-layer subscription adapter for
window-scoped platform events: platform code can publish a `HostWindowId` plus
normalized `HostEvent`, while apps map those `HostWindowEvent` values through
`Subscription::window_event`; cancellation removes the publisher handler so late
window events do not re-enter stale app state.
`HostPlatformEventSources` bundles the host-event and window-event sources for
platform runtimes. Web, macOS, Windows, and Linux app options can carry that
bundle; after a raw platform event is normalized and dispatched through the
matching `HostRuntimeDriver`, the backend publishes the same `HostEvent` with
its `HostWindowId` so app-owned `Subscription::host_event` and
`Subscription::window_event` adapters can observe real runtime events without
moving platform event conversion into `core`.
`HostTimerSource` is the matching host-layer subscription adapter for app-owned
timer ticks: host/platform code provides the scheduler callback, while apps map
`@core.Frame` ticks back into typed `Program` messages through
`Subscription::timer`; cancellation runs the scheduler cleanup so late timer
callbacks are ignored by the stale-dispatch guard.
`HostRouteSource` is the matching host-layer subscription adapter for app-owned
route/deep-link streams: host/platform code can publish `HostRouteEvent` values
carrying `@core.RouteLocation` plus a source label, while apps map those events
through `Subscription::route_event`; cancellation removes the publisher handler
so late route events do not re-enter stale app state. The adapter does not
mutate `RouteHistoryState` or synchronize browser/native history by itself.
`HostWindowRegistry::resolve_open_request` pairs a successful scene resolution
with the created registry record so the host can keep window id, scene metadata,
and runtime together. `HostWindowRuntimeSlot` then wraps that record with a
`HostRuntimeDriver`, giving future multi-window hosts a shared per-window
runtime/driver shape before platform-specific window and renderer handles are
attached. `HostWindowRuntimeSlots` is the matching collection for lookup,
primary/focused slot selection, record synchronization, and closed-window
cleanup, including shared helpers for inserting and syncing slots from
`HostWindowRegistry`, applying platform-neutral window requests, and applying
host lifecycle events while keeping the slot record aligned.
`HostPlatformWindowMap` binds platform window ids from `wzzc-dev/window` to
MoUI `HostWindowId` values so event dispatch can route through the host registry
instead of assuming one global window.
Web, macOS, Windows, and Linux should convert their native window events into
`HostEvent` and then let `AppRuntime` update state, rebuild, and emit
`DrawCommand` values.
The active Web, macOS, Windows, and Linux hosts all open a primary
`HostWindowRecord`, register the existing runtime/driver as a primary
`HostWindowRuntimeSlot`, bind the platform window id to the host id, route
incoming platform window events through that mapping, apply resize/focus/close
`HostEvent` values through the registry, sync slot records after lifecycle
changes, and remove slot, platform binding, and record when a host window is
disposed. That makes multi-window lifecycle state a shared host concern instead
of a future platform-specific rewrite. Platform entrypoints also accept a
shared `HostWindowRequestQueue` through their options-bearing runner and drain
focus, close, resize, minimize, show, and set-primary requests at the platform
edge. The same queue records ordered request completions, making accepted
operations and explicit rejections observable. Active backends use the shared
queue drain helper so completion recording stays a host contract instead of a
platform-local loop.
`HostWindowCommands` is the higher-level command facade over the same queue for
app-facing open/focus/resize/minimize/show/close helpers and shared draining
into a registry or window runtime slots.
Web exposes `run_app_with_options` directly because the browser renderer is part
of that host. Native host cores instead expose
`run_app_with_renderer_provider`; public native entrypoints live in
`backend/<platform>/wgpu` and `backend/<platform>/skia`. Those provider packages
carry the user-facing `run_app`, `run_app_with_options`, renderer-specific
options, and `renderer_provider` constructor. With a resolver, `OpenWindow`
requests resolve a scene into a new `AppRuntime`, create another platform
window, ask the provider for a `HostWindowRenderer`, register a per-window
`HostRuntimeDriver`, bind the platform id, and then route redraw, events,
context menus, service completions, IME sync, and disposal through
window-indexed slots. Without a resolver, hosts reject `OpenWindow` with the
shared unavailable-resolver message.

`HostWindowRenderer` is the renderer-neutral runtime handle used by native host
cores. It is a record of closures for resize, render, text-system access,
image-resource diagnostics, present-count diagnostics, and disposal. The shared
image repaint tracker consumes renderer-neutral image snapshots to route
late-image redraws per open window and expose tracked-window revision plus
loading/ready/failed/disposed status-count diagnostics, including
previous/current counts on repaint results. Host cores depend only on
`core`/`backend/host` plus the platform `window` package; they do not import
`render/wgpu`, `render/skia`, `wgpu_mbt`, or `moui_skia`. Skia provider
packages own the native mainline renderer creation, pixel presenter bridges,
and Skia availability diagnostics. WGPU provider packages retain GPU surface
bridges, `wgpu-native`, and native WGPU text provider composition as
experimental diagnostics.

`HostImageResourceCompletionSource` is the host-layer boundary for native async
image loader completions. Native provider/platform loaders publish
`@render.ImageResourceLoadCompletion` ready/failed results through
`HostWindowRenderer::apply_image_resource_load_completion`, which returns a revisioned
`@render.ImageResourceSnapshot`; the host routes that snapshot through
`HostImageResourceRepaintTracker`, requests redraw only for matching open
windows, ignores stale lower revisions, and discards closed-window completions.
`HostAsyncImageLoader` is the host-side scheduler adapter for that boundary: it
scans renderer snapshots for loading records, starts a platform/provider loader,
deduplicates in-flight `(window, source)` work, and gates late or cancelled
completion callbacks before they can apply to a renderer. `HostNativeAsyncImageSource`
is the host-owned deferred request source for platform loaders that need to
record pending `(window, source)` work and deliver a completion later from an
independent native callback. It proves the host boundary can receive late
completion callbacks after scheduling returns, but matching-host off-main runtime
artifacts are still required before the feature is ready. The native macOS,
Windows, and Linux host cores call the optional provider-owned loader hook after
the presented image-resource revision has been baselined, then cancel in-flight
window loads during disposal. Native WGPU provider packages now supply a
provider-owned loader that turns renderer-owned PNG/JPEG/BMP source decode
results into `ImageResourceLoadCompletion` payloads; matching-host off-main
async runtime evidence is still required before treating the route as fully
ready. Native Skia provider packages now install the same provider-owned loader
boundary around `skia_image_load_completion`, and provider-created Skia
renderers opt into post-present async image loading so the first presented
snapshot can contain loading records before the host routes ready/failed
completions into a repaint. The helper converts Skia encoded-image decode
results into ready/failed completion payloads without pre-populating renderer
caches. This is provider completion and smoke evidence, not matching-host
off-main runtime proof. The host source and scheduler do not decode images,
mutate renderer caches, or live in `core`;
renderer/provider packages still own concrete loading and lifecycle records.

`RendererDescriptor` and `RendererSelection` remain renderer facade reporting tools:
they describe static capability identity and matching, not native host runtime
assembly. `View` and the internal view tree still describe UI declaration trees only, and
`Binding[T]` remains the TEA/control/state two-way binding term.

Typed host services live on the same boundary. `HostServiceBridge` exposes
capability-checked dispatch for clipboard, file dialogs, menus, open-URL, and
system-theme requests. Backends can report unavailable services without
pretending that app code can call platform APIs directly.
`HostCapabilitySummary` folds those service flags together with input,
window-lifecycle, text-input, IME, drag/drop, async-service, and native
accessibility readiness. It is a high-level reporting API for apps, diagnostics,
and Showcase. Its `preflight_fields()` helper emits a renderer-neutral ready/gap
field string for provider/package audits such as native Skia preflight logs;
`HostServiceBridge`, `HostInputContract`, and platform backend setup remain the
source of truth for actual behavior.
`HostAppServices` is the app-facing facade over that same bridge, with helper
methods for clipboard, file dialogs, URL opening, system theme, context menus,
optional async queue completion handling, and an app-level
`completion_subscription` adapter; the bridge remains the source of truth for
capability routing and platform dispatch.
Services that cannot finish synchronously, especially browser clipboard reads
and file dialogs that need a permission or picker callback, can return
`HostServiceResponse::Pending` through `HostServiceAsyncQueue`. The host drains
pending requests into an in-flight set at the platform edge, completes them with
the original request attached, and records the completion. Runtime-owned
effects such as async paste are handed to `HostRuntimeDriver`, while app-owned
service flows should store pending request ids in model state and declare
`HostAppServices::completion_subscription` from `Program` subscriptions so the
completion re-enters the typed message loop without exposing platform APIs to
`core`. When that subscription is canceled because the model leaves the pending
state or the runtime is destroyed, the host queue releases its completion
handler; a later platform response is retained as a normal completed record
instead of dispatching through a dead app callback. The lower-level
`HostAppServices::on_completed` callback remains available for custom adapters.
The Web backend wires that queue to browser host imports and exported wasm
completion callbacks for clipboard reads and file pickers.
Web, macOS, and Windows entrypoints query that bridge at startup and install
the reported light/dark scheme into `AppRuntime` before the first host driver
layout/redraw pass, so initial view builds see the platform color scheme through
`BuildContext` environment reads.
`ThemeChanged` window events are also normalized into `HostEvent::ThemeChanged`;
`HostRuntimeDriver` applies them to runtime environment instead of leaking a
platform-specific event into app code.

Keyboard shortcuts, menus, and host command responses share the
`ActionCommand`/`CommandIntent` model. `ActionCommandMap` is the platform-neutral
dispatcher for matching shortcuts and invoking enabled command handlers.
The `views` package also provides view-level menu helpers over the same
metadata: `menu_bar`, `command_menu`, and `context_menu_region` render buttons,
rows, surfaces, and overlays as ordinary `View[Msg]` values. They are fallback
or app-authored menu UI, not platform menu services.
Copy, cut, and paste shortcuts are routed through `HostRuntimeDriver` with the
active `HostServiceBridge` so focused text controls use the platform clipboard
when that service is available, while app-level command handlers still run when
no text command handles the intent.
Secondary-button context-menu requests are recognized by the host event layer:
platform backends skip ordinary pointer dispatch for those events, then native
menu-capable hosts ask `HostServiceBridge::ShowMenu` to present the current
runtime action commands and dispatch the selected intent back through
`HostRuntimeDriver`.
File drop targets use the `View::on_file_drop` modifier; hosts normalize native
file drag/drop positions and paths before the runtime dispatches typed messages
to the hit view. `views.drop_zone` and `views.file_import_panel` are view-level
workflow shells over that modifier; their browse action remains an app message,
so effect-capable app code can return an `Effect::host_service` runner that calls
`HostAppServices::open_file`, dispatch typed completion messages for
unavailable or synchronous file dialog responses, and declare
`HostAppServices::completion_subscription` for pending dialogs. Web file import may
expose browser-selected file names or handles rather than native filesystem
paths, while native hosts can return platform paths through the same selection
array.

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

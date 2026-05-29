# Architecture

MoUI is a multi-platform MoonBit GUI framework prototype. The current architecture keeps the app/runtime/view model platform-neutral, with native hosts using `window + wgpu-native` and the Web host using a single `wasm-gc + window/web + browser WebGPU host imports` path. The project roadmap keeps this architecture focused on shared app logic, explicit backend contracts, transparent renderer capabilities, and bounded validation.

## Scope

- Platform-neutral `core` runtime, view specs, Taffy-backed layout placement,
  hit testing, and draw commands.
- Public root package aliases the most common core/style types for `@wzzc-dev/moui` consumers.
- `style` is the MoonBit package boundary for visual tokens and style type aliases during the gradual split from `core`.
- Spec-first views in `views`, including `text`, `button`, `text_field`, `surface`, row/column layout, and spacer primitives.
- Unified host boundaries in `backend/host`, with shared window-event mapping and platform hosts normalizing events into `HostEvent`.
- Native rendering through `render/wgpu`, including GPU text, rounded geometry, gradients, and soft shadows.
- Web rendering through `render/webgpu_adapter` on `wasm-gc` only, with browser WebGPU host imports for visible drawing. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
./                            root public facade package
core/                         one package for platform-neutral runtime, state, layout, input, editor, paint, and view model
style/                        visual token and control style compatibility package
views/                        public view constructors
backend/host/                 shared HostEvent, metrics, input, redraw driver, window/core + dpi event conversion
backend/windows/              Windows native host
backend/macos/                macOS native host
backend/linux/                Linux Wayland native host
backend/web/                  canonical Web host on wasm-gc plus browser JS assets
render/                       renderer facade and shared draw helpers
render/wgpu/                  native wgpu renderer
render/wgpu/cosmic_text/      Moon Cosmic provider for native wgpu text
render/wgpu/coretext/         macOS CoreText provider for native wgpu text
render/wgpu/text_protocol/    shared native measure/run/raster/register bytes protocol
render/wgpu/directwrite/      Windows DirectWrite provider scaffold
render/wgpu/fontconfig/       Linux fontconfig/HarfBuzz/FreeType provider scaffold
render/webgpu_adapter/        browser WebGPU host-import renderer for wasm-gc
tests/tooling/                quickcheck and pixelmatch integration tests
examples/showcase/app/        shared visual showcase app with Counter/Todo patterns
examples/showcase/macos/      macOS native showcase
examples/showcase/macos_cosmic/ macOS showcase selecting Moon Cosmic text
examples/showcase/macos_skia/ macOS showcase selecting native Skia raster
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows/    Windows native showcase
examples/showcase/windows_cosmic/ Windows showcase selecting Moon Cosmic text
examples/showcase/linux/      Linux Wayland native showcase
examples/showcase/linux_cosmic/ Linux showcase selecting Moon Cosmic text
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos/ macOS native Markdown editor
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/markdown_editor/windows/ Windows native Markdown editor
```

## Public View API

MoUI app code builds UI with opaque `@core.View[Msg]` values. The standard
shape is a typed TEA loop: `view : Model -> View[Msg]`, events carry typed
messages, `update` handles those messages, and explicit `Effect[Msg]` values
model follow-up work. Views that need viewport or platform inputs use
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
`todo_row(todo).map(TodoRowMsg)`. Ordinary controls are TEA-first controlled
views: app code passes the current value plus `on_input`, `on_change`, or
`on_select`, then updates the model from the emitted message. Controls that
require complex local state, such as rich text editing or virtualized resources,
keep that state explicit through bindings, cells, or dedicated integration
callbacks.

Stateful examples can still use `AppRuntime::new_component_view` with
`BuildContext`, while pure model examples should default to `Program::simple`
and `AppRuntime::new_program`. Effect-capable apps can use `Program::new` when
they need explicit `Effect[Msg]` output. Environment-aware TEA apps should use
the `*_with_environment` constructors instead of taking `BuildContext` in their
view layer. In both cases event dispatch flows through typed messages instead
of exposing the internal view tree.

## Runtime Mental Model

MoUI keeps the runtime pipeline explicit:

```text
View[Msg] -> internal ViewSpec -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

- `View[Msg]` is the immutable, opaque public description produced by app code; `ViewSpec` is the private core tree realized by the runtime.
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
- Layout uses constraints down, measured size up, then parent placement, and
  writes the result into `LayoutTree`.
- Paint consumes `LayoutTree` frames to build `RenderTree` and emits
  platform-neutral `DrawCommand` values. Renderers may degrade
  based on capability, but view constructors preserve brush, border, shadow,
  clip, image, and text intent.
- Backends normalize platform events into `HostEvent`; they do not own UI
  state or mutate element/render trees directly.
- `HostRuntimeDriver` owns redraw scheduling at the host boundary, dispatches
  normalized events into `AppRuntime`, and exposes platform-neutral draw
  commands for renderers.
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
runtime store and request component rebuilds when changed, and the store can be
snapshotted/restored through `SaveableStateSnapshot` for higher-level state
restoration flows.

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
- `ImageFit::Contain/Cover` records image intent, with source, opacity, and
  rounded clipping preserved in the view spec.
- Native and WebGPU renderers draw text through glyph-atlas GPU pipelines,
  evaluate linear gradients in shader code, and render rounded soft shadows as
  renderer primitives rather than start-color or layered-rectangle fallbacks.

View constructors pass `Brush`, border, and shadow data into `DrawCommand`
without calling `Brush::fallback_color`; fallback is centralized in renderer
capability layers.

The native wgpu renderer currently renders rounded fills, gradients, shadows,
GPU text, opacity, paths tessellated through `Milky2018/moon_zeno`, and decoded
PNG/JPEG/BMP images directly. Clip and transform commands have visible native
support with remaining follow-up work tracked in the renderer capability
report. The WebGPU host-import renderer forwards the full command set to the
browser runtime. See
[Renderer capability report](renderer-capability-report.md).

Text measurement flows through the runtime `TextSystem` contract. `core/` owns
the neutral contract and deterministic fallback; native providers live under
`render/wgpu/*`, and Web installs a browser Canvas-backed system that matches
its WebGPU glyph path. See [Text system](text-system.md).

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
of a future platform-specific rewrite. They also accept a shared
`HostWindowRequestQueue` through `run_app_with_window_requests` and drain focus,
close, resize, minimize, show, and set-primary requests at the platform edge.
The same queue records ordered request completions, making accepted operations
and explicit rejections observable. Active backends use the shared queue drain
helper so completion recording stays a host contract instead of a platform-local
loop.
`HostWindowCommands` is the higher-level command facade over the same queue for
app-facing open/focus/resize/minimize/show/close helpers and shared draining
into a registry or window runtime slots.
The Web, macOS, and Windows hosts also expose `run_app_with_options` with app
options that accept a `HostWindowSceneResolver`. With a resolver, `OpenWindow`
requests resolve a scene into a new `AppRuntime`, create another platform
window (browser canvas on Web, AppKit window with CAMetalLayer on macOS, Win32
window with HWND surface on Windows), attach a dedicated renderer, register a
per-window `HostRuntimeDriver`, bind the platform id, and then route redraw,
events, context menus, service completions, IME sync, and disposal through
window-indexed slots. Without a resolver, those hosts reject `OpenWindow` with
the shared unavailable-resolver message.

Typed host services live on the same boundary. `HostServiceBridge` exposes
capability-checked dispatch for clipboard, file dialogs, menus, open-URL, and
system-theme requests. Backends can report unavailable services without
pretending that app code can call platform APIs directly.
`HostCapabilitySummary` folds those service flags together with input,
window-lifecycle, text-input, IME, drag/drop, async-service, and native
accessibility readiness. It is a high-level reporting API for apps, diagnostics,
and Showcase; `HostServiceBridge`, `HostInputContract`, and platform backend
setup remain the source of truth for actual behavior.
`HostAppServices` is the app-facing facade over that same bridge, with helper
methods for clipboard, file dialogs, URL opening, system theme, context menus,
and optional async queue completion handling; the bridge remains the source of
truth for capability routing and platform dispatch.
Services that cannot finish synchronously, especially browser clipboard reads
and file dialogs that need a permission or picker callback, can return
`HostServiceResponse::Pending` through `HostServiceAsyncQueue`. The host drains
pending requests into an in-flight set at the platform edge, completes them with
the original request attached, and hands the completion back to
`HostRuntimeDriver` so runtime-owned effects such as async paste stay on the
same command path as synchronous services.
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
so app code can call `HostAppServices::open_file` and handle unavailable or
pending file dialog responses. Web file import may expose browser-selected file
names or handles rather than native filesystem paths, while native hosts can
return platform paths through the same selection array.

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

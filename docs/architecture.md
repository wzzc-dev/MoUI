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
backend/linux/                Linux host scaffold
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
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows/    Windows native showcase
examples/showcase/windows_cosmic/ Windows showcase selecting Moon Cosmic text
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos/ macOS native Markdown editor
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/markdown_editor/windows/ Windows native Markdown editor
```

## Spec API

MoUI uses a breaking, spec-only runtime. Public view constructors return
`@core.ViewSpec` directly; the old `ViewNode` compatibility API has been
removed.

```moonbit
let theme = @core.Theme::light()
let app = @views.surface(
  @views.column([
    @views.text("MoUI Counter").font(theme.typography.title),
    @views.button(
      "Increment",
      on_click=() => println("clicked"),
      style=@core.ButtonStyle::filled(theme~),
    ),
  ], spacing=theme.spacing_scale.md),
  style=@core.SurfaceStyle::default(theme~),
)

let runtime = @core.AppRuntime::new_spec(
  root=app,
  size=@core.Size::new(width=320.0, height=240.0),
)
```

Stateful apps should use `AppRuntime::new_component` with a `Component` that
returns `ViewSpec`. The long-term direction is tracked in
[2026 roadmap](roadmap-2026.md), while renderer-specific gaps are tracked in
[Renderer capability report](renderer-capability-report.md).

## Runtime Mental Model

MoUI keeps the runtime pipeline explicit:

```text
ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
```

- `ViewSpec` is the immutable description produced by app code.
- `ElementNode` owns identity, keys, control state, focus, and text-editing
  runtime state.
- App code should normally go through `AppRuntime`, `Component`, and
  `BuildContext`; `RuntimeState`, `ElementNode`, and `RenderNode` are engine
  implementation details even though some core tests still exercise them
  directly.
- `ScrollState`, `FocusState`, and `NavigationState` are the preferred state
  holders for reusable app structure instead of ad hoc view-local fields.
- `BuildContext::run_effect` registers keyed component-scoped effects with
  cleanup callbacks. Effects with stable keys are reused across rebuilds, and
  cleanups run when keys disappear or the component leaves the tree.
  `BuildContext` also exposes scoped save/restore helpers for small saveable
  string, bool, and int state.
- Layout uses constraints down, measured size up, then parent placement.
- Paint emits platform-neutral `DrawCommand` values. Renderers may degrade
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

Use `ctx.binding(state)` when a control needs two-way access during the build,
for example `@views.text_field(ctx.binding(self.draft))`. Event handlers and
model methods can still use `state.get()`, `state.set()`, and `state.update()`.
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

Small string, bool, and int state that needs to survive rebuilds, resize, and
same-root remount can use the scoped `save_*`, `restore_*`, or `saveable_*`
helpers. `saveable_*` helpers return `State` values that write back to the
runtime store and request component rebuilds when changed. More general
saveable value support remains a follow-up.

Environment values flow through `BuildContext` so components can react to
platform and accessibility signals such as color scheme, locale, layout
direction, accessibility contrast, reduced motion, content size category, text
scale, and scale factor.

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
`ViewSpec` children into a short-lived Taffy tree and then writing the computed
frames back into `PlacedNode`. `Scroll` and ordered layout modifiers preserve
MoUI's existing placement semantics. All layout results still produce the same
`RenderNode` output expected by renderers and hosts.

Advanced layout authors can use `ViewSpec::custom_layout` to define a child
layout delegate. The delegate receives measured child sizes, returns its own
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
- `AnimatedDouble`, `AnimatedPoint`, and `AnimatedColor` provide small
  property-animation samplers for state-driven visuals.
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

Advanced users can use `ViewSpec::custom` to provide measurement, paint, and
semantics callbacks without adding a new core enum variant:

```moonbit
let swatch = @core.ViewSpec::custom(
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

For custom layouts with children, use `ViewSpec::custom_layout` or the
`@views.custom_children_layout` helper:

```moonbit
let pair = @core.ViewSpec::custom_layout(
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
coordinate policies, `HostEvent`, text input session synchronization, and
`HostRuntimeDriver`. Web, macOS, and Windows should convert their native window
events into `HostEvent` and then let `AppRuntime` update state, rebuild, and emit
`DrawCommand` values. Linux currently keeps the same contract shape as a
scaffold until a real window backend exists.

Typed host services live on the same boundary. `HostServiceBridge` exposes
capability-checked dispatch for clipboard, file dialogs, menus, open-URL, and
system-theme requests. Backends can report unavailable services without
pretending that app code can call platform APIs directly.

Keyboard shortcuts, menus, and host command responses share the
`ActionCommand`/`CommandIntent` model. `ActionCommandMap` is the platform-neutral
dispatcher for matching shortcuts and invoking enabled command handlers.

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

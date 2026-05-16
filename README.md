# MoUI

MoUI is a multi-platform MoonBit GUI framework prototype. The current architecture keeps the app/runtime/view model platform-neutral, with native hosts using `window + wgpu-native` and the Web host using a single `wasm-gc + window/web + browser WebGPU host imports` path.

## Scope

- Platform-neutral `core` runtime, view specs, layout, hit testing, and draw commands.
- Spec-first views in `views`, including `text`, `button`, `text_field`, `surface`, row/column layout, and spacer primitives.
- Unified host boundaries in `backend/host`, with shared `backend/common` window-event mapping and platform hosts normalizing events into `HostEvent`.
- Native rendering through `render/wgpu`, including GPU text, rounded geometry, gradients, and soft shadows.
- Web rendering through `render/webgpu` on `wasm-gc` only, with browser WebGPU host imports for visible drawing. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
core/                         platform-neutral runtime and view model
views/                        public view constructors
backend/host/                 shared HostEvent, metrics, input, redraw driver
backend/common/               shared window/core + dpi event conversion
backend/windows/              Windows native host
backend/macos/                macOS native host
backend/linux/                Linux host scaffold
backend/web/                  canonical Web host on wasm-gc plus browser JS assets
render/                       renderer facade and shared draw helpers
render/wgpu/                  native wgpu renderer
render/webgpu/                browser WebGPU host-import renderer for wasm-gc
examples/counter/app/         shared counter app
examples/counter/windows/     Windows native counter
examples/counter/macos/       macOS native counter
examples/counter/web_wasm/    Web counter on wasm-gc
examples/todo/app/            shared todo app
examples/todo/windows/        Windows native todo
```

## V2 Spec API

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
returns `ViewSpec`.

## Runtime Mental Model

MoUI keeps the runtime pipeline explicit:

```text
ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
```

- `ViewSpec` is the immutable description produced by app code.
- `ElementNode` owns identity, keys, control state, focus, and text-editing
  runtime state.
- Layout uses constraints down, measured size up, then parent placement.
- Paint emits platform-neutral `DrawCommand` values. Renderers may degrade
  based on capability, but view constructors preserve brush, border, shadow,
  clip, image, and text intent.
- Backends normalize platform events into `HostEvent`; they do not own UI
  state or mutate element/render trees directly.

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

## Layout

Layout follows the Flutter-style protocol internally:

```text
Constraints down -> Size up -> parent places children
```

`Constraints::tight`, `Constraints::loose`, `Constraints::deflate`,
`Constraints::tighten`, and `Constraints::unbounded` are available in `core`.
`Padding` deflates child constraints and inflates its measured size. `Frame`
tightens child constraints. `Flex`, `Grid`, `List`, `Stack`, and `Scroll` all
participate in the measured/placed layout pass while preserving the existing
`RenderNode` output expected by renderers and hosts.

## Modifiers And Environment

Modifiers are represented as `ModifiedSpec` wrappers instead of recursively
rewriting every child spec. This keeps modifier order observable:

```moonbit
@views.text("A").padding(8.0).background(@core.Color::gray())
@views.text("A").background(@core.Color::gray()).padding(8.0)
```

The first paints the background outside the padding; the second paints it
inside. `font`, `foreground`, and `corner_radius` flow through a render
environment, while `padding`, `frame`, and `background` are interpreted by
layout/paint.

## Visual V2

Visual V2 adds platform-neutral tokens and styles:

- `Theme::light()` and `Theme::dark()` expose color palettes, spacing, radius,
  and typography scales.
- `ButtonStyle::filled/tonal/outline/ghost` and
  `TextFieldStyle::filled/outline` project state styles into core draw
  commands.
- `SurfaceStyle` supports surface brushes, radius, padding, border metadata,
  and shadow metadata.
- Native and WebGPU renderers draw text through glyph-atlas GPU pipelines,
  evaluate linear gradients in shader code, and render rounded soft shadows as
  renderer primitives rather than start-color or layered-rectangle fallbacks.

View constructors pass `Brush`, border, and shadow data into `DrawCommand`
without calling `Brush::fallback_color`; fallback is centralized in renderer
capability layers.

## Built-In And Custom Views

The public `views` package includes text, button, text field, checkbox, image,
surface/container, row/column, stack, scroll, grid, list, frame, padding, and
spacer helpers.

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

## Accessibility

`core/semantics.mbt` produces a platform-neutral semantics tree with roles,
labels, values, focus order, and checked state. `backend/web` includes a
semantics-to-ARIA adapter for the wasm-gc Web path. Native platform bridges are
kept behind backend boundaries and should map from the same core tree.

## Web Wasm-GC

Build the Web example:

```powershell
moon build examples/counter/web_wasm --target wasm-gc
python -m http.server 8080 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:8080/examples/counter/web_wasm/index.html
```

The Web path requires browser WebGPU. Startup fails clearly if `navigator.gpu`, an adapter, or a device is unavailable. There is no JS-target fallback branch. Browser font APIs may be used to populate hidden glyph atlas bitmaps, but visible text composition is performed by WebGPU.

The reusable browser runtime assets live under `backend/web/*.js`; `examples/counter/web_wasm/` is only the counter app's Web entrypoint and supplies the example-specific wasm URL.

Note: The Milky2018/window package does not support Windows/Web targets. Instead, clone the wzzc-dev/window repository to `.local_repos/window` using: `git clone git@github.com:wzzc-dev/window.git .local_repos/window` and checkout the `web-support` branch with: git checkout web-support`. 

## macOS Native

Build the native counter:

```sh
moon build examples/counter/macos --target native
```

Run it:

```sh
moon run examples/counter/macos --target native
```

The macOS host uses `Milky2018/window/macos` for AppKit windows and installs a `CAMetalLayer` on the window `NSView` for the native `render/wgpu` renderer.

## Windows Native

Install the native build/runtime dependencies with MSYS2 UCRT64:

```powershell
C:\msys64\usr\bin\pacman.exe -S --needed --noconfirm `
  mingw-w64-ucrt-x86_64-gcc `
  mingw-w64-ucrt-x86_64-vulkan-loader `
  mingw-w64-ucrt-x86_64-vulkan-headers
```

Use the static Windows GNU `wgpu-native` release expected by the helper script:

```text
.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release
```
Download it manually from the GitHub release: https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0

Build only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
```

Build and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1
```

Build todo on Windows:

```powershell
moon build examples/todo/windows --target native
.\_build\native\debug\build\examples\todo\windows\windows.exe
```

## Validation

```powershell
moon test render/webgpu --target wasm-gc
moon test backend/web --target wasm-gc
moon build examples/counter/web_wasm --target wasm-gc
moon test --target native
moon build examples/counter/macos --target native
moon build examples/counter/windows --target native
moon build examples/todo/windows --target native
```

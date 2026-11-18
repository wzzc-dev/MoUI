# Canvas And Custom Paint

App-facing custom drawing in MoUI uses `@views.canvas`, `@views.custom_layout`,
and the `PaintContext` helpers (`fill_rounded_rect`, `push_clip`,
`push_opacity`, path/shader helpers, and so on). These APIs emit ordinary
`DrawCommand` streams; they do not depend on a concrete renderer package.

## When to use which

| API | Use when |
| --- | --- |
| `canvas(measure, draw)` | Pure paint, no children (Flutter `CustomPainter` / SwiftUI `Canvas`) |
| `custom_layout(measure, paint, …)` | Custom measure/paint with optional child placement |
| `custom_children_layout(...)` | Multi-child custom layout + paint |
| Ordinary controls + modifiers | Theme tokens, padding, opacity, transition samples |

Prefer ordinary controls and theme tokens first. Reach for canvas when you need
procedural shapes, charts, HUD overlays, or pointer-driven sketches.

## Minimal canvas

```moonbit nocheck
using @views {canvas, fill_rounded_rect}

fn swatch() -> @moui.View[Msg] {
  canvas(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=200.0, height=120.0))
    },
    draw=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=12.0),
        @graphics.Brush::solid(@graphics.Color::rgba(r=0.2, g=0.45, b=0.9)),
      )
    },
    semantics_label="Blue swatch",
  )
}
```

`PaintContext` is package-local to `views`; app code only sees it as the first
argument of the `draw` / `paint` callbacks. Build colors/brushes/paths with
`@moui/graphics` (or `@core` equivalents re-exported there).

## Pointer-driven paint

Compose canvas with gesture modifiers. `View::on_drag` is enough for simple
sketch pads; keep stroke points in the app model.

```moonbit nocheck
canvas(measure~, draw~)
  .on_drag(event => CanvasDrag(event.position))
```

See `examples/showcase/app/platform` for a runnable drag-to-draw card.

### Continuous pointer and keyboard streams

`on_drag` waits for drag slop and `on_tap_with_frame` only fires on a completed
tap. A canvas that tracks hover, wheel input, or a release outside its frame
should use the raw observer instead:

```moonbit nocheck
canvas(measure~, draw~)
  .on_pointer((event, frame) => CanvasPointer(event, frame))
  .on_keyboard_input(
    key_handler=event => CanvasKey(event),
    text_input_handler=event => CanvasTextInput(event),
  )
```

`on_pointer` forwards every `PointerEvent` (Move/Down/Up/Cancel/Exit and wheel
deltas) plus the child frame; `Down` captures the pointer, and the runtime's
geometry hit focuses the nearest focusable wrapper (pair with `on_key`).
`on_key` makes the element focusable and forwards `KeyboardEvent` only while it
is focused. When the canvas also accepts IME, use one combined
`on_keyboard_input(key_handler=…, text_input_handler=…)` wrapper instead of
stacking separate focusable observers, so keyboard and `TextInputEvent` streams
reach the same element. Neither modifier adds semantics or changes press state
— the app owns interpretation. The p5 example (`examples/p5_sketch`) uses this pair to
drive `mouseX`/`mouseMoved`/`mouseWheel` and p5 key callbacks.

## Offscreen RGBA buffers

`@graphics.RgbaBuffer` is a writable, renderer-neutral RGBA8 buffer for
procedural textures, thumbnails, and pixel editing:

```moonbit nocheck
let image = @graphics.RgbaBuffer::new(width=64, height=64)
image.set(0, 0, @graphics.Color::rgba(r=1.0, g=0.0, b=0.5))
let pixel = image.get(0, 0)
image.pixels[4] = (255 : Byte)
```

It is straight (non-premultiplied) row-major RGBA and has no renderer
dependency. `to_png_bytes()` is the framework's single public PNG encode entry:
an addon keeps its own naming on top (the p5 `Image::to_png_bytes` delegates to
it) and turns those bytes into a renderer-decodable source. To paint it, emit
`ImageRun`/`DrawImage`; Skia and Sun decode PNG data URIs, and the browser image
loader accepts the same source.

## Path stroke caps and joins

`PathSpec` carries optional stroke-cap/join hints; `None` keeps the renderer
default:

```moonbit nocheck
let spec = @graphics.PathSpec::new(
  verbs~,
  stroke=Some(@graphics.Brush::solid(@graphics.Color::black())),
  stroke_width=2.0,
  stroke_cap=Some(@graphics.StrokeCap::Round),
  stroke_join=Some(@graphics.StrokeJoin::Bevel),
)
```

Skia and Sun honor both fields. Other renderers may keep their backend default
until their path pipeline consumes the hints.

## Animation

MoUI animation for apps is mostly **app-sampled**:

- `View::transition` / `View::presence` sample a `TransitionSpec` into opacity /
  offset / scale / foreground modifiers.
- `TransitionSpec::with_spring` drives the transition with spring physics
  (`SpringSpec::gentle` / `snappy` / `bouncy` damping-ratio presets); springs
  settle deterministically and respect reduced motion.
- For app-driven values, `@core.SpringState::advance` integrates toward a
  moving target with velocity handoff — retargeting mid-flight keeps the
  current speed instead of restarting from rest.
- `@moui/animation` re-exports easing, transition, and spring types.
- `@views.animated_canvas` is for looping canvas motion: the draw callback
  receives `now_ms` from the runtime paint clock and the paint plan is marked
  animating so the host keeps requesting frames without a `TimerSource`.
- Drive model-level ticks with `@services.TimerSource`; keep paint-only looping
  motion on `animated_canvas` so it does not enter the business model.

Reduced-motion should be respected when sampling transitions (see core
transition helpers and Showcase motion cards).

## Deeper examples

| Example | What to look at |
| --- | --- |
| Showcase Platform workspace | Minimal canvas + timer-driven opacity |
| Tutorial `06-animation` | `animated_canvas` orb driven by `now_ms` |
| `examples/showcase` Advanced Rendering | Layers, blend, filter, shader, path, transform |
| `examples/pdf_workbench` | `custom_layout` page bitmaps |

## Multi-stop and conic brushes

`@core.Brush` carries two-color linear/radial gradients plus a richer
`StopsGradient` variant:

```moonbit
let stops = [
  @core.GradientStop::new(color=red, at=0.0),
  @core.GradientStop::new(color=green, at=0.5),
  @core.GradientStop::new(color=blue, at=1.0),
]
// Linear / radial axes use the same stop list.
let linear = @core.Brush::linear_stops(
  start=@core.Point::new(x=0.0, y=0.0),
  end=@core.Point::new(x=240.0, y=0.0),
  stops~,
  oklab=true,
)
// Conic angles are CSS-style: degrees clockwise from 12 o'clock.
let conic = @core.Brush::conic(
  center=@core.Point::new(x=120.0, y=120.0),
  stops~,
  angle_degrees=45.0,
)
```

`oklab=true` mixes adjacent stops in Oklab (keeping saturation through the
midpoint). Skia interpolates that natively; Sun expands the list to sRGB
samples. `StopsGradientSpec::color_at(t)` samples the gradient in app code, and
`srgb_stops()` returns a renderer-ready sRGB list.

## Materials and scroll edges

`@views.material(width, height, blur_radius=16, corner_radius=12, tint?)`
paints a frosted backdrop panel. It emits the `backdrop-blur` shader effect:
renderers that can read their own pixels (Skia raster, Sun CPU) blur what was
already painted and tone it; the others paint the tint alone as the documented
degradation. `tint` defaults to the theme surface at 65%.

```moonbit
// A floating glass toolbar over a scrolling list.
@views.material(width=320.0, height=44.0, blur_radius=20.0, corner_radius=22.0)
```

`@views.scroll_edge(child, width, height, fade_height=24, color?)` fades the
content under the top/bottom edge with linear gradients — the renderer-neutral
way to make a toolbar-over-content scroll affordance.

Native macOS `NSVisualEffectView` vibrancy is declared as a host capability but
not implemented yet; see
[platform-readiness-declaration.md](platform-readiness-declaration.md#visual-material--host-vibrancy).

Renderer capability status (gradients, filters, text shaping, …) lives in
`docs/renderer-capability-report.md`, not in the view catalog.

## Related docs

- [View catalog](view-catalog.md) — control matrix
- [Non-render cookbook](non-render-component-cookbook.md) — host recipes
- [TEA program model](tea-program-model.md) — effects and subscriptions

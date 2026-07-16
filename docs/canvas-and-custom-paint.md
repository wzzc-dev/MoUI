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

## Animation

MoUI animation for apps is mostly **app-sampled**:

- `View::transition` / `View::presence` sample a `TransitionSpec` into opacity /
  offset / scale / foreground modifiers.
- `@moui/animation` re-exports easing and transition types.
- `Subscription::animation_tick` is a descriptor kind only; there is no universal
  host adapter yet. Drive frames with `HostTimerSource` (as Showcase Platform does)
  or host animation callbacks when you own them.

Reduced-motion should be respected when sampling transitions (see core
transition helpers and Showcase motion cards).

## Deeper examples

| Example | What to look at |
| --- | --- |
| Showcase Platform workspace | Minimal canvas + timer-driven opacity |
| `examples/showcase` Advanced Rendering | Layers, blend, filter, shader, path, transform |
| `examples/pdf_workbench` | `custom_layout` page bitmaps |
| `examples/markdown_editor` | Editor surface paint |

Renderer capability status (gradients, filters, text shaping, …) lives in
`docs/renderer-capability-report.md`, not in the view catalog.

## Related docs

- [View catalog](view-catalog.md) — control matrix
- [Non-render cookbook](non-render-component-cookbook.md) — host recipes
- [TEA program model](tea-program-model.md) — effects and subscriptions

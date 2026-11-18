# Stroke text: outlined TextRun support

- **Status**: done (2026-11-17)
- **Goal**: Give `TextRun` an optional stroke so canvas-style outlined text
  (p5 `stroke()` + `text()`) renders for real on Skia; the remaining backends
  keep fill-only until each grows a text-stroke path.

## Current behavior

`TextRun` carries only `color`; every renderer fills glyph runs and nothing
else. The p5 adapter forwards only the fill color, so `stroke()` has no effect
on `text()` — p5 code that draws hollow/outlined labels silently renders solid
fill (or nothing when `no_fill()` is set, because p5 currently forwards the
fill color regardless).

## Design

1. `TextRun` gains `stroke_color : Color?` and `stroke_width : Double`;
   `TextRun::new` defaults them to `None` / `0.0` so no call site changes.
2. Skia `draw_text`: when `stroke_color` is set, draw the glyph segments twice
   inside the existing clip — first a stroke paint (Round cap/join, stroke
   width), then the fill paint on top. Fill-under-stroke ordering keeps the
   outline visible around the fill.
3. Sun / Web / WGPU / Metal / TUI: ignore the stroke fields (fill-only). This
   is a style degradation, not a missing command; documented in the p5 README
   like the path-clip matrix.
4. p5 `Surface::fill_text` gains stroke parameters; the adapter maps them into
   `TextRun`, the `Recorder` logs them, and `RecordingSurface` records them so
   `create_graphics` replay keeps the outline. p5 `Sketch::text` passes
   `style.stroke` + `style.stroke_weight`.

## Verification results

- `moon test moui_skia_renderer --target native`: 152 passed, including
  "skia renderer strokes text under the fill" (yellow 3px outline pixels under
  a black fill; a zero-width stroke records nothing unsupported).
- `moon test examples/p5_sketch/p5 --target native`: 38 passed — the Recorder
  logs `stroke=... w=...`, and `no_fill()` + `stroke()` no longer returns early.
- `moon test examples/p5_sketch/p5/moui --target native`: 14 passed — the
  adapter's `TextRun` carries the stroke fields.
- Sun 112 / TUI 43 / Web 33 / WGPU 61 / Metal 91 passed; static validators and
  regenerated budgets/report all green.
- Shapes demo screenshot shows a stroke-only "outlined" label on Skia.

## Follow-ups

- Sun software-glyph stroke, Canvas2D `strokeText`, Metal/WGPU text-stroke
  paths remain separate slices.

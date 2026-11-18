# Source blend: exact-replace compositing for pixel overlays

- **Status**: done (2026-11-17)
- **Goal**: Add `BlendMode::Source` so a compositing scope replaces the
  destination exactly (including alpha). The p5 pixel overlay uses it, which
  makes `update_pixels` exact on any backdrop and enables erasing to
  transparent.

## Current behavior

`PushLayer` composites with source-over (or one of 13 modes). A p5 pixel
overlay therefore double-blends on transparent backdrops and cannot erase
existing pixels — setting a pixel to transparent is a no-op.

## Design

1. Core: add `BlendMode::Source` (the 14th mode).
2. Skia: `Src`. Sun: the paint enum's existing `Source`. Canvas2D JS:
   host code 13 → `copy`. WebGPU/Metal: degrade like the other separable
   modes (source-over factors / `-1` sentinel).
3. p5 adapter: `append_canvas_overlay` wraps the overlay `DrawImage` in
   `PushLayer(blend_mode=Source, offscreen=true)` / `PopLayer`, so the buffer
   replaces the canvas exactly — erased pixels stay erased, and semi-transparent
   buffer pixels no longer double-blend with the history underneath.
4. Update the p5 README limitation notes.

## Verification results

- `moon test moui_skia_renderer`: 154 passed — a Source layer over opaque red
  yields exactly the half-transparent blue (premultiplied readback r=g=0,
  b~=a~=128); source-over would have left red in the pixel.
- `moon test moui_sun_renderer`: 113 passed — mapping covers `Source`.
- `moon test examples/p5_sketch/p5/moui`: 15 passed — the overlay commits as
  `PushLayer(Source) → DrawImage → PopLayer`.
- TUI 43 / Web 33 / WGPU 61 / Metal 91 passed; static validators and
  regenerated budgets/report green.

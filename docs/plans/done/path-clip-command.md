# Path clip: a real non-rectangular DrawCommand

- **Status**: done (2026-11-17)
- **Goal**: Replace the p5 adapter's bounding-box clip approximation with a
  renderer-neutral path clip command. Skia executes the true path; the remaining
  backends keep a documented bounding-box fallback until each grows path-clip
  support.

## Current behavior

`@p5.Sketch::clip_path_begin(path)` reaches `MoUISurface::clip_path`, which
currently does:

```moonbit
let (x, y, width, height) = path.bounds()
self.commands.push(@core.PushClip(@core.Rect::new(x~, y~, width~, height~)))
```

The clip is visible in screenshots only as a rectangle. `PushClip` carries a
`Rect`, so circles, polygons, and compound paths cannot clip at all. This is
the last p5 drawing primitive that silently changes geometry rather than
degrading a color/filter detail.

## Design

1. Add `PushPathClip(@core.PathSpec)` / `PopPathClip` to `DrawCommand`.
   Add `PathSpec::shape_bounds()` (geometry without stroke inflation) so every
   non-Skia renderer can degrade to the same bounding rectangle; `bounds()`
   keeps its drawing-damage inflation.
2. Treat the pair as one `Clip` scope in the shared fallback planner so
   unbalanced scopes are still reported.
3. Skia: `canvas.clip_path(skia_path(verbs), anti_alias=true)` inside the
   existing save/restore clip scope.
4. Sun, TUI, WGPU, Metal, Web: intersect the current clip with
   `PathSpec::shape_bounds()`. Web Canvas2D reuses `canvas2d_clip_rect`; WebGPU
   reuses `host_push_clip`; this is a geometry degradation only, not a missing
   command.
5. p5 adapter: `clip_path` emits `PushPathClip` and `clip_end` emits
   `PopPathClip`.
6. Geometry transforms: `runtime/render_tree` translates the path with the
   existing `translate_path` helper; devtools/damage inspect the bounds.

## Verification

- `moon test moui/core --target native`: command plan / damage / path bounds.
- `moon test moui_skia_renderer --target native`: a pixel test whose clip is a
  triangle or circle; a corner inside the bounds but outside the path must
  stay unclipped/unchanged.
- `moon test examples/p5_sketch/p5/moui --target native`: adapter emits
  `PushPathClip`/`PopPathClip`, not `PushClip`.
- `moon test moui_sun_renderer moui_tui_renderer moui_web_renderer` and the
  static validators.
- `moon build examples/p5_sketch/macos_skia --target native` + screenshot.

## Verification results

- `moon test moui/core --target native`: 205 passed, including the path-clip
  damage bounds test.
- `moon test moui_skia_renderer --target native`: 151 passed, including
  "skia renderer clips to a path, not its bounding box".
- `moon test examples/p5_sketch/p5/moui --target native`: 13 passed; the adapter
  emits `PushPathClip`/`PopPathClip` and no rect clip.
- Sun 112, TUI 43, Web 33, WGPU 61, Metal 91 passed.
- Seven static validators passed; API budgets/report regenerated.

## Follow-ups

- Web Canvas2D native path clip (the current DrawPath path is also a stub).
- A per-backend capability cell is not added: `Clip` already exists; the
  fallback record for non-Skia backends should name the bounding-box
  degradation once the capability report grows per-command detail.
- Stroke text and advanced blend remain separate slices.

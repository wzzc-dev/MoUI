# Plan: Sun CPU raster hot paths (macOS interactive latency)

- **Status**: active
- **Archive note**: work landed in the working tree; move the row to
  `done/INDEX.md` with the landing sha once the change is committed.
- **Goal**: Make the Sun CPU renderer usable interactively — `examples/showcase/macos_sun`
  opens promptly and click feedback lands within a frame budget instead of
  taking seconds — by removing the measured hot spots in text mask rasterisation,
  shape filling, and CPU presentation. Evidence: before/after `MOUI_SUN_PROFILE=1`
  frame reports on macOS.
- **Non-goals**:
  - Changing Sun's product positioning or making it the default renderer
    (ADR 0023; `sun-visual-parity.md` owns perceived output).
  - A general damage/dirty-rect present path for Sun. `RenderFrame`/`DirtyRegion`
    bookkeeping stays unused; this plan only stops per-pixel dirty calls from
    dominating a full-frame replay.
  - Optimising the Skia/WGPU/Metal routes; the one shared-package change here
    (`moui/backend/macos`) only replaces how the *CPU* presenter hands an
    already-rasterised frame to Core Animation.

## Initial baseline (macOS native, `--release`, Showcase 535 commands)

`MOUI_SUN_PROFILE=1`, after warmup:

| Frame | total | setup | replay | read | present |
|---|---|---|---|---|---|
| first | 4690.3 ms | 5.2 ms | 4667.0 ms | 16.5 ms | 1.6 ms |
| warm | 832.9 ms | — | 806.4 ms | — | — |

Dominant warm buckets: `DrawText` 221.8 ms / 113, `FillRoundedRectBrush`
507.1 ms / 90, `StrokeRoundedRectBrush` 77.4 ms / 8.

A later baseline taken right before the text rewrite (fills, pixmap and readback
already fixed) was cold 307.6 ms / warm 56.8 ms; the present phase measured
9.8–10.7 ms per frame once the window was on screen.

## Diagnosis

1. **Text masks are canvas-sized.** `render_text_mask_face` builds
   `Rasterizer::new(pixmap.width, pixmap.height)`, clears the full coverage
   buffer per glyph, and `to_mask` copies the whole canvas (~1M px). The cache
   stores that full-canvas mask, copies it again on insert and on every hit, and
   `draw_mask` then scans the whole canvas per line. Total work per frame:
   `113 × canvas area`. The mask also has the text origin baked in while the
   cache key omits position, so the cache can replay stale positions.
2. **Per-pixel gradient sampling.** `Canvas::sample_paint_color` calls
   `transform.inverse()` per pixel (an `Option` allocation plus six divisions)
   for every shader paint. `fill_span_shape` rows and `draw_mask` pixels both
   do this, and each pixel also pays a `mark_dirty_bounds` call whose only
   consumer is an unused damage path.
3. **Per-frame canvas allocation** (`new_canvas_for_metrics`), a redundant
   full-frame copy in `read_frame`, and retained-layer hits resampled with
   `Balanced` even at scale 1.
4. **Glyph rasterisation was O(pixels × 16 samples × every line segment)**:
   `scanline_fill_with_aa` re-tested every segment for every pixel **and** every
   sub-sample, so a cold first frame cost ~36 ms per text line.
5. **Per-frame warm text rebuilt everything**: face resolution, line planning,
   cache-key construction (font JSON + text), fallback planning and one
   `TextLayout::layout` per span ran again for every `DrawText`, even though the
   line mask was a cache hit.
6. **Present uploaded a fresh CGImage every frame.** 6.4 MB of pixels were
   copied into a new `NSMutableData`, wrapped in a new `CGImage`, and assigned to
   `layer.contents`; Core Animation then converted and uploaded that image on
   the AppKit thread (~10 ms per frame at 1600×1000@2x). The memcpy itself was
   never the cost — a ping-pong buffer only moved 9.9 → 10.2 ms.

## Final evidence (macOS native, Showcase 535 commands)

`--release`, three cold runs / three warm runs:

| Frame | total | setup | replay | read | present |
|---|---|---|---|---|---|
| first (cold) | 31.0–32.8 ms | 0.7–1.5 ms | 27.7–28.3 ms | 1.0–1.4 ms | 1.5–1.7 ms |
| warm | 11.4–11.8 ms | 0.9–1.3 ms | 6.7–7.3 ms | 1.7–2.1 ms | 1.6–2.1 ms |

Warm buckets: `FillRoundedRectBrush` 3.0–3.5 ms / 90, `DrawText` 2.5–2.9 ms /
113, `StrokeRoundedRectBrush` 0.9 ms / 8. Debug (`moon run`): cold 97 ms
(`DrawText` 74 ms), warm 30 ms (fills ~11 ms, strokes 7.5 ms, text 6.4 ms,
present 2.8 ms) — the debug build is dominated by unoptimised MoonBit code
generation, not by any single algorithm.

Stage over stage:

| Phase | Initial | Pre-text baseline | Final |
|---|---|---|---|
| cold total (release) | 4690.3 ms | 307.6 ms | ~31 ms |
| warm total (release) | 832.9 ms | 56.8 ms | ~11.5 ms |
| `DrawText` warm | 221.8 ms | 19.1 ms (debug) | 2.5–2.9 ms |
| `FillRoundedRectBrush` warm | 507.1 ms | 10.3–11.1 ms (debug) | 3.0–3.5 ms |
| `StrokeRoundedRectBrush` warm | 77.4 ms | 7.7 ms (debug) | 0.9 ms |
| present (release) | — | 9.8–10.7 ms | 1.6–2.1 ms |

Presentation stayed correct: the frame is RGBA in memory, the presenter swizzles
to the IOSurface's BGRA order, and a `screencapture` of the running app shows
correct colours (blue accent pill, warm sidebar, no red/blue swap) with the
retina scale preserved.

## What changed

- `moui_sun/text/rasterizer.mbt`: `scanline_fill_with_aa` re-derived per
  sub-scanline crossings with a winding span fill instead of testing every
  segment at every pixel sample; bit-identical coverage (`covered * 255 / 16`,
  same sample centres). Added `TextMaskCache::get_advance` / `insert_advance`
  (a phase-free memo of per-span layout widths).
- `moui_sun/renderer/renderer_text.mbt`: span widths come from the advance memo
  before any `TextLayout::layout` call.
- `moui_sun_renderer/renderer_text_layout.mbt` + `renderer.mbt` +
  `renderer_text_draw.mbt` + `renderer_font_faces.mbt`: a per-run cache of
  `faces` + line plan + metric span (key `font JSON | max width | text`, FIFO
  512, cleared on font registration); `draw_text` guards on
  `text_system.font_count()` instead of resolving faces every frame.
- `moui_sun/graphics/canvas_shape_coverage.mbt` + `canvas.mbt`: fill scratch
  (coverage row, opaque-colour pattern row, four sub-scanline span arrays)
  moves onto the `Canvas` and is reused; straight rows bulk-blit an opaque
  pattern, sampled corner rows blend only their fringe windows.
- `moui/backend/macos/macos_present.mm` + `moui/build.mbtx`: the CPU presenter
  keeps two per-view `IOSurface`s, memcpy+swizzles a frame into the idle one and
  assigns it to `layer.contents`; Core Animation samples shared memory instead
  of converting a new CGImage per commit. The CGImage path stays as the
  allocation-failure fallback. `-framework IOSurface` joins the shared macOS
  backend link flags.
- `moui_sun_renderer/renderer_profile.mbt`: the env-gated profiler is kept
  (`MOUI_SUN_PROFILE=1`) as a standing diagnostic; disabled it costs one cached
  boolean check per call site.

## Acceptance

- [x] Text masks rasterise into a tight line box (glyph bounds + padding), the
      cache key includes family/weight/position-independent geometry, and
      compositing touches only the line rect.
- [x] Shader sampling hoists `transform.inverse()` to once per shape/row and
      skips it entirely for identity transforms; solid paints skip sampling.
- [x] Dirty bookkeeping in coverage rows and masks is per-row, not per-pixel.
- [x] Canvas buffers are reused across frames; `read_frame` drops the redundant
      full-frame copy; retained-layer hits at scale 1 blit instead of resample.
- [x] Glyph rasterisation is per-scanline, not per-pixel sample.
- [x] Warm text reuses the run-level face/plan/metric span cache.
- [x] CPU present hands Core Animation an IOSurface instead of a new CGImage
      per frame.
- [x] Before/after profile on macOS release build recorded above; warm replay
      is under the 60 Hz budget (~16 ms) for the Showcase first screen.
- [x] `moon test moui_sun/text` 149/149, `moon test moui_sun/graphics` 615/615,
      `moon test moui_sun_renderer` 126/126, `moon test moui/backend/macos`
      55/55 (the presenter test now asserts the retained IOSurface contents).

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-20 | Profile first with an env-gated profiler in `moui_sun_renderer` instead of guessing; keep it as a standing diagnostic rather than deleting it after the fix. |
| 2026-11-20 | Fix text by shrinking the mask allocation (tight box + cache offsets), not by adding a glyph atlas: the existing line cache already keys whole lines and the atlas path changes visible AA behaviour. |
| 2026-11-20 | Do not wire real damage rectangles yet; make dirty marking O(rows) so the unused bookkeeping stops costing per-pixel time. |
| 2026-11-20 | Rewrite the AA scanline filler (winding spans per sub-scanline) rather than lowering the sample count: cold text was 36 ms/line, and fewer samples would change visible AA. |
| 2026-11-20 | Present via per-view double-buffered `IOSurface` contents instead of dirty rects: the measured 10 ms was Core Animation's CGImage conversion/upload, not the pixel copy, so dirty rects would not remove it. Per-view ownership (not a static) keeps two windows from sharing a surface. |
| 2026-11-20 | The presenter keeps the CGImage path as a fallback when IOSurface allocation fails, and the retained-contents ivar is now an `id` so both paths share one `updateLayer` re-assert. |

## Progress

| Date | Note |
|------|------|
| 2026-11-20 | Baseline profiled on macOS release; root causes confirmed by reading `moui_sun/text/rasterizer.mbt`, `moui_sun/renderer/renderer_text.mbt`, `moui_sun/graphics/canvas_shape_coverage.mbt`, `canvas_image.mbt`. |
| 2026-11-20 | Text mask + rasterizer + run cache landed: release cold 307.6 → 28.9 ms, warm `DrawText` 19.1 → 2.5 ms. |
| 2026-11-20 | Fill/stroke scratch pooling landed; correctness held (615 graphics tests) but debug fills stayed ~11 ms, so the remaining fill cost is per-pixel blending, not allocation. |
| 2026-11-20 | Present profiled at 9.8–10.7 ms/frame and traced to CGImage texture conversion; ping-pong NSMutableData did not help, which confirmed the diagnosis. |
| 2026-11-20 | IOSurface presenter landed: present 9.8–10.7 → 1.6–2.1 ms, warm frame 56.8 → ~11.5 ms, cold ~31 ms; screenshot verified colour order and retina scale. |

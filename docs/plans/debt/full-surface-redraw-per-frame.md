# Plan: Full-surface redraw per frame (no damage rectangles)

- **Status**: debt
- **Goal**: Let a renderer present only the region a frame actually changed, so a
  scroll step or a caret blink stops re-rasterising the whole surface.
- **Non-goals**: changing the frame contract for platforms that already rely on
  full-surface overwrite (macOS Metal, Web, Windows D3D, Linux Vulkan); adding a
  second presentation path; optimising the Skia raster backend itself.

## Context

`SkiaRasterRenderer::resolve_effective_damage` always returns `FullSurface`, with
the comment "frame contract: full surface overwrite". Every presented frame
therefore clears and repaints the entire surface — on the HarmonyOS target that
is 2090x1324 physical pixels (about 2.8 Mpx) per frame.

During scroll work on HarmonyOS (see
`memories/repo/harmonyos-window-hosted.md`) three separate causes of "scroll feels
laggy" were found and fixed: a missing `pump_redraw_requested` on the wheel path,
physical-vs-logical pointer coordinates, and frame pacing (`native_vsync`). What
remains is this one: even when pacing is correct and the loop presents on the
refresh boundary, each frame still costs a full re-raster, which shows up as
dropped frames on larger windows or heavier content.

`moui/render` already carries the vocabulary (`FrameDamage`, `Empty`,
`FullSurface`, `damage_index`, `DamageRegion`), and `moui_skia_renderer` has
`render_cached_layer.mbt` consuming damage for cached layers. The gap is that the
top-level raster path opts out of it.

## Why it is not fixed yet

The full-surface contract is load-bearing in more than one place:

- `renderer.mbt:446` treats `Empty | FullSurface(_)` as "nothing to do" for
  partial-damage bookkeeping, and `renderer.mbt:460` clears on `FullSurface`.
- `render_cached_layer.mbt:129` returns `false` for `FullSurface`, so cached-layer
  invalidation is written around the assumption.
- Presentation on several platforms implies "the whole surface is authoritative";
  a partial present needs a platform that can blit a sub-rect (EGL/OHOS can, but
  the Metal/Metal-like paths in this repo assume otherwise).

Turning it on for one platform means either a per-platform damage capability on
the render surface contract, or a renderer that presents sub-rects and a flag the
host sets. Both are contract changes under `docs/invariants.md` and need an ADR,
not a drive-by edit.

## Sketch of the intended shape

1. Add a damage capability to the render surface description (e.g.
   `present_damage: FullSurfaceOnly | SubRect`), defaulting to full surface so no
   platform changes behaviour.
2. Have `SkiaRasterRenderer::resolve_effective_damage` return the accumulated
   region when the surface reports `SubRect`.
3. Teach the HarmonyOS presenter (`harmonyos_present.cpp`,
   `moonbit_skia_surface_egl_*`) to flush only the dirty rects via
   `eglSwapBuffersWithDamageKHR`-style region submission or
   `OH_NativeWindow` damage regions.
4. Keep the clear-then-repaint path when the damage covers most of the surface;
   a partial present is only a win below some coverage threshold.

## Exit criteria

- Scrolling a 2090x1324 Showcase window presents sub-rect damage and the raster
  cost per frame drops measurably (record before/after numbers in the ADR).
- macOS / Web / Windows / Linux routes are byte-for-byte unaffected (the default
  stays full-surface).
- `checks/platforms/harmonyos.json` evidence is refreshed with the new numbers.

## Related

- `moui_skia_renderer/renderer.mbt` (`resolve_effective_damage`)
- `moui_skia_renderer/render_cached_layer.mbt`
- `moui/render/damage*.mbt`, `moui/render/image_resource*.mbt`
- `memories/repo/harmonyos-window-hosted.md` (the pacing/coordinate findings)
- `docs/invariants.md` (frame and renderer contract boundaries)

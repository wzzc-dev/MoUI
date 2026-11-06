# Plan: Full-surface redraw per frame (no damage rectangles)

- **Status**: debt, re-evaluated 2026-11-05
- **Goal**: Let a renderer present only the region a frame actually changed, so a
  scroll step or a caret blink stops re-rasterising the whole surface.
- **Non-goals**: changing the frame contract for platforms that already rely on
  full-surface overwrite (macOS Metal, Web, Windows D3D, Linux Vulkan); adding a
  second presentation path; optimising the Skia raster backend itself; adding
  EGL partial-swap code before the runtime can supply truthful rect damage and a
  matching device shows a frame-budget benefit.

## Context

The render protocol now has an explicit `SurfaceDamageCapability`
(`FullSurfaceOnly | SubRect`). `FullSurfaceOnly` preserves the historical
whole-surface overwrite and remains the default. The Skia CPU-raster path can
honour `SubRect` when a composition root opts in; a GPU drawable always falls
back to full because it does not retain the previous back buffer. No production
composition root negotiates `SubRect`, and the HarmonyOS/EGL presenter has no
partial-swap implementation.

During scroll work on HarmonyOS (see
`memories/repo/harmonyos-window-hosted.md`) three separate causes of "scroll feels
laggy" were found and fixed: a missing `pump_redraw_requested` on the wheel path,
physical-vs-logical pointer coordinates, and frame pacing (`native_vsync`). What
remains is the full-surface product of two independent inputs: precise runtime
damage and a presenter that can preserve/present a sub-rectangle.

`moui/render` already carries the vocabulary (`FrameDamage`, `Empty`,
`FullSurface`, `damage_index`, `DamageRegion`), and `moui_skia_renderer` has
`render_cached_layer.mbt` consuming damage for cached layers. The remaining gap
is upstream: after N5 removed app-owned scroll offsets, the normal Showcase
scroll path no longer activates the root, but it still raises layout dirt and
therefore produces full-surface damage.

## 2026-11-05 matching-device re-evaluation

A current-tree Showcase HAP was run on a matching `HAD-W32` (HarmonyOS
`7.0.0.107`, 2090×1324 surface, Maleoon 916, OpenGL ES 3.2):

- Two long drag runs measured 154 and 123 frames. Inter-frame p50/p95 was
  16/20 ms and 20/26 ms, so full-surface pacing was already around 50-60 fps.
- Frame p50/p95 was 4.99/7.80 ms and 5.20/8.00 ms; render was 8.91/11.06 ms
  and 8.63/11.26 ms. EGL present was only 1.2-2.4 ms.
- All 277 frames requested full-surface damage. Logged causes were "dirty
  region covers most of the surface", "activation rebuild", and one "dirty
  bounds unavailable". There was no rect damage to pass to a partial presenter.
- The scroll path still feeds `on_scroll` back into the Showcase model. The
  control marks that event `activated`, so each scroll step rebuilds the root
  even though `ScrollRuntimeState` already owns the transient offset.

The evidence does not support enabling partial presentation now. It is not a
waiver: the path is ineligible because runtime damage is full and the
full-surface frame budget is not being missed. Artifacts and logs are local at
`artifacts/harmonyos/w23b-baseline/` and are intentionally not committed.

## 2026-11-05 N5 follow-up

The Showcase shell now leaves transient offsets in element-owned
`ScrollRuntimeState`; only opening a different story issues a one-shot
`ScrollRequest`. Wheel and drag regressions show no program message/update and
no activation rebuild.

Damage remains full for a different reason:

- a wheel step ends at `layout changed`, because the scroll container still
  updates its layout-phase `child_transform`;
- a drag can accumulate a full region across multiple paint passes, ending at
  `damage accumulated across paint passes`.

The structural benchmark improved even without rect damage. Across two
identical 60-frame `native-skia-raster --structural-only` runs, layout counters
fell from 243 hits/693 misses to 63/279 and render counters from 117/522 to
27/108. No rect frame appeared, so the CPU-raster pixel self-check was not
activated and no partial-present path was added.

## Reopen conditions

All three must hold before implementation:

1. The runtime produces non-empty, correct rect damage during a Showcase scroll
   (not synthetic damage, and not a rect that omits moved pixels).
2. A matching device still measurably misses the full-surface frame/present
   budget after the runtime-side work is removed.
3. The device EGL surface exposes the preserved-buffer and damage-swap
   extensions needed by the presenter. Capability must not be inferred from
   the renderer name or HarmonyOS version.

The intended implementation then remains:

1. Exercise the existing CPU-raster pixel self-check against the device frame.
2. Teach the HarmonyOS presenter (`harmonyos_present.cpp`,
   `moonbit_skia_surface_egl_*`) to submit only the proven region.
3. Keep full-surface frames when damage coverage is large or the host rejects
   the partial path.
4. Record raster, present, frame-pacing, and stale-pixel evidence in ADR 0050
   before enabling the capability for that route.

## Exit criteria

- Adoption requires all reopen conditions plus a pixel-equal partial frame and
  a measurable matching-device improvement over the 2026-11-05 baseline.
- macOS / Web / Windows / Linux routes are byte-for-byte unaffected (the default
  stays full-surface).
- A non-adoption closure is valid when the matching-device evidence shows no
  eligible rect input or no missed full-surface budget; record the reopen
  conditions rather than leaving an indefinite "try partial damage" task.
- HarmonyOS platform evidence links the decision and refreshes when the route
  changes materially.

## Related

- `moui_skia_renderer/renderer.mbt` (`resolve_effective_damage`)
- `moui_skia_renderer/render_cached_layer.mbt`
- `moui/render/damage*.mbt`, `moui/render/image_resource*.mbt`
- `memories/repo/harmonyos-window-hosted.md` (the pacing/coordinate findings)
- `docs/invariants.md` (frame and renderer contract boundaries)

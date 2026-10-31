# Skia Renderer Performance Infrastructure

- `SkiaRasterRenderer.layer_cache` is a
  `Map[SkiaLayerCacheKey, SkiaCachedLayerImageEntry]`. Keys are structural
  (`SkiaLayerIdentity` = runtime key + route + scale factor + physical size,
  plus `content_revision`), derived `Eq`/`Hash` — there is no per-lookup
  string interpolation anymore. All lookups, stores, removes, and identity
  checks are O(1). Do not revert to `Array` — the eviction path was O(n²)
  before ADR 0007.
- A separate `layer_cache_identity_index : Map[SkiaLayerIdentity, SkiaLayerCacheKey]`
  maps identity → latest key. It must be kept in sync on every
  `store_cached_layer` / `remove_cached_layers_by_identity` /
  `invalidate_cached_layers_for_image_source` / `clear_layer_cache` call.
  The identity invariant (one entry per identity) is enforced through this
  index, not through linear scans. The picture cache mirrors the same
  key/index/accumulator shape.
- `layer_cache_total_bytes : Int64` is an accumulator maintained on every
  store/remove/evict/invalidate. Read this for O(1) byte-size checks; do not
  reintroduce an O(n) scan in `evict_cached_layers_if_needed`.
- `layer_cache_admissions : Map[SkiaLayerIdentity, SkiaCachedLayerAdmissionRecord]`
  is keyed by identity (not by revision key). Admission records track
  update streak, hit count, skip reason, last admitted frame, and last
  revision across multiple revisions of the same identity.
- Image load completion invalidates **only** the cached layers whose entry
  recorded the completed image source in `image_sources` (collected once per
  layer update by scanning the layer's command range for `DrawImage` runs);
  `apply_image_resource_load_completion` calls
  `invalidate_cached_layers_for_image_source` instead of `clear_layer_cache`.
  There is no image generation component in the layer cache key anymore.
  `clear_layer_cache()` remains the full-reset path for resize and dispose.
- `DrawFrame.clear_color` owns frame initialization; runtime frame commands do
  not contain a leading `Clear`. Legacy host/Web renderer adapters materialize
  that clear when lowering to command-only backends.
- The renderer consumes `DrawFrame.damage` via `resolve_effective_damage` +
  `apply_damage_clip` + `apply_damage_clear`. `Empty` and
  scope-command-present frames auto-fallback to `FullSurface`. `Rects` are
  conservatively unioned, then the complete command stream is clipped in
  logical coordinates after canvas scaling.
- `render_cached_command_range` takes `damage~ : DamageRegion` (defaults to
  `FullSurface`). `DrawCachedLayer` commands whose `frame` does not intersect
  any damage rect are skipped. Offscreen layer rendering (inside
  `update_cached_layer`) passes `FullSurface` and never skips.
- Damage region partial clear currently fires in only 1/5 benchmark scenarios
  (`showcase-sidebar-hover`). The other 4 return `FullSurface` from the
  runtime. Improving runtime damage computation is the next leverage point —
  the renderer-side infrastructure is complete.
- Layer cache strategy matches Flutter's `RasterCache`: byte budget
  (`layer_cache_budget_bytes()`), 3-frame warmup admission threshold,
  64 MiB cache cap, 512 admission record limit, LRU eviction with
  cold/large and churn-without-hit priority.
- Text shaping cache keys are structural (`SkiaTextShapingKey`, derived
  `Eq`/`Hash` over a hashed `FontSpec` mirror + resolution tag + text), with a
  bounded per-cache memo reusing one key object per distinct `FontSpec`. Never
  go back to `to_json().stringify()` keys or `@debug.to_string` keys — the
  latter was measured as the top frame while a large document opened (see the
  fallback-memo comment in `renderer_text_glyphs.mbt`). Double key fields are
  zero-normalized so `0.0`/`-0.0` cannot disagree between derived `Eq` and
  `Hash`. Cache hits return the cached `SkiaResolvedTextLayout` by reference —
  layouts are immutable after construction, so do not reintroduce
  `copy_layout`.
- Paint parameter objects are reused per renderer session: a bounded
  (`skia_paint_memo_capacity`) FIFO memo keyed by (color, style, width) backs
  `SkiaRasterRenderer::skia_paint` / `skia_stroke_paint` / `skia_opacity_paint`,
  and the fixed `Paint::new(anti_alias=true)` combination is the shared
  `skia_anti_alias_paint` value. Paints are immutable value structs, so
  sharing is safe; do not add per-op `Paint::new` again.
- The geometry wrappers `skia_rect` / `skia_point` / `skia_rrect` /
  `skia_matrix` still allocate per parameter: they wrap `@core` geometry into
  `@moui_skia` value structs whose fields are immutable (no `mut` fields to
  scratch-reuse without a `moui_skia` change, which is outside this
  renderer's package boundary). Field-copy cost only; not a measured hotspot.
- `draw_frame_to_canvas` reuses renderer-owned per-frame parameter objects:
  `frame_stats` (reset via `SkiaCachedLayerFrameStats::reset`) and
  `frame_canvas_scopes` (cleared). The picture-recording path
  (`draw_frame_to_picture_canvas`) keeps per-call locals on purpose —
  `record_frame_picture` is a pub host/worker entry point, so its frame state
  stays call-local even though it is currently same-thread.
- See ADR `docs/decisions/0007-skia-layer-cache-indexing-and-damage-region.md`
  for cache design and ADR
  `docs/decisions/0009-draw-frame-clear-and-skia-damage-clip.md` for the
  corrected frame/damage contract.
- Performance-budget p99 is not the maximum: below 100 samples the validator
  (`tools/moui/validate_performance_budgets`) reads the second-highest sample,
  because nearest-rank p99 would otherwise equal the worst frame and one
  scheduler hiccup on shared CI runners fails the gate (2026-10-26 run
  40276592135: single 127ms excel paint frame vs 49.6ms second-highest). When
  a budget gate trips, compare the second-highest sample against the limit
  before considering a re-baseline — a lone outlier is noise, a shifted tail
  is real.

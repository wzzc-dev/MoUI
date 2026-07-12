# Skia Renderer Performance Infrastructure

- `SkiaRasterRenderer.layer_cache` is a `Map[String, SkiaCachedLayerImageEntry]`
  keyed by `entry.key` (identity + revision + physical size). All lookups,
  stores, removes, and identity checks are O(1). Do not revert to `Array` —
  the eviction path was O(n²) before ADR 0007.
- A separate `layer_cache_identity_index : Map[String, String]` maps
  `identity_key` → latest `key`. It must be kept in sync on every
  `store_cached_layer` / `remove_cached_layers_by_identity` /
  `clear_layer_cache` call. The identity invariant (one entry per
  identity_key) is enforced through this index, not through linear scans.
- `layer_cache_total_bytes : Int64` is an accumulator maintained on every
  store/remove/evict. Read this for O(1) byte-size checks; do not reintroduce
  an O(n) scan in `evict_cached_layers_if_needed`.
- `layer_cache_admissions : Map[String, SkiaCachedLayerAdmissionRecord]` is
  keyed by `identity_key` (not by revision key). Admission records track
  update streak, hit count, skip reason, last admitted frame, and last
  revision across multiple revisions of the same identity.
- The renderer consumes `DrawFrame.damage` via `resolve_effective_damage` +
  `apply_damage_clear`. `Empty` and scope-command-present frames auto-fallback
  to `FullSurface`. `Rects` triggers per-rect `clip_rect + clear`.
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
- See ADR `docs/decisions/0007-skia-layer-cache-indexing-and-damage-region.md`
  for full design rationale, options considered, and benchmark data.

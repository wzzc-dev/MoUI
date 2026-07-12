# 0007: Skia Layer Cache Indexing and Damage Region Partial Clear

- **Date**: 2026-07-12
- **Status**: Accepted
- **Deciders**: Agent-assisted (Trae AI, GLM-5.2)
- **Related**: `moui/render/skia/renderer.mbt`, `moui/render/skia/renderer_cached_layer.mbt`, `moui/core/damage.mbt`, `docs/architecture.md`

## Context

MoUI's Skia renderer had two performance bottlenecks identified during a
comparison with mainstream GUI frameworks (Flutter/SwiftUI/Compose/iced):

1. **Layer cache O(n)/O(n²) scans**: `layer_cache` and `layer_cache_admissions`
   were stored as `Array[SkiacachedLayerImageEntry]`. Every lookup, identity
   check, admission record lookup, eviction candidate selection, and byte-size
   computation was a linear scan. The eviction path was O(n²) because
   `evict_cached_layers_if_needed` iterated the full array, and each eviction
   re-scanned to recompute total bytes. While n is small today (per-frame
   cached layer count is 2–16 in current benchmarks), this becomes a
   bottleneck for complex UIs with long lists or many cached subtrees.

2. **Damage region computed but ignored**: The runtime already computed a
   `DamageRegion` (`Empty` / `FullSurface` / `Rects`) per `DrawFrame`, but the
   Skia renderer unconditionally called `canvas.clear(clear_color)` over the
   full surface at the start of `render_frame_inner`. The computed damage was
   discarded. This is more aggressive than Flutter (which never does
   canvas-level partial clear) but the infrastructure was unused.

### Forces

- **Correctness first**: Both optimizations must not regress the 99 existing
  cached-layer wbtests or the visual regression smoke (showcase + markdown
  editor).
- **Framework alignment**: Flutter's `RasterCache` is the proven model — MoUI's
  layer cache should match its indexing/eviction strategy.
- **Risk asymmetry**: Layer cache indexing is pure data-structure refactor
  (zero visual risk). Damage region partial clear touches the clear path and
  needs scope-aware fallback.
- **Runtime damage coverage**: The runtime's damage computation only produces
  `Rects` in 1 of 5 benchmark scenarios today; 4/5 return `FullSurface`. The
  renderer-side work is infrastructure for future runtime improvements.

## Decision

Implement two independent optimizations, each shippable as a standalone PR.

### Part A: Layer Cache Indexing (O(n) → O(1))

Migrate the layer cache data structures from `Array` to `Map`-based indexing:

**Struct changes** (`renderer.mbt`):

```moonbit
priv layer_cache : Map[String, SkiaCachedLayerImageEntry]
priv layer_cache_identity_index : Map[String, String]
priv layer_cache_admissions : Map[String, SkiaCachedLayerAdmissionRecord]
priv mut layer_cache_total_bytes : Int64
priv mut layer_cache_tick : Int
```

- `layer_cache`: keyed by `entry.key` (identity + revision + physical size).
  Replaces linear `find` lookup with O(1) `Map.get`.
- `layer_cache_identity_index`: maps `identity_key` → latest `key`. Replaces
  linear `remove_stale_cached_layers_for_entry` and `layer_cache_has_identity`
  scans with O(1) lookup.
- `layer_cache_admissions`: keyed by `identity_key`. Replaces linear
  `layer_cache_admission_record` scan with O(1).
- `layer_cache_total_bytes`: accumulator maintained on every store/remove/evict.
  Replaces O(n) `layer_cache_byte_size` scan with O(1) read.

**Operation complexity changes** (`renderer_cached_layer.mbt`):

| Operation | Before | After |
|-----------|--------|-------|
| `lookup_cached_layer` | O(n) | O(1) |
| `layer_cache_admission_record` | O(n) | O(1) |
| `store_cached_layer` | O(n) (stale removal scan) | O(1) |
| `remove_stale_cached_layers_for_entry` | O(n) | O(1) |
| `remove_cached_layers_by_identity` | O(n) | O(1) |
| `evict_cached_layers_if_needed` | O(n²) (rescan bytes each iteration) | O(n) |
| `layer_cache_byte_size` | O(n) | O(1) |
| `layer_cache_has_identity` | O(n) | O(1) |

**Invariant preservation**:
- `identity_key` uniqueness maintained via `layer_cache_identity_index` —
  `store_cached_layer` updates the index atomically with the cache write.
- Byte total maintained via `layer_cache_total_bytes` — every store subtracts
  any old entry's bytes, then adds the new entry's bytes; every remove/evict
  subtracts.
- `clear_layer_cache` resets all three Maps and zeroes the accumulator.

### Part B: Damage Region Partial Clear

Make the renderer consume `DrawFrame.damage` instead of ignoring it.

**New functions** (`renderer.mbt`):

1. `resolve_effective_damage(frame) -> DamageRegion`
   - `Empty` → auto-fallback to `FullSurface("empty damage fallback")`
   - Pre-scans commands for `PushOpacity` / `PushLayer` / `PushFilter` — if
     present, fallback to `FullSurface("scope commands present")` because
     partial clear under active scopes is unsafe.
   - `FullSurface` and `Rects` pass through unchanged.

2. `apply_damage_clear(canvas, damage, clear_color, surface_size)`
   - `FullSurface` → `canvas.clear(color)` (existing path, unchanged)
   - `Rects` → for each rect: `canvas.save()` → `canvas.clip_rect(rect)` →
     `canvas.clear(color)` → `canvas.restore()`. Non-overlapping rects only;
     overlapping rects would double-clear (acceptable: correctness preserved,
     just wasted work).

**Command skipping** (`renderer_cached_layer.mbt`):

- `render_cached_command_range` gains `damage~ : DamageRegion` parameter
  (defaults to `FullSurface` so offscreen layer rendering is unaffected).
- `DrawCachedLayer` branch checks `should_skip_command_for_damage(spec.frame, damage)`:
  - `FullSurface` → never skip
  - `Rects` → skip if `frame.intersection(rect)` is `None` for all damage
    rects (the cached layer's pixels didn't change)
  - `Empty` → never reached (already fallback to `FullSurface`)

**Fallback strategy** (conservative):
- Any scope command in the frame → `FullSurface` (don't risk partial clear
  under PushOpacity/PushLayer/PushFilter)
- `Empty` damage → `FullSurface` (Empty means "unknown", not "nothing to
  clear")
- Damage rect count exceeds `damage_region_max_rects` (8) → runtime already
  collapses to `FullSurface` before reaching the renderer

## Options Considered

### Option A: Layer Cache — `Map` with separate identity index (chosen)

- Pros: O(1) on all hot paths; preserves two-level key scheme (revision key
  for lookup, identity key for admission tracking); minimal API surface change.
- Cons: Extra `layer_cache_identity_index` Map adds ~one pointer per entry;
  identity index must be kept in sync on store/remove.

### Option B: Layer Cache — Sorted `Array` with binary search

- Pros: Better cache locality than `Map`; no hash overhead.
- Cons: Binary search requires sorted keys; insertion becomes O(n log n);
  eviction still needs full scan for cold/large candidates. Rejected — the
  access pattern is hash-style (lookup by exact key), not range-scan.

### Option C: Damage Region — Canvas-level partial clear (chosen)

- Pros: More aggressive than Flutter — can save raster work on small dirty
  regions (sidebar hover, caret blink).
- Cons: Risk of visual residue if damage computation is wrong; needs scope
  fallback; only 1/5 benchmark scenarios produce `Rects` today, so current
  benefit is limited.

### Option D: Damage Region — Flutter-style layer-level skip only

- Pros: No partial clear risk — only skip whole `DrawCachedLayer` commands
  whose frame is outside damage rects.
- Cons: Misses the clear-path savings; doesn't help non-cached scenarios.
  Rejected — Part B's canvas clear is the foundation for future
  command-level skip extensions.

### Option E: Damage Region — Delete Part B entirely

- Pros: Removes ~80 lines of "dead code" that only fires in 1/5 scenarios.
- Cons: Loses infrastructure for future runtime damage improvements;
  re-implementing later requires redoing tests and scope fallback logic.
  Rejected — Part B is infrastructure investment, not a finished optimization.

## Rationale

1. **Part A is zero-risk and aligns with Flutter's `RasterCache`**: pure
   data-structure refactor, all 99 existing tests pass, byte counts and
   hit/miss counts unchanged. The O(n²) eviction path was a latent bug for
   complex UIs; fixing it now is cheap insurance.

2. **Part B is infrastructure for the runtime damage roadmap**: The renderer
   is now a consumer of `DamageRegion`. Any future runtime improvement that
   produces more `Rects` damage immediately benefits the renderer without
   further renderer changes. Deleting Part B would block that roadmap.

3. **Conservative fallback strategy**: The three fallbacks (Empty → FullSurface,
  scope commands → FullSurface, too many rects → FullSurface at runtime) mean
  Part B can never produce visual residue in the unsafe cases — it just
  degenerates to the existing full-clear path.

4. **Framework positioning**: MoUI's layer cache now matches Flutter's
   `RasterCache` strategy (budget + admission + eviction + revision key).
   MoUI's damage region handling is more aggressive than Flutter (Flutter
   never does canvas partial clear) — this is a deliberate bet that MoUI's
   runtime can eventually produce precise damage rects.

## Consequences

### Positive

- Layer cache hot paths are O(1); eviction is O(n) instead of O(n²). Complex
  UIs with many cached subtrees will scale better.
- Renderer is now damage-aware: future runtime damage improvements get free
  renderer-side wins.
- 5 new wbtests cover the damage path (FullSurface baseline, Rects partial
  clear, Empty fallback, DrawCachedLayer skip, scope fallback).
- Visual regression smoke (showcase + markdown editor) passes.

### Negative

- Part B currently fires in only 1/5 benchmark scenarios
  (`showcase-sidebar-hover`). The other 4 return `FullSurface` from the
  runtime, so Part B is effectively no-op there.
- `render_frame_inner` is more complex (scope pre-scan + damage branch).
- `render_cached_command_range` signature gained a `damage~` parameter.

### Follow-up Work Needed

- **Runtime damage computation improvement**: Make more scenarios produce
  `Rects` instead of `FullSurface`. Current `first_full_reason` values:
  - `"initial frame"` — 3 scenarios return FullSurface after first frame
  - `"dirty bounds unavailable"` — markdown-editor-scroll can't compute
    dirty bounds
- **Extend command skip whitelist**: Currently only `DrawCachedLayer` is
  skipped. `FillRect` / `DrawText` / `DrawImage` could also be skipped when
  their bounds are outside damage rects.
- **Scope command granular fallback**: Instead of falling back to
  `FullSurface` whenever any scope command exists, track scope depth and only
  fallback if the scope intersects damage rects.

## Agent Notes

- **Session context**: Continuing a performance analysis session comparing
  MoUI with Flutter/SwiftUI/Compose/iced. User asked to optimize two
  bottlenecks: layer cache O(n)/O(n²) and unused damage region.
- **Agent model**: GLM-5.2 (Trae AI)
- **Key prompt or instruction**: "两个优化都做" (do both optimizations) +
  "完整 + 自动回退 FullSurface" (complete solution with auto-fallback to
  FullSurface for scope commands).
- **Validation**:
  - `moon check moui/render/skia --target native` — 0 errors, 0 warnings
  - `moon test moui/render/skia --target native` — 104/104 tests pass
    (99 existing + 5 new damage wbtests)
  - `moon run moui/tests/skia_cached_layer_benchmark/native --target native`
    — cache_hit/miss counts unchanged
  - `moon run benchmarks/app_cached_layer/native --target native` — benchmark
    counts unchanged across 5 scenarios
  - `scripts/macos-skia-renderer-smoke.sh` — exit 0
  - `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke`
    — exit 0 (visual regression)
  - `sh scripts/check.sh --profile daily` — exit 0

### Benchmark Results (post-optimization)

| Scenario | cached_avg_ms | full_avg_ms | speedup | cache_hits | damage_rect_frames | damage_full_frames |
|----------|---------------|-------------|---------|------------|--------------------|--------------------|
| showcase-runtime-scroll | 1.21 | 8.78 | 7.25x | 180 | 0 | 90 |
| showcase-sidebar-hover | 1.79 | 8.52 | 4.75x | 0 | 90 | 0 |
| markdown-editor-text-input | 0.41 | 11.78 | 28.52x | 270 | 0 | 90 |
| markdown-editor-scroll | 1.77 | 13.10 | 7.42x | 1440 | 0 | 90 |
| markdown-editor-caret-overlay | 0.45 | 10.16 | 22.37x | 270 | 0 | 90 |

**Key observations**:
- Part A: cache_hit/miss counts identical to pre-optimization — no regression.
  Absolute time savings are microseconds (n is small), but O(n²) eviction risk
  is eliminated for future complex UIs.
- Part B: only `showcase-sidebar-hover` produces `Rects` damage (90/90 frames).
  Other 4 scenarios return `FullSurface` from runtime — Part B degenerates to
  existing clear path, no regression.

## References

- **Plan file**: `.trae/documents/skia-layer-cache-and-damage-region-optimization.md`
- **Renderer struct**: `moui/render/skia/renderer.mbt` (lines 51–73)
- **Layer cache operations**: `moui/render/skia/renderer_cached_layer.mbt`
- **Damage region types**: `moui/core/damage.mbt`
- **Damage wbtests**: `moui/render/skia/skia_renderer_damage_wbtest.mbt`
- **Frame cache wbtests**: `moui/render/skia/skia_renderer_frame_cache_wbtest.mbt`
  (updated for Map iteration access)
- **Framework comparison**: Flutter `RasterCache`
  (https://api.flutter.dev/flutter/painting/RasterCache-class.html)

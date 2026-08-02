# 2026-07-12: Skia Layer Cache Indexing and Damage Region Partial Clear

- **Agent**: Trae AI (GLM-5.2)
- **Goal**: Optimize two Skia renderer performance bottlenecks identified
  during a GUI framework comparison with Flutter/SwiftUI/Compose/iced.
- **Outcome**: Success — both optimizations landed, 104/104 tests pass,
  visual regression smoke green, `check.sh --profile daily` green.

## Summary

Migrated the Skia layer cache from `Array` to `Map`-based indexing (O(n)→O(1)
on all hot paths, O(n²)→O(n) on eviction), and made the renderer consume
`DrawFrame.damage` for partial surface clearing instead of unconditionally
clearing the full surface. Both optimizations are infrastructure-grade: Part A
eliminates a latent O(n²) bottleneck for future complex UIs; Part B is the
foundation for future runtime damage computation improvements.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui/render/skia/renderer.mbt` | Migrated `layer_cache`, `layer_cache_admissions` from `Array` to `Map`; added `layer_cache_identity_index`, `layer_cache_total_bytes` fields; added `resolve_effective_damage` and `apply_damage_clear` functions; replaced unconditional `canvas.clear` in `render_frame_inner` with damage-aware clearing | Part A indexing + Part B damage clear |
| `moui/render/skia/renderer_cached_layer.mbt` | Rewrote `lookup_cached_layer`, `store_cached_layer`, `remove_stale_cached_layers_for_entry`, `remove_cached_layers_by_identity`, `evict_cached_layers_if_needed`, `layer_cache_byte_size`, `layer_cache_has_identity`, `prune_layer_cache_admission_records`, `clear_layer_cache` to use Map operations; renamed `cached_layer_eviction_index`→`cached_layer_eviction_entry` and `oldest_cached_layer_index`→`oldest_cached_layer_entry` (now return tuples); added `should_skip_command_for_damage` helper; added `damage~` parameter to `render_cached_command_range` | Part A O(1) operations + Part B DrawCachedLayer skip |
| `moui/render/skia/skia_renderer_frame_cache_wbtest.mbt` | Replaced Array index access (`layer_cache_admissions[0]`) with Map iteration for 2 existing tests | Array→Map migration |
| `moui/render/skia/skia_renderer_test_helpers_wbtest.mbt` | Added `skia_test_draw_frame_with_damage` helper | Part B test infrastructure |
| `moui/render/skia/skia_renderer_damage_wbtest.mbt` | New file — 5 tests: FullSurface baseline, Rects partial clear, Empty fallback, DrawCachedLayer skip, scope fallback | Part B coverage |
| `docs/decisions/0007-renderer-and-skia.md` | New ADR | Formal decision record |
| `docs/decisions/README.md` | Added 0007 to index | ADR index |
| `memories/repo/skia-renderer-perf.md` | New quick-reference facts file | Agent auto-load reference |

## Key Decisions

- **Part A: `Map` with separate identity index** — chosen over sorted `Array`
  with binary search because the access pattern is hash-style (lookup by
  exact key), not range-scan. (→ ADR 0007 Option A vs B)
- **Part B: Canvas-level partial clear** — chosen over Flutter-style
  layer-level skip only because the canvas clear is the foundation for future
  command-level skip extensions. More aggressive than Flutter (which never
  does canvas partial clear), but conservative fallbacks make it safe.
  (→ ADR 0007 Option C vs D)
- **Part B: Conservative fallback strategy** — `Empty`→`FullSurface`,
  scope commands present→`FullSurface`, too many rects→`FullSurface` at
  runtime. Part B can never produce visual residue in unsafe cases; it
  degenerates to the existing full-clear path.
- **Part B not deleted despite limited current benefit** — only 1/5 benchmark
  scenarios produce `Rects` damage today. Kept as infrastructure for the
  runtime damage roadmap. (→ ADR 0007 Option E rejected)

## Discoveries

- **MoonBit `panic` takes 0 args** — signature is `() -> String`. Use
  `abort(msg)` for panic-with-message (`pub fn[T] abort(String) -> T`).
- **`.is_some()` is deprecated** — use `is Some(_)` pattern instead.
- **MoonBit `Map.get` returns modifiable reference** for structs with `mut`
  fields — `entry.last_used = tick` works directly on the returned reference.
- **No `Set[T]` in MoonBit core** — use `Map[String, Unit]` as alternative.
- **`moon check`/`moon test` for `moui/render/skia` requires `--target native`**
  — the package only supports the native target.
- **Flutter never does canvas-level partial clear** — it relies entirely on
  `RasterCache` layer reuse. MoUI's Part B is more aggressive than Flutter's
  approach, which is a deliberate bet on future runtime damage precision.
- **Runtime damage coverage is the bottleneck for Part B benefit** —
  `first_full_reason` shows 3 scenarios return `"initial frame"` and 1 returns
  `"dirty bounds unavailable"`. The renderer is ready; the runtime is not.

## Validation

```sh
moon check moui/render/skia --target native          # 0 errors, 0 warnings
moon test moui/render/skia --target native           # 104/104 pass
moon run moui/tests/skia_cached_layer_benchmark/native --target native  # counts unchanged
moon run benchmarks/app_cached_layer/native --target native             # 5 scenarios, counts unchanged
scripts/macos-skia-renderer-smoke.sh                                   # exit 0
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke  # exit 0
sh scripts/check.sh --profile daily                   # exit 0
```

### Benchmark Results (post-optimization)

| Scenario | cached_avg_ms | full_avg_ms | speedup | cache_hits | damage_rect_frames | damage_full_frames |
|----------|---------------|-------------|---------|------------|--------------------|--------------------|
| showcase-runtime-scroll | 1.21 | 8.78 | 7.25x | 180 | 0 | 90 |
| showcase-sidebar-hover | 1.79 | 8.52 | 4.75x | 0 | 90 | 0 |
| markdown-editor-text-input | 0.41 | 11.78 | 28.52x | 270 | 0 | 90 |
| markdown-editor-scroll | 1.77 | 13.10 | 7.42x | 1440 | 0 | 90 |
| markdown-editor-caret-overlay | 0.45 | 10.16 | 22.37x | 270 | 0 | 90 |

## Follow-Up

- [ ] Runtime damage computation improvement — make more scenarios produce
      `Rects` instead of `FullSurface` (3 scenarios return `"initial frame"`,
      1 returns `"dirty bounds unavailable"`).
- [ ] Extend command skip whitelist — `FillRect` / `DrawText` / `DrawImage`
      could also be skipped when bounds are outside damage rects.
- [ ] Scope command granular fallback — track scope depth instead of
      falling back to `FullSurface` whenever any scope command exists.
- [ ] Related ADR: `docs/decisions/0007-renderer-and-skia.md`

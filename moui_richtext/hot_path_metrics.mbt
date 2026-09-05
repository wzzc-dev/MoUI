///|
/// Package-private counters for editor hot paths.
///
/// White-box tests and the gated hot-path benchmark assert on these
/// counters so the performance invariants (no full-document parse per
/// keystroke, no full height walk per wheel event, one paragraph layout
/// shared by paint/caret/hit-test) are machine-checkable instead of
/// relying on wall-clock thresholds. The runtime is single-threaded and
/// counters are reset by each test that reads them.

///|
/// `parse_markdown_editor_blocks` over the whole source (session `new` or
/// the full-parse `apply` path).
let hot_path_full_parse_count : Ref[Int] = Ref(0)

///|
/// `apply` calls that re-parsed only the affected source region.
let hot_path_region_reparse_count : Ref[Int] = Ref(0)

///|
/// `apply` calls that fell back to a full re-parse from the incremental
/// region path (region expansion refused).
let hot_path_incremental_fallback_count : Ref[Int] = Ref(0)

///|
/// Blocks visited while (re)building the scroll block-height array.
let hot_path_block_height_walk_blocks : Ref[Int] = Ref(0)

///|
/// Scroll geometry reads served from the persisted prefix-sum index.
let hot_path_scroll_geometry_cache_hits : Ref[Int] = Ref(0)

///|
/// Measured-height landings applied to the live scroll geometry through
/// the O(log n) Fenwick point update (instead of invalidating it).
let hot_path_scroll_geometry_point_updates : Ref[Int] = Ref(0)

///|
/// Scroll geometry reads served by rebasing the live entry in place after
/// an incremental edit (window splice + point updates) instead of walking
/// every block again.
let hot_path_scroll_geometry_rebase_hits : Ref[Int] = Ref(0)

///|
/// Rich-text block conversions executed (cache misses).
let hot_path_block_conversion_builds : Ref[Int] = Ref(0)

///|
/// Soft-wrap paragraph layouts built (cache misses) for wrapped blocks.
let hot_path_block_wrap_builds : Ref[Int] = Ref(0)

///|
/// Soft-wrap paragraph layouts reused from the cache.
let hot_path_block_wrap_cache_hits : Ref[Int] = Ref(0)

///|
/// Block fingerprint strings built in `markdown_document_assign_blocks`.
/// With a reindex window only the re-parse window (whose blocks may have
/// changed content) pays fingerprint construction; the untouched prefix
/// and suffix reuse the previous fingerprints by reference.
let hot_path_block_fingerprints_built : Ref[Int] = Ref(0)

///|
/// Per-block height metrics recomputed from source in
/// `markdown_document_height_index`. Outside the re-parse window the
/// metrics are reused (their heights depend on unchanged content), so
/// this counts only window blocks.
let hot_path_height_metrics_recomputed : Ref[Int] = Ref(0)

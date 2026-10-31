///|
/// Session-scoped shaping cache (ADR 0034 batch, renderer-owned per P16):
/// every `DrawText` frame re-shapes identical `(font, text, resolution)`
/// runs. Resolved layouts are immutable after construction (see `resolve`),
/// so an LRU over them is hit-free to replay and hits share the cached layout
/// instead of copying it. Keys are structural (`SkiaTextShapingKey`, hashed
/// without building JSON strings); the per-spec portion is memoized so a
/// repeated font reuses one key object. Hit/miss deltas fold into the
/// existing `RenderFrameResult` cache counters; no protocol field changes.

///|
/// Hashable mirror of one `FontFamily`. `@core.FontFamily` derives `Eq` but
/// not `Hash`, so the structured key carries a stable tag plus the `Name`
/// payload. Kept package-local: the shaping cache owns its key format.
priv struct SkiaShapingFamilyKey {
  tag : Int32
  name : String
} derive(Eq, Hash)

///|
/// Hashable mirror of one `FontVariation` axis/value pair.
priv struct SkiaShapingVariationKey {
  axis : String
  value : Double
} derive(Eq, Hash)

///|
/// Hashable mirror of `@core.FontSpec`. Field-for-field: family stack (tagged
/// because the enum has a `Name(String)` payload), size, weight, style, and
/// variation axes. Double fields are zero-normalized so `0.0` and `-0.0`
/// (equal under `Eq`) cannot end up with different hashes in a `Map` key.
priv struct SkiaShapingFontKey {
  families : Array[SkiaShapingFamilyKey]
  size : Double
  weight : Int32
  style : Int32
  variations : Array[SkiaShapingVariationKey]
} derive(Eq, Hash)

///|
/// Full shaping cache key: structural font identity plus resolution and the
/// text itself. Replaces the former `font_spec.to_json().stringify() + tag +
/// text` concatenation that allocated a JSON tree, a stringified document,
/// and a merged string on every lookup.
priv struct SkiaTextShapingKey {
  font : SkiaShapingFontKey
  system_font_mgr : Bool
  text : String
} derive(Eq, Hash)

///|
priv struct SkiaTextShapingEntry {
  layout : SkiaResolvedTextLayout
  mut last_used : Int32
}

///|
priv struct SkiaTextShapingCache {
  entries : Map[SkiaTextShapingKey, SkiaTextShapingEntry]
  /// Bounded memo of `FontSpec -> SkiaShapingFontKey`. Building the key copies
  /// the family and variation arrays, and fonts repeat across a whole frame
  /// (usually one or two distinct specs), so the memo turns the per-lookup
  /// key construction into a short structural scan with zero array copies.
  font_keys : Array[(@core.FontSpec, SkiaShapingFontKey)]
  mut tick : Int32
  mut total_hits : Int32
  mut total_misses : Int32
  mut frame_mark_hits : Int32
  mut frame_mark_misses : Int32
}

///|
let skia_text_shaping_cache_capacity = 256

///|
/// Distinct font specs per session are the app's font configurations —
/// small. The memo is a plain FIFO: overflowing it only costs rebuilding a
/// key later (keys are compared structurally in the map, never by identity,
/// so eviction cannot alias), which is why no LRU bookkeeping is needed.
let skia_font_key_memo_capacity = 64

///|
fn SkiaTextShapingCache::new() -> SkiaTextShapingCache {
  {
    entries: Map([]),
    font_keys: [],
    tick: 0,
    total_hits: 0,
    total_misses: 0,
    frame_mark_hits: 0,
    frame_mark_misses: 0,
  }
}

///|
/// Normalize equal-under-`Eq` zeros so the derived `Hash` of a `Map` key
/// cannot disagree with its derived `Eq` (`0.0 == -0.0` but their bits — and
/// therefore a bit-derived hash — differ).
fn skia_shaping_hash_double(value : Double) -> Double {
  if value == 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn skia_shaping_family_key(family : @core.FontFamily) -> SkiaShapingFamilyKey {
  match family {
    Name(name) => { tag: 0, name, }
    SystemUi => { tag: 1, name: "", }
    UiSansSerif => { tag: 2, name: "", }
    UiSerif => { tag: 3, name: "", }
    UiMonospace => { tag: 4, name: "", }
    SansSerif => { tag: 5, name: "", }
    Serif => { tag: 6, name: "", }
    Monospace => { tag: 7, name: "", }
    Emoji => { tag: 8, name: "", }
    Math => { tag: 9, name: "", }
    FangSong => { tag: 10, name: "", }
  }
}

///|
fn skia_shaping_font_key(font_spec : @core.FontSpec) -> SkiaShapingFontKey {
  let families : Array[SkiaShapingFamilyKey] = []
  for family in font_spec.families.families {
    families.push(skia_shaping_family_key(family))
  }
  let variations : Array[SkiaShapingVariationKey] = []
  for variation in font_spec.variations {
    variations.push({
      axis: variation.axis,
      value: skia_shaping_hash_double(variation.value),
    })
  }
  {
    families,
    size: skia_shaping_hash_double(font_spec.size),
    weight: font_spec.weight,
    style: match font_spec.style {
      Normal => 0
      Italic => 1
    },
    variations,
  }
}

///|
fn SkiaTextShapingCache::memoized_font_key(
  self : SkiaTextShapingCache,
  font_spec : @core.FontSpec,
) -> SkiaShapingFontKey {
  for memo in self.font_keys {
    if memo.0 == font_spec {
      return memo.1
    }
  }
  let key = skia_shaping_font_key(font_spec)
  if self.font_keys.length() >= skia_font_key_memo_capacity {
    ignore(self.font_keys.remove(0))
  }
  self.font_keys.push((font_spec, key))
  key
}

///|
fn SkiaTextShapingCache::shaping_key(
  self : SkiaTextShapingCache,
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaTextShapingKey {
  {
    font: self.memoized_font_key(font_spec),
    system_font_mgr: resolution is SystemFontMgr,
    text,
  }
}

///|
fn SkiaTextShapingCache::begin_frame(self : SkiaTextShapingCache) -> Unit {
  self.frame_mark_hits = self.total_hits
  self.frame_mark_misses = self.total_misses
}

///|
fn SkiaTextShapingCache::frame_delta(
  self : SkiaTextShapingCache,
) -> (Int32, Int32) {
  (
    self.total_hits - self.frame_mark_hits,
    self.total_misses - self.frame_mark_misses,
  )
}

///|
fn SkiaTextShapingCache::resolve(
  self : SkiaTextShapingCache,
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
  shape : () -> SkiaResolvedTextLayout?,
) -> SkiaResolvedTextLayout? {
  self.tick = self.tick + 1
  let key = self.shaping_key(font_spec, text, resolution)
  match self.entries.get(key) {
    Some(entry) => {
      entry.last_used = self.tick
      self.total_hits = self.total_hits + 1
      // Shared-layout replay, no per-hit copy. The cached layout is immutable
      // after construction: `SkiaResolvedTextLayout.segments` is only
      // appended to inside `skia_resolved_text_segments`/`
      // skia_resolved_text_layout_for_resolution` before the layout is handed
      // to the cache, and every consumer (`draw_text`, caret measurement,
      // diagnostics) only reads fields and iterates. MoonBit structs are
      // reference values, so returning the cached layout shares it; the old
      // `copy_layout` only duplicated the segments array anyway (glyph runs
      // and font handles were already shared), so sharing gives up nothing
      // while removing the per-hit array allocation.
      Some(entry.layout)
    }
    None => {
      self.total_misses = self.total_misses + 1
      match shape() {
        Some(layout) => {
          self.entries[key] = { layout, last_used: self.tick, }
          self.evict_if_needed()
          Some(layout)
        }
        None => None
      }
    }
  }
}

///|
fn SkiaTextShapingCache::evict_if_needed(self : SkiaTextShapingCache) -> Unit {
  while self.entries.length() > skia_text_shaping_cache_capacity {
    let mut oldest_key : SkiaTextShapingKey? = None
    let mut oldest_tick = self.tick + 1
    for key, entry in self.entries {
      if entry.last_used < oldest_tick {
        oldest_key = Some(key)
        oldest_tick = entry.last_used
      }
    }
    match oldest_key {
      Some(key) => ignore(self.entries.remove(key))
      None => break
    }
  }
}

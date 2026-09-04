///|
/// Session-scoped shaping cache (ADR 0034 batch, renderer-owned per P16):
/// every `DrawText` frame re-shapes identical `(font, text, resolution)`
/// runs. Resolved layouts are pure values plus live font handles, so an LRU
/// over them is hit-free to replay. Hit/miss deltas fold into the existing
/// `RenderFrameResult` cache counters; no protocol field changes.

///|
priv struct SkiaTextShapingEntry {
  layout : SkiaResolvedTextLayout
  mut last_used : Int
}

///|
priv struct SkiaTextShapingCache {
  entries : Map[String, SkiaTextShapingEntry]
  mut tick : Int
  mut total_hits : Int
  mut total_misses : Int
  mut frame_mark_hits : Int
  mut frame_mark_misses : Int
}

///|
let skia_text_shaping_cache_capacity = 256

///|
fn SkiaTextShapingCache::new() -> SkiaTextShapingCache {
  {
    entries: Map([]),
    tick: 0,
    total_hits: 0,
    total_misses: 0,
    frame_mark_hits: 0,
    frame_mark_misses: 0,
  }
}

///|
fn skia_text_shaping_cache_key(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> String {
  let resolution_tag = match resolution {
    SkiaFontResolution::SystemFontMgr => "system"
    SkiaFontResolution::EmptyTypeface => "empty"
  }
  font_spec.to_json().stringify() + "\{resolution_tag}\n" + text
}

///|
fn SkiaTextShapingCache::begin_frame(self : SkiaTextShapingCache) -> Unit {
  self.frame_mark_hits = self.total_hits
  self.frame_mark_misses = self.total_misses
}

///|
fn SkiaTextShapingCache::frame_delta(self : SkiaTextShapingCache) -> (Int, Int) {
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
  let key = skia_text_shaping_cache_key(font_spec, text, resolution)
  match self.entries.get(key) {
    Some(entry) => {
      entry.last_used = self.tick
      self.total_hits = self.total_hits + 1
      Some(entry.layout.copy_layout())
    }
    None => {
      self.total_misses = self.total_misses + 1
      match shape() {
        Some(layout) => {
          self.entries[key] = { layout, last_used: self.tick }
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
    let mut oldest_key : String? = None
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

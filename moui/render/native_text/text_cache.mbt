///|
// Memoized platform text results for one renderer instance. A renderer holds
// one and shares it with its glyph atlas; nothing here depends on a concrete
// rendering backend.
pub struct NativeTextCache {
  priv engine : NativeTextEngine
  priv measure_cache : Map[String, @core.TextLayoutResult]
  priv layout_cache : Map[String, NativeTextLayout]
}

///|
pub fn NativeTextCache::new() -> NativeTextCache {
  NativeTextCache::new_with_engine(native_noop_text_engine())
}

///|
pub fn NativeTextCache::new_with_engine(
  engine : NativeTextEngine,
) -> NativeTextCache {
  { engine, measure_cache: Map([]), layout_cache: Map([]), }
}

///|
pub fn NativeTextCache::engine(self : NativeTextCache) -> NativeTextEngine {
  self.engine
}

///|
pub fn NativeTextCache::measure(
  self : NativeTextCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let key = input.text +
    "|" +
    input.font.to_json().stringify() +
    "|" +
    Json(input.max_width).stringify()
  match self.measure_cache.get(key) {
    Some(result) => result
    None => {
      let result = self.engine.measure(input)
      self.measure_cache[key] = result
      result
    }
  }
}

///|
pub fn NativeTextCache::layout_run(
  self : NativeTextCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  let key = run.text +
    "|" +
    run.font.to_json().stringify() +
    "|" +
    run.frame.size.width.to_string() +
    "|" +
    scale_factor.to_string()
  match self.layout_cache.get(key) {
    Some(layout) => Some(layout)
    None =>
      match self.engine.layout_run(run, scale_factor) {
        Some(layout) => {
          self.layout_cache[key] = layout
          Some(layout)
        }
        None => None
      }
  }
}

///|
// Retry a run against the engine's explicit fallback provider. Uncached by
// design: the caller only reaches it after the primary layout failed to fill a
// glyph atlas.
pub fn NativeTextCache::fallback_layout_run(
  self : NativeTextCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  self.engine.fallback_layout_run(run, scale_factor)
}

///|
pub fn NativeTextCache::raster_glyph(
  self : NativeTextCache,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  self.engine.raster_glyph(key)
}

///|
pub fn NativeTextCache::register_font_data(
  self : NativeTextCache,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  self.engine.register_font_data(family, data)
}

///|
fn NativeTextEngine::measure(
  self : NativeTextEngine,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  match (self.provider.measure)(input) {
    Some(layout) =>
      if layout.is_valid_for_measure(input.text) {
        layout.to_text_layout_result()
      } else {
        self.measure_with_fallback(input)
      }
    None => self.measure_with_fallback(input)
  }
}

///|
fn NativeTextEngine::measure_with_fallback(
  self : NativeTextEngine,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  match self.fallback {
    Some(fallback) =>
      match (fallback.measure)(input) {
        Some(layout) =>
          if layout.is_valid_for_measure(input.text) {
            layout.to_text_layout_result()
          } else {
            @core.TextSystem::fallback().measure_text(input)
          }
        None => @core.TextSystem::fallback().measure_text(input)
      }
    None => @core.TextSystem::fallback().measure_text(input)
  }
}

///|
fn NativeTextEngine::layout_run(
  self : NativeTextEngine,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  match (self.provider.layout_run)(run, scale_factor) {
    Some(layout) if layout.is_valid_for_run(run.text) => Some(layout)
    _ => self.fallback_layout_run(run, scale_factor)
  }
}

///|
fn NativeTextEngine::fallback_layout_run(
  self : NativeTextEngine,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  match self.fallback {
    Some(fallback) =>
      match (fallback.layout_run)(run, scale_factor) {
        Some(layout) =>
          if layout.is_valid_for_run(run.text) {
            Some(layout)
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn NativeTextEngine::raster_glyph(
  self : NativeTextEngine,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  match (self.provider.raster_glyph)(key.cache_key, key.payload) {
    Some(glyph) if glyph.is_valid() => Some(glyph)
    _ => self.fallback_raster_glyph(key)
  }
}

///|
fn NativeTextEngine::fallback_raster_glyph(
  self : NativeTextEngine,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  match self.fallback {
    Some(fallback) =>
      match (fallback.raster_glyph)(key.cache_key, key.payload) {
        Some(glyph) => if glyph.is_valid() { Some(glyph) } else { None }
        None => None
      }
    None => None
  }
}

///|
fn NativeTextEngine::register_font_data(
  self : NativeTextEngine,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  (self.provider.register_font_data)(family, data)
  match self.fallback {
    Some(fallback) => (fallback.register_font_data)(family, data)
    None => ()
  }
}

///|
pub fn native_text_system() -> @core.TextSystem {
  native_text_system_with_cache(NativeTextCache::new())
}

///|
pub fn native_text_system_with_engine(
  engine : NativeTextEngine,
) -> @core.TextSystem {
  native_text_system_with_cache(NativeTextCache::new_with_engine(engine))
}

///|
pub fn native_text_system_with_cache(
  cache : NativeTextCache,
) -> @core.TextSystem {
  @core.TextSystem::new(
    id=cache.engine.id(),
    measure=input => cache.measure(input),
    register_font_data=(family, data) => cache.register_font_data(family, data),
  )
}

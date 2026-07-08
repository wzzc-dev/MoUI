///|
fn NativeTextEngine::measure(
  self : NativeTextEngine,
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let _ = cache
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
  cache : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  let _ = cache
  match (self.provider.layout_run)(run, scale_factor) {
    Some(layout) =>
      if layout.is_valid_for_run(run.text) {
        Some(layout)
      } else {
        self.layout_with_fallback(run, scale_factor)
      }
    None => self.layout_with_fallback(run, scale_factor)
  }
}

///|
fn NativeTextEngine::layout_with_fallback(
  self : NativeTextEngine,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  self.fallback_layout_run(run, scale_factor)
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
  cache : NativeFontCache,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  let _ = cache
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
  cache : NativeFontCache,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  let _ = cache
  (self.provider.register_font_data)(family, data)
  match self.fallback {
    Some(fallback) => (fallback.register_font_data)(family, data)
    None => ()
  }
}

///|
pub fn native_text_system() -> @core.TextSystem {
  native_text_system_with_cache(NativeFontCache::new())
}

///|
pub fn native_text_system_with_engine(
  text_engine : NativeTextEngine,
) -> @core.TextSystem {
  native_text_system_with_cache(NativeFontCache::new_with_engine(text_engine))
}

///|
fn native_text_system_with_cache(cache : NativeFontCache) -> @core.TextSystem {
  @core.TextSystem::new(
    id=cache.text_engine.id(),
    measure=input => native_measure_text_layout(cache, input),
    register_font_data=(family, data) => {
      cache.text_engine.register_font_data(cache, family, data)
    },
  )
}

///|
fn native_measure_text_layout(
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  cache.text_engine.measure(cache, input)
}

///|
fn native_text_vertical_extra(
  frame : @core.Rect,
  layout : NativeTextLayout,
) -> Double {
  let extra = frame.size.height - layout.size.height
  if extra > 0.0 {
    extra / 2.0
  } else {
    0.0
  }
}

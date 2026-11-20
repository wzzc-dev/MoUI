///|
/// Draw text through the stable font-face layout pipeline.
pub fn Renderer::draw_text_face(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> Unit {
  let pixmap = self.canvas.get_pixmap()
  draw_text_face(
    self.canvas,
    face,
    text,
    x,
    y,
    pixmap.get_width(),
    pixmap.get_height(),
    config,
    paint,
  )
}

///|
/// Draw text through a caller-owned rendered text-mask cache.
pub fn Renderer::draw_text_face_cached(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  text_cache : @text.TextMaskCache,
  text_key : String,
  paint : @graphics.Paint,
) -> TextMaskDrawResult {
  let pixmap = self.canvas.get_pixmap()
  draw_text_face_cached(
    self.canvas,
    face,
    text,
    x,
    y,
    pixmap.get_width(),
    pixmap.get_height(),
    config,
    text_cache,
    text_key,
    paint,
  )
}

///|
/// Draw text through renderer-owned text resources and the rendered mask cache.
pub fn Renderer::draw_text_face_cached_with_resources(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererTextResources,
  text_key : String,
  paint : @graphics.Paint,
) -> TextMaskDrawResult {
  self.draw_text_face_cached(
    face,
    text,
    x,
    y,
    config,
    resources.get_text_mask_cache(),
    text_key,
    paint,
  )
}

///|
/// Draw text through renderer-owned resources and the rendered mask cache.
pub fn Renderer::draw_text_face_cached_with_renderer_resources(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  text_key : String,
  paint : @graphics.Paint,
) -> TextMaskDrawResult {
  self.draw_text_face_cached_with_resources(
    face,
    text,
    x,
    y,
    config,
    resources.get_text_resources(),
    text_key,
    paint,
  )
}

///|
/// Draw a single left-to-right text line through an ordered font fallback stack.
pub fn Renderer::draw_text_fallback_line(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  let pixmap = self.canvas.get_pixmap()
  draw_text_fallback_line(
    self.canvas,
    faces,
    text,
    x,
    y,
    pixmap.get_width(),
    pixmap.get_height(),
    config,
    paint,
  )
}

///|
/// Draw a single fallback line through a caller-owned rendered text-mask cache.
pub fn Renderer::draw_text_fallback_line_cached(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  text_cache : @text.TextMaskCache,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  let pixmap = self.canvas.get_pixmap()
  draw_text_fallback_line_cached(
    self.canvas,
    faces,
    text,
    x,
    y,
    pixmap.get_width(),
    pixmap.get_height(),
    config,
    text_cache,
    text_key_prefix,
    paint,
  )
}

///|
/// Draw a cached fallback line through renderer-owned text resources.
pub fn Renderer::draw_text_fallback_line_cached_with_resources(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererTextResources,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  self.draw_text_fallback_line_cached(
    faces,
    text,
    x,
    y,
    config,
    resources.get_text_mask_cache(),
    text_key_prefix,
    paint,
  )
}

///|
/// Draw a cached fallback line through renderer-owned resources.
pub fn Renderer::draw_text_fallback_line_cached_with_renderer_resources(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  self.draw_text_fallback_line_cached_with_resources(
    faces,
    text,
    x,
    y,
    config,
    resources.get_text_resources(),
    text_key_prefix,
    paint,
  )
}

///|
/// Draw a single fallback line through caller-owned glyph mask cache and atlas
/// resources.
pub fn Renderer::draw_text_fallback_line_atlas(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  glyph_cache : @text.GlyphMaskCache,
  atlas : @text.GlyphMaskAtlas,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackAtlasDrawResult {
  draw_text_fallback_line_atlas(
    self.canvas,
    faces,
    text,
    x,
    y,
    config,
    glyph_cache,
    atlas,
    glyph_key_prefix,
    paint,
  )
}

///|
/// Draw a fallback line through renderer-owned text resources and the glyph
/// atlas path.
pub fn Renderer::draw_text_fallback_line_atlas_with_resources(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererTextResources,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackAtlasDrawResult {
  self.draw_text_fallback_line_atlas(
    faces,
    text,
    x,
    y,
    config,
    resources.get_glyph_mask_cache(),
    resources.get_glyph_mask_atlas(),
    glyph_key_prefix,
    paint,
  )
}

///|
/// Draw a fallback line through renderer-owned resources and the glyph atlas
/// path.
pub fn Renderer::draw_text_fallback_line_atlas_with_renderer_resources(
  self : Renderer,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackAtlasDrawResult {
  self.draw_text_fallback_line_atlas_with_resources(
    faces,
    text,
    x,
    y,
    config,
    resources.get_text_resources(),
    glyph_key_prefix,
    paint,
  )
}

///|
/// Parse font bytes through renderer resources, then draw through the rendered
/// text-mask cache.
pub fn Renderer::draw_font_bytes_cached_with_renderer_resources(
  self : Renderer,
  font_data : Bytes,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  font_key : String,
  text_key : String,
  paint : @graphics.Paint,
) -> Result[CachedFontTextDrawResult, @text.FontParseError] {
  match
    resources.get_font_face_cache().get_or_parse_result(font_key, font_data) {
    Ok(parse_result) => {
      let text_result = self.draw_text_face_cached_with_renderer_resources(
        parse_result.get_face(),
        text,
        x,
        y,
        config,
        resources,
        text_key,
        paint,
      )
      Ok({ did_parse_font: parse_result.did_parse(), text_result, })
    }
    Err(error) => Err(error)
  }
}

///|
/// Load a font face through renderer resources, then draw through the rendered
/// text-mask cache.
pub fn[L : @text.FontLoader] Renderer::draw_loaded_font_cached_with_renderer_resources(
  self : Renderer,
  loader : L,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  font_key : String,
  text_key : String,
  paint : @graphics.Paint,
) -> Result[CachedFontTextDrawResult, @text.FontLoadError] {
  match resources.get_font_face_cache().get_or_load_result(font_key, loader) {
    Ok(load_result) => {
      let text_result = self.draw_text_face_cached_with_renderer_resources(
        load_result.get_face(),
        text,
        x,
        y,
        config,
        resources,
        text_key,
        paint,
      )
      Ok({ did_parse_font: load_result.did_parse(), text_result, })
    }
    Err(error) => Err(error)
  }
}

///|
/// Parse an ordered font-byte stack through renderer resources, then draw a
/// cached fallback line through the shared text-mask cache.
pub fn Renderer::draw_font_bytes_fallback_line_cached_with_renderer_resources(
  self : Renderer,
  sources : Array[FontBytesFallbackSource],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> Result[CachedFontFallbackDrawResult, @text.FontParseError] {
  let faces : Array[@text.FontFace] = []
  let mut parsed_font_count = 0
  let mut font_cache_hit_count = 0
  for source in sources {
    match
      resources
      .get_font_face_cache()
      .get_or_parse_result(source.get_font_key(), source.get_font_data()) {
      Ok(parse_result) => {
        faces.push(parse_result.get_face())
        if parse_result.did_parse() {
          parsed_font_count += 1
        } else {
          font_cache_hit_count += 1
        }
      }
      Err(error) => return Err(error)
    }
  }
  let fallback_result = self.draw_text_fallback_line_cached_with_renderer_resources(
    faces, text, x, y, config, resources, text_key_prefix, paint,
  )
  Ok({ parsed_font_count, font_cache_hit_count, fallback_result, })
}

///|
/// Parse an ordered font-byte stack through renderer resources, then draw a
/// fallback line through the shared glyph mask cache and atlas.
pub fn Renderer::draw_font_bytes_fallback_line_atlas_with_renderer_resources(
  self : Renderer,
  sources : Array[FontBytesFallbackSource],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> Result[CachedFontFallbackAtlasDrawResult, @text.FontParseError] {
  let faces : Array[@text.FontFace] = []
  let mut parsed_font_count = 0
  let mut font_cache_hit_count = 0
  for source in sources {
    match
      resources
      .get_font_face_cache()
      .get_or_parse_result(source.get_font_key(), source.get_font_data()) {
      Ok(parse_result) => {
        faces.push(parse_result.get_face())
        if parse_result.did_parse() {
          parsed_font_count += 1
        } else {
          font_cache_hit_count += 1
        }
      }
      Err(error) => return Err(error)
    }
  }
  let fallback_result = self.draw_text_fallback_line_atlas_with_renderer_resources(
    faces, text, x, y, config, resources, glyph_key_prefix, paint,
  )
  Ok({ parsed_font_count, font_cache_hit_count, fallback_result, })
}

///|
/// Draw text through caller-owned glyph mask cache and glyph atlas resources.
pub fn Renderer::draw_text_face_atlas(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  glyph_cache : @text.GlyphMaskCache,
  atlas : @text.GlyphMaskAtlas,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextAtlasDrawResult {
  draw_text_face_atlas(
    self.canvas,
    face,
    text,
    x,
    y,
    config,
    glyph_cache,
    atlas,
    glyph_key_prefix,
    paint,
  )
}

///|
/// Draw text through renderer-owned text resources and the glyph atlas path.
pub fn Renderer::draw_text_face_atlas_with_resources(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererTextResources,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextAtlasDrawResult {
  self.draw_text_face_atlas(
    face,
    text,
    x,
    y,
    config,
    resources.get_glyph_mask_cache(),
    resources.get_glyph_mask_atlas(),
    glyph_key_prefix,
    paint,
  )
}

///|
/// Draw text through renderer-owned resources and the glyph atlas path.
pub fn Renderer::draw_text_face_atlas_with_renderer_resources(
  self : Renderer,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextAtlasDrawResult {
  self.draw_text_face_atlas_with_resources(
    face,
    text,
    x,
    y,
    config,
    resources.get_text_resources(),
    glyph_key_prefix,
    paint,
  )
}

///|
/// Parse font bytes through renderer resources, then draw through glyph cache
/// and atlas resources.
pub fn Renderer::draw_font_bytes_atlas_with_renderer_resources(
  self : Renderer,
  font_data : Bytes,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  font_key : String,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> Result[CachedFontAtlasDrawResult, @text.FontParseError] {
  match
    resources.get_font_face_cache().get_or_parse_result(font_key, font_data) {
    Ok(parse_result) => {
      let atlas_result = self.draw_text_face_atlas_with_renderer_resources(
        parse_result.get_face(),
        text,
        x,
        y,
        config,
        resources,
        glyph_key_prefix,
        paint,
      )
      Ok({ did_parse_font: parse_result.did_parse(), atlas_result, })
    }
    Err(error) => Err(error)
  }
}

///|
/// Load a font face through renderer resources, then draw through glyph cache
/// and atlas resources.
pub fn[L : @text.FontLoader] Renderer::draw_loaded_font_atlas_with_renderer_resources(
  self : Renderer,
  loader : L,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  resources : RendererResources,
  font_key : String,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> Result[CachedFontAtlasDrawResult, @text.FontLoadError] {
  match resources.get_font_face_cache().get_or_load_result(font_key, loader) {
    Ok(load_result) => {
      let atlas_result = self.draw_text_face_atlas_with_renderer_resources(
        load_result.get_face(),
        text,
        x,
        y,
        config,
        resources,
        glyph_key_prefix,
        paint,
      )
      Ok({ did_parse_font: load_result.did_parse(), atlas_result, })
    }
    Err(error) => Err(error)
  }
}

///|
/// Composite an existing text coverage mask on the renderer canvas.
pub fn Renderer::draw_coverage_mask(
  self : Renderer,
  mask : @text.CoverageMask,
  paint : @graphics.Paint,
) -> Unit {
  draw_coverage_mask(self.canvas, mask, paint)
}

///|
/// Draw one glyph entry from a coverage-mask atlas snapshot.
pub fn Renderer::draw_glyph_atlas_entry(
  self : Renderer,
  atlas_mask : @text.CoverageMask,
  entry : @text.GlyphAtlasEntry,
  x : Int32,
  y : Int32,
  paint : @graphics.Paint,
) -> Unit {
  draw_glyph_atlas_entry(self.canvas, atlas_mask, entry, x, y, paint)
}

///|
/// Rasterize font-face text and composite it on a canvas.
fn draw_text_face(
  canvas : @graphics.Canvas,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  width : Int32,
  height : Int32,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> Unit {
  ignore(width)
  ignore(height)
  let (origin_x, phase_x) = text_mask_origin(x)
  let (origin_y, phase_y) = text_mask_origin(y)
  let mask = @text.render_text_mask_face_tight(
    face, text, phase_x, phase_y, config,
  )
  draw_coverage_mask_at(canvas, mask, origin_x, origin_y, paint)
}

///|
/// Draw text through a caller-owned rendered text-mask cache.
fn draw_text_face_cached(
  canvas : @graphics.Canvas,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  width : Int32,
  height : Int32,
  config : @text.LayoutConfig,
  text_cache : @text.TextMaskCache,
  text_key : String,
  paint : @graphics.Paint,
) -> TextMaskDrawResult {
  ignore(width)
  ignore(height)
  let (origin_x, phase_x) = text_mask_origin(x)
  let (origin_y, phase_y) = text_mask_origin(y)
  // The caller key stays verbatim: callers use it as the keyed-resource name
  // (`contains_text_mask` and eviction rely on an exact match). The mask itself
  // records the sub-pixel phase, and the cache re-rasterises when it differs,
  // so a mask rendered for another fractional position is never replayed.
  let result = text_cache.get_or_render_face_tight_result(
    text_key, face, text, phase_x, phase_y, config,
  )
  draw_coverage_mask_at(canvas, result.get_mask(), origin_x, origin_y, paint)
  { did_render_mask: result.did_render(), }
}

///|
/// Draw a single left-to-right text line through an ordered font fallback stack.
fn draw_text_fallback_line(
  canvas : @graphics.Canvas,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  width : Int32,
  height : Int32,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  draw_text_fallback_line_with_cache(
    canvas,
    faces,
    text,
    x,
    y,
    width,
    height,
    config,
    None,
    "",
    paint,
  )
}

///|
/// Draw a single fallback line through a caller-owned rendered text-mask cache.
fn draw_text_fallback_line_cached(
  canvas : @graphics.Canvas,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  width : Int32,
  height : Int32,
  config : @text.LayoutConfig,
  text_cache : @text.TextMaskCache,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  draw_text_fallback_line_with_cache(
    canvas,
    faces,
    text,
    x,
    y,
    width,
    height,
    config,
    Some(text_cache),
    text_key_prefix,
    paint,
  )
}

///|
/// Draw a single fallback line through caller-owned glyph mask cache and atlas
/// resources.
fn draw_text_fallback_line_atlas(
  canvas : @graphics.Canvas,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  glyph_cache : @text.GlyphMaskCache,
  atlas : @text.GlyphMaskAtlas,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackAtlasDrawResult {
  let plan = @text.plan_font_fallback(faces, text)
  let line_config = fallback_line_config(config)
  let mut cursor_x = x
  let mut drawn_span_count = 0
  let mut skipped_span_count = 0
  let mut emitted_char_count = 0
  let mut glyph_count = 0
  let mut drawn_glyph_count = 0
  let mut skipped_glyph_count = 0
  let mut cache_hit_count = 0
  let mut rasterized_glyph_count = 0
  let mut atlas_hit_count = 0
  let mut atlas_inserted_count = 0
  let mut did_clear_atlas = false

  for span in plan.get_spans() {
    if emitted_char_count > 0 {
      cursor_x += line_config.letter_spacing
    }
    if span.is_missing() {
      skipped_span_count += 1
      cursor_x += estimate_missing_span_advance(span.get_text(), line_config)
    } else {
      let face = faces[span.get_face_index()]
      let span_text = span.get_text()
      let result = draw_text_face_atlas(
        canvas,
        face,
        span_text,
        cursor_x,
        y,
        line_config,
        glyph_cache,
        atlas,
        fallback_glyph_atlas_cache_prefix(
          glyph_key_prefix,
          span.get_face_index(),
        ),
        paint,
      )
      glyph_count += result.get_glyph_count()
      drawn_glyph_count += result.get_drawn_glyph_count()
      skipped_glyph_count += result.get_skipped_glyph_count()
      cache_hit_count += result.get_cache_hit_count()
      rasterized_glyph_count += result.get_rasterized_glyph_count()
      atlas_hit_count += result.get_atlas_hit_count()
      atlas_inserted_count += result.get_atlas_inserted_count()
      if result.did_clear_atlas() {
        did_clear_atlas = true
      }
      cursor_x += @text.TextLayout::layout(face, span_text, line_config).get_width()
      drawn_span_count += 1
    }
    emitted_char_count += span.get_char_count()
  }

  {
    plan,
    drawn_span_count,
    skipped_span_count,
    advance_width: cursor_x - x,
    atlas_result: {
      glyph_count,
      drawn_glyph_count,
      skipped_glyph_count,
      cache_hit_count,
      rasterized_glyph_count,
      atlas_hit_count,
      atlas_inserted_count,
      did_clear_atlas,
    },
  }
}

///|
fn draw_text_fallback_line_with_cache(
  canvas : @graphics.Canvas,
  faces : Array[@text.FontFace],
  text : String,
  x : Double,
  y : Double,
  width : Int32,
  height : Int32,
  config : @text.LayoutConfig,
  text_cache : @text.TextMaskCache?,
  text_key_prefix : String,
  paint : @graphics.Paint,
) -> TextFallbackDrawResult {
  let plan = @text.plan_font_fallback(faces, text)
  let line_config = fallback_line_config(config)
  let mut cursor_x = x
  let mut drawn_span_count = 0
  let mut skipped_span_count = 0
  let mut rendered_mask_count = 0
  let mut cache_hit_count = 0
  let mut emitted_char_count = 0
  let mut span_index = 0

  for span in plan.get_spans() {
    if emitted_char_count > 0 {
      cursor_x += line_config.letter_spacing
    }
    if span.is_missing() {
      skipped_span_count += 1
      cursor_x += estimate_missing_span_advance(span.get_text(), line_config)
    } else {
      let face = faces[span.get_face_index()]
      let span_text = span.get_text()
      let advance_key = fallback_text_advance_key(
        text_key_prefix,
        span_index,
        span.get_face_index(),
        span_text,
        line_config,
      )
      let mut span_width = -1.0
      match text_cache {
        Some(cache) => {
          match cache.get_advance(advance_key) {
            Some(width) => span_width = width
            None => ()
          }
          let (origin_x, phase_x) = text_mask_origin(cursor_x)
          let (origin_y, phase_y) = text_mask_origin(y)
          let key = fallback_text_cache_key(
            text_key_prefix,
            span_index,
            span.get_face_index(),
            span_text,
            phase_x,
            phase_y,
            line_config,
          )
          let result = cache.get_or_render_face_tight_result(
            key, face, span_text, phase_x, phase_y, line_config,
          )
          draw_coverage_mask_at(
            canvas,
            result.get_mask(),
            origin_x,
            origin_y,
            paint,
          )
          if result.did_render() {
            rendered_mask_count += 1
          } else {
            cache_hit_count += 1
          }
        }
        None =>
          draw_text_face(
            canvas, face, span_text, cursor_x, y, width, height, line_config, paint,
          )
      }
      // The advance cannot change while the span identity does not, so once a
      // line has been laid out its width is reused; shaping on every frame only
      // to re-learn the same width is pure waste in a static UI.
      if span_width < 0.0 {
        span_width = @text.TextLayout::layout(face, span_text, line_config).get_width()
        match text_cache {
          Some(cache) => cache.insert_advance(advance_key, span_width)
          None => ()
        }
      }
      cursor_x += span_width
      drawn_span_count += 1
    }
    emitted_char_count += span.get_char_count()
    span_index += 1
  }

  {
    plan,
    drawn_span_count,
    skipped_span_count,
    rendered_mask_count,
    cache_hit_count,
    advance_width: cursor_x - x,
  }
}

///|
/// Draw text through caller-owned glyph mask cache and glyph atlas resources.
fn draw_text_face_atlas(
  canvas : @graphics.Canvas,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  glyph_cache : @text.GlyphMaskCache,
  atlas : @text.GlyphMaskAtlas,
  glyph_key_prefix : String,
  paint : @graphics.Paint,
) -> TextAtlasDrawResult {
  let layout = @text.TextLayout::layout(face, text, config)
  let scale = config.font_size / face.get_units_per_em().to_double()
  let mut glyph_count = 0
  let mut drawn_glyph_count = 0
  let mut skipped_glyph_count = 0
  let mut cache_hit_count = 0
  let mut rasterized_glyph_count = 0
  let mut atlas_hit_count = 0
  let mut atlas_inserted_count = 0
  let mut did_clear_atlas = false

  for run in layout.get_runs() {
    for glyph in run.get_glyphs() {
      glyph_count += 1
      let glyph_id = glyph.get_glyph_id()
      let key = glyph_atlas_cache_key(
        glyph_key_prefix,
        glyph_id,
        config.font_size,
      )
      match
        glyph_cache.get_or_rasterize_face_glyph_result(
          key, face, glyph_id, scale,
        ) {
        Some(cache_result) => {
          if cache_result.did_rasterize() {
            rasterized_glyph_count += 1
          } else {
            cache_hit_count += 1
          }
          let mask = cache_result.get_mask()
          let placement = cache_result.get_placement()
          match atlas.insert_or_clear(key, mask) {
            Some(result) => {
              if result.did_clear() {
                did_clear_atlas = true
              }
              if result.did_reuse() {
                atlas_hit_count += 1
              } else {
                atlas_inserted_count += 1
              }
              let entry = result.get_entry()
              draw_glyph_atlas_entry(
                canvas,
                atlas.to_mask(),
                entry,
                floor_to_int(x + glyph.get_origin_x()) +
                placement.get_draw_offset_x(),
                floor_to_int(y + run.get_baseline_y()) +
                placement.get_draw_offset_y(),
                paint,
              )
              drawn_glyph_count += 1
            }
            None => skipped_glyph_count += 1
          }
        }
        None => skipped_glyph_count += 1
      }
    }
  }

  {
    glyph_count,
    drawn_glyph_count,
    skipped_glyph_count,
    cache_hit_count,
    rasterized_glyph_count,
    atlas_hit_count,
    atlas_inserted_count,
    did_clear_atlas,
  }
}

///|
fn fallback_line_config(config : @text.LayoutConfig) -> @text.LayoutConfig {
  @text.LayoutConfig::new(
    max_width=1000000000.0,
    font_size=config.font_size,
    line_height=config.line_height,
    alignment=Left,
    letter_spacing=config.letter_spacing,
    word_spacing=config.word_spacing,
  )
}

///|
fn estimate_missing_span_advance(
  text : String,
  config : @text.LayoutConfig,
) -> Double {
  let mut width = 0.0
  let mut char_count = 0
  for ch in text {
    width += config.font_size * 0.6
    if ch is ' ' {
      width += config.word_spacing
    }
    char_count += 1
  }
  if char_count > 1 {
    width += config.letter_spacing * (char_count - 1).to_double()
  }
  width
}

///|
/// Cache key for one fallback span's tight coverage mask.
///
/// The mask is rasterised into a line-local box, so the absolute draw position
/// is not part of the identity: only the sub-pixel phase (which shifts the
/// glyph coverage inside the box) is. That lets a scrolled or re-laid-out line
/// reuse its mask as long as the phase matches.
fn fallback_text_advance_key(
  prefix : String,
  span_index : Int32,
  face_index : Int32,
  text : String,
  config : @text.LayoutConfig,
) -> String {
  prefix +
  ":fallback-advance:" +
  span_index.to_string() +
  ":face:" +
  face_index.to_string() +
  ":size:" +
  config.font_size.to_string() +
  ":letter:" +
  config.letter_spacing.to_string() +
  ":word:" +
  config.word_spacing.to_string() +
  ":text:" +
  text
}

///|
fn fallback_text_cache_key(
  prefix : String,
  span_index : Int32,
  face_index : Int32,
  text : String,
  phase_x : Double,
  phase_y : Double,
  config : @text.LayoutConfig,
) -> String {
  prefix +
  ":fallback-span:" +
  span_index.to_string() +
  ":face:" +
  face_index.to_string() +
  ":phase-x:" +
  phase_x.to_string() +
  ":phase-y:" +
  phase_y.to_string() +
  ":size:" +
  config.font_size.to_string() +
  ":letter:" +
  config.letter_spacing.to_string() +
  ":word:" +
  config.word_spacing.to_string() +
  ":text:" +
  text
}

///|
fn fallback_glyph_atlas_cache_prefix(
  prefix : String,
  face_index : Int32,
) -> String {
  prefix + ":fallback-face:" + face_index.to_string()
}

///|
/// Composite a text coverage mask on a canvas at the mask's own origin.
fn draw_coverage_mask(
  canvas : @graphics.Canvas,
  mask : @text.CoverageMask,
  paint : @graphics.Paint,
) -> Unit {
  draw_coverage_mask_at(
    canvas,
    mask,
    mask.get_offset_x(),
    mask.get_offset_y(),
    paint,
  )
}

///|
/// Composite a text coverage mask on a canvas with an extra origin offset.
fn draw_coverage_mask_at(
  canvas : @graphics.Canvas,
  mask : @text.CoverageMask,
  origin_x : Int32,
  origin_y : Int32,
  paint : @graphics.Paint,
) -> Unit {
  canvas.draw_mask(
    origin_x + mask.get_offset_x(),
    origin_y + mask.get_offset_y(),
    mask.get_width(),
    mask.get_height(),
    mask.get_pixels(),
    paint,
  )
}

///|
/// Composite one glyph entry from a coverage-mask atlas snapshot on a canvas.
fn draw_glyph_atlas_entry(
  canvas : @graphics.Canvas,
  atlas_mask : @text.CoverageMask,
  entry : @text.GlyphAtlasEntry,
  x : Int32,
  y : Int32,
  paint : @graphics.Paint,
) -> Unit {
  canvas.draw_mask_rect(
    x,
    y,
    atlas_mask.get_width(),
    atlas_mask.get_height(),
    atlas_mask.get_pixels(),
    @graphics.PixelRect::new(
      x=entry.get_x(),
      y=entry.get_y(),
      width=entry.get_width(),
      height=entry.get_height(),
    ),
    paint,
  )
}

///|
fn glyph_atlas_cache_key(
  prefix : String,
  glyph_id : Int32,
  font_size : Double,
) -> String {
  prefix + ":glyph:" + glyph_id.to_string() + ":size:" + font_size.to_string()
}

///|
/// Split a device-space coordinate into an integer mask origin and a
/// quantised sub-pixel phase.
///
/// Tight text masks are rasterised in a line-local box; the phase decides where
/// the glyph coverage sits inside that box. Quantising to 1/16 px keeps the
/// mask cache addressable at the cost of at most ~0.03 px of glyph shift, which
/// is below what the 4x4 sample grid can resolve.
fn text_mask_origin(value : Double) -> (Int32, Double) {
  let base = floor_to_int(value)
  let mut phase = value - base.to_double()
  if phase < 0.0 {
    phase = 0.0
  }
  let quantised = (phase * 16.0).round() / 16.0
  if quantised >= 1.0 {
    (base + 1, 0.0)
  } else {
    (base, quantised)
  }
}

///|
fn floor_to_int(value : Double) -> Int32 {
  let truncated = value.to_int()
  if truncated.to_double() > value {
    truncated - 1
  } else {
    truncated
  }
}

///|
fn ceil_to_int(value : Double) -> Int32 {
  let truncated = value.to_int()
  if truncated.to_double() < value {
    truncated + 1
  } else {
    truncated
  }
}

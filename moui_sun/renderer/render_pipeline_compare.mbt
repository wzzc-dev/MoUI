///|
fn render_commands_are_same(a : RenderCommand, b : RenderCommand) -> Bool {
  match render_point_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match render_sampled_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match render_quality_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match render_transformed_sampled_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match render_transformed_quality_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match render_tiled_image_commands_are_same(a, b) {
    Some(same) => return same
    None => ()
  }
  match (a, b) {
    (RenderCommand::Clear(a_color), RenderCommand::Clear(b_color)) =>
      a_color == b_color
    (
      RenderCommand::FillRect(ax, ay, aw, ah, a_paint),
      RenderCommand::FillRect(bx, by, bw, bh, b_paint),
    ) =>
      ax == bx &&
      ay == by &&
      aw == bw &&
      ah == bh &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::StrokeRect(ax, ay, aw, ah, a_paint),
      RenderCommand::StrokeRect(bx, by, bw, bh, b_paint),
    ) =>
      ax == bx &&
      ay == by &&
      aw == bw &&
      ah == bh &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::FillPath(a_path, a_paint),
      RenderCommand::FillPath(b_path, b_paint),
    ) =>
      render_paths_are_same(a_path, b_path) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::StrokePath(a_path, a_paint),
      RenderCommand::StrokePath(b_path, b_paint),
    ) =>
      render_paths_are_same(a_path, b_path) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawNinePatchBmpBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_insets,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawNinePatchBmpBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_insets,
        b_paint,
        b_sampling
      ),
    ) =>
      render_keyed_nine_patch_image_is_same(
        a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_insets, b_insets, a_paint,
        b_paint, a_sampling, b_sampling,
      )
    (
      RenderCommand::DrawNinePatchPngBytesKeyed(
        a_key,
        _,
        ax,
        ay,
        aw,
        ah,
        a_insets,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawNinePatchPngBytesKeyed(
        b_key,
        _,
        bx,
        by,
        bw,
        bh,
        b_insets,
        b_paint,
        b_sampling
      ),
    ) =>
      render_keyed_nine_patch_image_is_same(
        a_key, b_key, ax, ay, aw, ah, bx, by, bw, bh, a_insets, b_insets, a_paint,
        b_paint, a_sampling, b_sampling,
      )
    (
      RenderCommand::DrawNinePatchRgbaBytesKeyed(
        a_key,
        _,
        a_image_width,
        a_image_height,
        ax,
        ay,
        aw,
        ah,
        a_insets,
        a_paint,
        a_sampling
      ),
      RenderCommand::DrawNinePatchRgbaBytesKeyed(
        b_key,
        _,
        b_image_width,
        b_image_height,
        bx,
        by,
        bw,
        bh,
        b_insets,
        b_paint,
        b_sampling
      ),
    ) =>
      render_keyed_nine_patch_image_dimensions_is_same(
        a_key, b_key, a_image_width, a_image_height, b_image_width, b_image_height,
        ax, ay, aw, ah, bx, by, bw, bh, a_insets, b_insets, a_paint, b_paint, a_sampling,
        b_sampling,
      )
    (
      RenderCommand::DrawPixmapRect(_, _, _, _, _),
      RenderCommand::DrawPixmapRect(_, _, _, _, _),
    ) => false
    (
      RenderCommand::DrawPixmapRectKeyed(a_key, _, a_src, ax, ay, a_paint),
      RenderCommand::DrawPixmapRectKeyed(b_key, _, b_src, bx, by, b_paint),
    ) =>
      render_keyed_image_source_point_is_same(
        a_key, b_key, a_src, b_src, ax, ay, bx, by, a_paint, b_paint,
      )
    (
      RenderCommand::DrawTextFace(_, _, _, _, _, _),
      RenderCommand::DrawTextFace(_, _, _, _, _, _),
    ) => false
    (
      RenderCommand::DrawTextFaceKeyed(
        a_key,
        _,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawTextFaceKeyed(
        b_key,
        _,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      a_key == b_key &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawFontBytesKeyed(
        a_font_key,
        _,
        a_text_key,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawFontBytesKeyed(
        b_font_key,
        _,
        b_text_key,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      a_font_key == b_font_key &&
      a_text_key == b_text_key &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawFontBytesAtlasKeyed(
        a_font_key,
        _,
        a_glyph_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawFontBytesAtlasKeyed(
        b_font_key,
        _,
        b_glyph_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      a_font_key == b_font_key &&
      a_glyph_key_prefix == b_glyph_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawFontBytesFallbackKeyed(
        a_sources,
        a_text_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawFontBytesFallbackKeyed(
        b_sources,
        b_text_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      render_font_bytes_fallback_sources_are_same(a_sources, b_sources) &&
      a_text_key_prefix == b_text_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        a_sources,
        a_glyph_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawFontBytesFallbackAtlasKeyed(
        b_sources,
        b_glyph_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      render_font_bytes_fallback_sources_are_same(a_sources, b_sources) &&
      a_glyph_key_prefix == b_glyph_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawLoadedFontKeyed(
        a_font_key,
        a_text_key,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawLoadedFontKeyed(
        b_font_key,
        b_text_key,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      a_font_key == b_font_key &&
      a_text_key == b_text_key &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawLoadedFontFallbackKeyed(
        a_font_keys,
        a_text_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawLoadedFontFallbackKeyed(
        b_font_keys,
        b_text_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      string_arrays_are_same(a_font_keys, b_font_keys) &&
      a_text_key_prefix == b_text_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawLoadedFontFallbackAtlasKeyed(
        a_font_keys,
        a_glyph_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawLoadedFontFallbackAtlasKeyed(
        b_font_keys,
        b_glyph_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      string_arrays_are_same(a_font_keys, b_font_keys) &&
      a_glyph_key_prefix == b_glyph_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    (
      RenderCommand::DrawLoadedFontAtlasKeyed(
        a_font_key,
        a_glyph_key_prefix,
        a_text,
        ax,
        ay,
        a_config,
        a_paint
      ),
      RenderCommand::DrawLoadedFontAtlasKeyed(
        b_font_key,
        b_glyph_key_prefix,
        b_text,
        bx,
        by,
        b_config,
        b_paint
      ),
    ) =>
      a_font_key == b_font_key &&
      a_glyph_key_prefix == b_glyph_key_prefix &&
      a_text == b_text &&
      ax == bx &&
      ay == by &&
      render_layout_config_is_same(a_config, b_config) &&
      render_paint_is_same(a_paint, b_paint)
    _ => false
  }
}

///|
fn render_font_bytes_fallback_sources_are_same(
  a : Array[FontBytesFallbackSource],
  b : Array[FontBytesFallbackSource],
) -> Bool {
  guard a.length() == b.length() else { return false }
  for index in 0..<a.length() {
    if a[index].get_font_key() != b[index].get_font_key() {
      return false
    }
  }
  true
}

///|
fn render_paths_are_same(a : @graphics.Path, b : @graphics.Path) -> Bool {
  guard a.segment_count() == b.segment_count() else { return false }
  let a_segments = a.get_segments()
  let b_segments = b.get_segments()
  for index in 0..<a_segments.length() {
    if a_segments[index] != b_segments[index] {
      return false
    }
  }
  true
}

///|
fn render_paint_is_same(a : @graphics.Paint, b : @graphics.Paint) -> Bool {
  a.color == b.color &&
  a.shader == b.shader &&
  a.filter == b.filter &&
  a.style == b.style &&
  a.blend_mode == b.blend_mode &&
  a.stroke_width == b.stroke_width &&
  a.stroke_cap == b.stroke_cap &&
  a.stroke_join == b.stroke_join &&
  a.miter_limit == b.miter_limit &&
  double_arrays_are_same(a.stroke_dash_pattern, b.stroke_dash_pattern) &&
  a.stroke_dash_offset == b.stroke_dash_offset &&
  a.fill_rule == b.fill_rule &&
  a.opacity == b.opacity
}

///|
fn render_layout_config_is_same(
  a : @text.LayoutConfig,
  b : @text.LayoutConfig,
) -> Bool {
  a.max_width == b.max_width &&
  a.font_size == b.font_size &&
  a.line_height == b.line_height &&
  a.alignment == b.alignment &&
  a.letter_spacing == b.letter_spacing &&
  a.word_spacing == b.word_spacing
}

///|
fn double_arrays_are_same(a : Array[Double], b : Array[Double]) -> Bool {
  guard a.length() == b.length() else { return false }
  for index in 0..<a.length() {
    if a[index] != b[index] {
      return false
    }
  }
  true
}

///|
fn string_arrays_are_same(a : Array[String], b : Array[String]) -> Bool {
  guard a.length() == b.length() else { return false }
  for index in 0..<a.length() {
    if a[index] != b[index] {
      return false
    }
  }
  true
}

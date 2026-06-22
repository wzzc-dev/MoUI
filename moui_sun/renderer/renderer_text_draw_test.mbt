///|
test "Renderer::draw_text_face_cached reuses rendered text masks" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let text_cache = @text.TextMaskCache::new()
  let first = renderer.draw_text_face_cached(
    face,
    "A",
    1.0,
    1.0,
    config,
    text_cache,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_true(first.did_render_mask())
  assert_true(!first.did_hit_cache())
  assert_eq(text_cache.len(), 1)
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_face_cached(
    face,
    "O",
    1.0,
    1.0,
    config,
    text_cache,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(!second.did_render_mask())
  assert_true(second.did_hit_cache())
  assert_eq(text_cache.len(), 1)
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer::draw_text_face preserves holes in parsed TTF glyphs" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  renderer.draw_text_face(
    face,
    "O",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(5, 5), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer::draw_text_face applies layout alignment" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=30.0,
    font_size=10.0,
    line_height=10.0,
    alignment=@text.TextAlign::Right,
  )
  renderer.draw_text_face(
    face,
    "A",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(20, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(21, 1), @graphics.Color::black())
}

///|
test "Renderer::draw_text_face applies explicit newlines" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 24)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=30.0,
    font_size=10.0,
    line_height=10.0,
  )
  renderer.draw_text_face(
    face,
    "A\nA",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(1, 11), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer::draw_text_face applies letter spacing" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(26, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
    letter_spacing=3.0,
  )
  renderer.draw_text_face(
    face,
    "AA",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(11, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(14, 1), @graphics.Color::black())
}

///|
test "Renderer::draw_text_face wraps after trailing space" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(14, 24)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=12.0,
    font_size=10.0,
    line_height=10.0,
  )
  renderer.draw_text_face(
    face,
    "A A",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(11, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 11), @graphics.Color::black())
}

///|
test "Renderer::draw_text_face covers a parsed TTF glyph matrix" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  assert_matrix_glyph(face, "A", (2, 2), None, config)
  assert_matrix_glyph(face, "O", (2, 2), Some((5, 5)), config)
  assert_matrix_glyph(face, "D", (2, 2), Some((6, 5)), config)
  assert_matrix_glyph(face, "o", (2, 5), Some((5, 5)), config)
  assert_matrix_glyph(face, "d", (2, 3), Some((6, 5)), config)
  assert_matrix_glyph(face, "0", (2, 2), Some((5, 5)), config)
  assert_matrix_glyph(face, "2", (5, 10), None, config)
  assert_matrix_glyph(face, "3", (7, 3), None, config)
  assert_matrix_glyph(face, "8", (2, 2), Some((5, 3)), config)
  assert_matrix_glyph(face, "i", (2, 3), Some((2, 6)), config)
  assert_matrix_glyph(face, "i", (2, 9), Some((2, 6)), config)
}

///|
test "Renderer::draw_text_face covers printable ASCII from parsed TTF bytes" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let ascii = printable_ascii_string()
  let mut glyph_count = 0
  for ch in ascii {
    let codepoint = ch.to_int()
    let glyph_id = face.char_to_glyph(codepoint)
    assert_true(glyph_id > 0)
    assert_eq(glyph_id, codepoint - 0x20 + 1)
    if ch is ' ' {
      assert_ascii_space_glyph(face, ch.to_string(), glyph_id, config)
    } else {
      assert_ascii_visible_glyph(face, ch.to_string(), glyph_id, config)
    }
    glyph_count = glyph_count + 1
  }
  assert_eq(glyph_count, printable_ascii_count())
}

///|
test "Renderer checked generated font fixture applies kern table to layout and pixels" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_kerning_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let layout = @text.TextLayout::layout(face, "AV", config)
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_width(), 16.0)
  let glyphs = layout.get_runs()[0].get_glyphs()
  assert_eq(glyphs.length(), 2)
  assert_eq(glyphs[0].get_glyph_id(), 1)
  assert_eq(glyphs[1].get_glyph_id(), 2)
  assert_eq(glyphs[0].get_x(), 0.0)
  assert_eq(glyphs[1].get_x(), 6.0)

  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  renderer.draw_text_face(
    face,
    "AV",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(16, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(17, 1), @graphics.Color::white())
}

///|
test "Renderer generated format 12 fixture draws supplementary glyph through cached atlas resources" {
  let text = string_from_codepoints([0x1F600])
  let font_bytes = make_ttf_for_codes([0x1F600])
  let face = unwrap_font_face(@text.FontFace::from_bytes(font_bytes))
  assert_eq(face.char_to_glyph(0x1F600), 1)
  assert_true(face.has_glyph_for_char(0x1F600))

  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let layout = @text.TextLayout::layout(face, text, config)
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_runs()[0].glyph_count(), 1)
  assert_eq(layout.get_runs()[0].get_glyphs()[0].get_glyph_id(), 1)

  let canvas = @graphics.Canvas::new(16, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(16, 16, 1, 2, 2, 1)
  let first = match
    renderer.draw_font_bytes_atlas_with_renderer_resources(
      font_bytes,
      text,
      1.0,
      1.0,
      config,
      resources,
      "emoji-face",
      "emoji-label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected supplementary atlas draw")
  }
  assert_true(first.did_parse_font())
  assert_eq(first.get_glyph_count(), 1)
  assert_eq(first.get_rasterized_glyph_count(), 1)
  assert_eq(first.get_atlas_inserted_count(), 1)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_atlas_with_renderer_resources(
      b"not a font",
      text,
      1.0,
      1.0,
      config,
      resources,
      "emoji-face",
      "emoji-label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected supplementary atlas cache hit")
  }
  assert_true(second.did_hit_font_cache())
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 1)
  assert_eq(second.get_atlas_hit_count(), 1)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer generated fallback atlas fixture reports supplementary spans and missing glyphs" {
  let text = string_from_codepoints(['A'.to_int(), 0x1F600, 'Z'.to_int()])
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(24, 12, 2, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = match
    renderer.draw_font_bytes_fallback_line_atlas_with_renderer_resources(
      [
        FontBytesFallbackSource::new("latin", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("emoji", make_ttf_for_codes([0x1F600])),
      ],
      text,
      1.0,
      1.0,
      config,
      resources,
      "mixed-label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected mixed fallback atlas draw")
  }
  assert_eq(first.get_parsed_font_count(), 2)
  assert_eq(first.get_span_count(), 3)
  assert_eq(first.get_drawn_span_count(), 2)
  assert_eq(first.get_skipped_span_count(), 1)
  assert_eq(first.get_missing_span_count(), 1)
  assert_eq(first.get_missing_char_count(), 1)
  assert_true(first.has_missing_glyphs())
  assert_eq(first.get_glyph_count(), 2)
  assert_eq(first.get_rasterized_glyph_count(), 2)
  assert_eq(first.get_atlas_inserted_count(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_fallback_line_atlas_with_renderer_resources(
      [
        FontBytesFallbackSource::new("latin", b"not a font"),
        FontBytesFallbackSource::new("emoji", b"also not a font"),
      ],
      text,
      1.0,
      1.0,
      config,
      resources,
      "mixed-label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected mixed fallback atlas cache hit")
  }
  assert_eq(second.get_parsed_font_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 2)
  assert_eq(second.get_missing_span_count(), 1)
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
fn assert_matrix_glyph(
  face : @text.FontFace,
  text : String,
  filled : (Int, Int),
  hole : (Int, Int)?,
  config : @text.LayoutConfig,
) -> Unit raise {
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  renderer.draw_text_face(
    face,
    text,
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  let (filled_x, filled_y) = filled
  assert_eq(pixmap.get_pixel(filled_x, filled_y), @graphics.Color::black())
  match hole {
    Some((hole_x, hole_y)) =>
      assert_eq(
        pixmap.get_pixel(hole_x, hole_y),
        @graphics.Color::white(),
        msg="hole pixel should stay white for " + text,
      )
    None => ()
  }
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
fn assert_ascii_visible_glyph(
  face : @text.FontFace,
  text : String,
  glyph_id : Int,
  config : @text.LayoutConfig,
) -> Unit raise {
  let layout = @text.TextLayout::layout(face, text, config)
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_runs()[0].glyph_count(), 1)
  assert_eq(layout.get_runs()[0].get_glyphs()[0].get_glyph_id(), glyph_id)

  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  renderer.draw_text_face(
    face,
    text,
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
fn assert_ascii_space_glyph(
  face : @text.FontFace,
  text : String,
  glyph_id : Int,
  config : @text.LayoutConfig,
) -> Unit raise {
  let layout = @text.TextLayout::layout(face, text, config)
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_runs()[0].glyph_count(), 1)
  assert_eq(layout.get_runs()[0].get_glyphs()[0].get_glyph_id(), glyph_id)
  assert_eq(layout.get_runs()[0].get_width(), 5.0)

  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  renderer.draw_text_face(
    face,
    text,
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(!pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
fn pixmap_has_ink(pixmap : @graphics.Pixmap) -> Bool {
  for y in 0..<pixmap.get_height() {
    for x in 0..<pixmap.get_width() {
      if pixmap.get_pixel(x, y) != @graphics.Color::white() {
        return true
      }
    }
  }
  false
}

///|
fn printable_ascii_string() -> String {
  let out = StringBuilder(size_hint=printable_ascii_count())
  for codepoint in 0x20..<=0x7E {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}

///|
fn printable_ascii_count() -> Int {
  0x7E - 0x20 + 1
}

///|
fn string_from_codepoints(codepoints : Array[Int]) -> String {
  let out = StringBuilder(size_hint=codepoints.length())
  for codepoint in codepoints {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}

///|
fn unwrap_font_face(
  result : Result[@text.FontFace, @text.FontParseError],
) -> @text.FontFace {
  match result {
    Ok(face) => face
    Err(_) => abort("expected valid font face")
  }
}

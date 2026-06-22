///|
test "Renderer::draw_coverage_mask composites text mask" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  pixels[1] = 255
  let mask = @text.CoverageMask::new(2, 2, pixels)
  let renderer = Renderer::new(canvas)
  renderer.draw_coverage_mask(
    mask,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::black())
}

///|
test "Renderer::draw_glyph_atlas_entry composites atlas subrect" {
  let atlas = @text.GlyphMaskAtlas::new(4, 2)
  let first = @text.CoverageMask::new(2, 2, FixedArray::make(4, 0))
  ignore(atlas.insert("empty", first))
  let glyph_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  glyph_pixels[0] = 255
  glyph_pixels[1] = 128
  glyph_pixels[2] = 0
  glyph_pixels[3] = 64
  let glyph = @text.CoverageMask::new(2, 2, glyph_pixels)
  let entry = match atlas.insert("glyph", glyph) {
    Some(entry) => entry
    None => abort("expected atlas entry")
  }

  let canvas = @graphics.Canvas::new(4, 3)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  renderer.draw_glyph_atlas_entry(
    atlas.to_mask(),
    entry,
    1,
    0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::black())
  assert_eq(
    pixmap.get_pixel(2, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
  assert_eq(
    pixmap.get_pixel(2, 1),
    @graphics.Color::new(r=191, g=191, b=191, a=255),
  )
}

///|
test "Renderer::draw_coverage_mask uses paint opacity" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::white())
  let pixels : FixedArray[Byte] = FixedArray::make(1, 255)
  let mask = @text.CoverageMask::new(1, 1, pixels)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_opacity(0.5)
  let renderer = Renderer::new(canvas)
  renderer.draw_coverage_mask(mask, paint)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
}
